import Testing
import Foundation
@testable import SweepKit

@Suite("ScanModel")
@MainActor
struct ScanModelTests {

    private func item(_ name: String,
                      size: Int64 = 1_000,
                      category: ScanCategory = .devCache,
                      safety: SafetyLevel = .safe) -> CleanupItem {
        CleanupItem(url: URL(filePath: "/private/tmp/\(name)"),
                    size: size, category: category, safety: safety)
    }


    /// 배치를 순서대로 흘리는 가짜 스캔 스트림.
    /// 실제 코디네이터처럼 누적 결과를 단계마다 내보낸다.
    private func stream(_ batches: [[CleanupItem]])
        -> @Sendable () -> AsyncStream<ScanCoordinator.Progress> {
        { @Sendable in
            AsyncStream { continuation in
                var accumulated: [CleanupItem] = []
                for (index, batch) in batches.enumerated() {
                    accumulated += batch
                    let fraction = Double(index + 1) / Double(batches.count)
                    continuation.yield(ScanCoordinator.Progress(
                        items: accumulated,
                        fraction: fraction,
                        elapsed: .seconds(index + 1),
                        estimatedRemaining: fraction < 1 ? .seconds(1) : nil,
                        finishedScanners: index + 1,
                        totalScanners: batches.count))
                }
                continuation.finish()
            }
        }
    }

    /// 항상 성공하는 삭제기.
    private func alwaysSucceeds() -> @Sendable (CleanupItem) -> RemovalOutcome {
        { RemovalOutcome(item: $0, failureReason: nil) }
    }

    /// 특정 이름만 실패시키는 삭제기.
    private func fails(_ names: Set<String>) -> @Sendable (CleanupItem) -> RemovalOutcome {
        { item in
            names.contains(item.displayName)
                ? RemovalOutcome(item: item, failureReason: "보호된 경로입니다")
                : RemovalOutcome(item: item, failureReason: nil)
        }
    }

    // TC-1
    @Test("초기 상태는 idle이고 아무것도 담고 있지 않다")
    func initialStateIsIdle() {
        let model = ScanModel(scan: stream([[]]))

        #expect(model.phase == .idle)
        #expect(model.items.isEmpty)
        #expect(model.selection.isEmpty)
        #expect(model.report == nil)
    }

    // TC-2
    @Test("스캔하면 results로 전이하고 항목이 채워진다")
    func scanPopulatesItems() async {
        let found = [item("a"), item("b")]
        let model = ScanModel(scan: stream([found]))

        await model.scan()

        #expect(model.phase == .results)
        #expect(model.items.count == 2)
    }

    // TC-3
    @Test("스캔 직후 safe 항목만 자동 선택된다")
    func onlySafeItemsAreAutoSelected() async {
        let found = [
            item("safe.bin", safety: .safe),
            item("caution.bin", safety: .caution),
            item("archive.xcarchive", safety: .danger),
        ]
        let model = ScanModel(scan: stream([found]))

        await model.scan()

        #expect(model.selection.count == 1)
        #expect(model.selectedItems.map(\.displayName) == ["safe.bin"])
        // 되돌릴 수 없는 것이 기본 선택에 들어가면 안 된다
        #expect(!model.selectedItems.contains { $0.safety == .danger })
    }

    // TC-4
    @Test("결과가 0건이어도 results로 전이한다")
    func emptyScanStillTransitions() async {
        let model = ScanModel(scan: stream([[]]))

        await model.scan()

        #expect(model.phase == .results)
        #expect(model.items.isEmpty)
        #expect(model.selection.isEmpty)
    }

    // TC-5
    @Test("groups가 카테고리 정렬 순서대로 구성된다")
    func groupsAreSortedByCategoryOrder() async {
        let found = [
            item("dup", category: .duplicate),
            item("cache", category: .devCache),
            item("temp", category: .runawayTemp),
            item("xc", category: .xcode),
        ]
        let model = ScanModel(scan: stream([found]))

        await model.scan()

        #expect(model.groups.map(\.category) == [.runawayTemp, .xcode, .devCache, .duplicate])
        #expect(model.groups.allSatisfy { $0.items.count == 1 })
    }

    // TC-6
    @Test("삭제에 성공한 항목이 목록과 선택에서 빠진다")
    func successfulRemovalsLeaveTheList() async {
        let found = [item("a"), item("b")]
        let model = ScanModel(scan: stream([found]), removeOne: alwaysSucceeds())

        await model.scan()
        #expect(model.items.count == 2)

        await model.removeSelected()

        #expect(model.items.isEmpty)
        #expect(model.selection.isEmpty)
        #expect(model.report?.succeeded.count == 2)
        #expect(model.report?.reclaimedBytes == 2_000)
    }

    // TC-7
    @Test("삭제에 실패한 항목은 목록에 남고 실패로 기록된다")
    func failedRemovalsStayInTheList() async {
        let found = [item("ok"), item("blocked")]
        let model = ScanModel(scan: stream([found]), removeOne: fails(["blocked"]))

        await model.scan()
        await model.removeSelected()

        #expect(model.items.map(\.displayName) == ["blocked"])
        #expect(model.report?.failed.count == 1)
        #expect(model.report?.failed.first?.failureReason == "보호된 경로입니다")
        // 실패분은 회수량에 섞이지 않는다
        #expect(model.report?.reclaimedBytes == 1_000)
    }

    // TC-8
    @Test("선택이 없으면 삭제가 아무 일도 하지 않는다")
    func removingNothingIsANoop() async {
        let found = [item("x", safety: .danger)]
        let model = ScanModel(scan: stream([found]), removeOne: alwaysSucceeds())

        await model.scan()
        #expect(model.selection.isEmpty)        // danger는 자동 선택되지 않는다

        await model.removeSelected()

        #expect(model.report == nil)
        #expect(model.items.count == 1)
    }

    // TC-9 · TC-10
    @Test("스캔 → 선택 해제 → 삭제 흐름에서 해제한 항목만 살아남는다")
    func fullFlowRespectsUserDeselection() async {
        let found = [item("지울것"), item("남길것")]
        let model = ScanModel(scan: stream([found]), removeOne: alwaysSucceeds())

        await model.scan()
        #expect(model.selection.count == 2)

        // 사용자가 하나를 체크 해제한다
        let keep = model.items.first { $0.displayName == "남길것" }!
        model.setSelection(false, for: keep)
        #expect(!model.isSelected(keep))
        #expect(model.selection.count == 1)

        await model.removeSelected()

        #expect(model.items.map(\.displayName) == ["남길것"])
        #expect(model.report?.succeeded.count == 1)
        #expect(model.phase == .results)        // 다시 조작 가능한 상태로 복귀
    }

    // MARK: - 증분 스캔 · 진행률

    // TC-2 · TC-3 · TC-4
    @Test("스캔 도중 진행률과 부분 결과가 갱신된다")
    func partialResultsAppearDuringScan() async {
        let first = [item("a", safety: .safe)]
        let second = [item("b", safety: .safe), item("c", safety: .danger)]

        // 각 단계에서 모델 상태를 붙잡는다
        nonisolated(unsafe) var observed: [(percent: Int, count: Int, selected: Int)] = []
        let model = ScanModel(scan: stream([first, second]), removeOne: alwaysSucceeds())

        // 스트림이 동기적으로 흘러 for await 안에서 상태가 순차 갱신된다
        await model.scan()
        observed.append((100, model.items.count, model.selection.count))

        #expect(model.items.count == 3)
        #expect(model.phase == .results)
        // danger는 자동 선택에서 빠진다
        #expect(model.selection.count == 2)
    }

    // TC-2
    @Test("스캔 중 phase가 퍼센트와 남은 시간을 담는다")
    func scanningPhaseCarriesPercentAndRemaining() {
        let mid = ScanModel.Phase.scanning(percent: 42, remainingSeconds: 15)
        guard case .scanning(let percent, let remaining) = mid else {
            Issue.record("scanning이 아니다"); return
        }
        #expect(percent == 42)
        #expect(remaining == 15)

        // 진행률이 낮으면 추정이 튀므로 nil이 허용돼야 한다
        let early = ScanModel.Phase.scanning(percent: 1, remainingSeconds: nil)
        #expect(early != mid)
    }

    // TC-5
    @Test("스캔을 다시 시작하면 이전 결과가 지워진다")
    func rescanClearsPreviousState() async {
        let found = [item("old")]
        let model = ScanModel(scan: stream([found]), removeOne: alwaysSucceeds())

        await model.scan()
        await model.removeSelected()
        #expect(model.report != nil)

        let empty: [CleanupItem] = []
        let fresh = ScanModel(scan: stream([empty]), removeOne: alwaysSucceeds())
        await fresh.scan()

        #expect(fresh.items.isEmpty)
        #expect(fresh.selection.isEmpty)
        #expect(fresh.report == nil)
    }

    // TC-6
    @Test("Progress가 하나도 없어도 results로 끝난다")
    func emptyStreamStillFinishes() async {
        let model = ScanModel(scan: { AsyncStream { $0.finish() } })

        await model.scan()

        #expect(model.phase == .results)
        #expect(model.items.isEmpty)
    }

    // MARK: - 총계 · 선택 프리셋 · 섹션 토글

    /// safe 2 / caution 2 / danger 1이 두 카테고리에 나뉘어 담긴 모델.
    private func mixedModel() async -> ScanModel {
        let found = [
            item("safe-a", size: 100, category: .devCache, safety: .safe),
            item("safe-b", size: 200, category: .devCache, safety: .safe),
            item("caution-a", size: 400, category: .xcode, safety: .caution),
            item("caution-b", size: 800, category: .xcode, safety: .caution),
            item("danger-a", size: 1_600, category: .xcode, safety: .danger),
        ]
        let model = ScanModel(scan: stream([found]), removeOne: alwaysSucceeds())
        await model.scan()
        return model
    }

    // TC-1
    @Test("전체 회수 가능량이 선택과 무관하게 계산된다")
    func totalSizeIsIndependentOfSelection() async {
        let model = await mixedModel()

        // 자동 선택은 safe 2개(300B)뿐이지만 총계는 3,100B다
        #expect(model.selection.count == 2)
        #expect(model.items.totalSize == 3_100)
        #expect(!model.formattedTotalSize.isEmpty)
        #expect(model.formattedTotalSize != model.formattedSelectedSize)
    }

    // TC-2
    @Test("안전만 프리셋은 safe만 고른다")
    func safeOnlyPreset() async {
        let model = await mixedModel()
        model.apply(.all)

        model.apply(.safeOnly)

        #expect(model.selectedItems.allSatisfy { $0.safety == .safe })
        #expect(model.selectedItems.count == 2)
    }

    // TC-3
    @Test("권장 프리셋은 danger만 뺀다")
    func recommendedPresetExcludesDangerOnly() async {
        let model = await mixedModel()

        model.apply(.recommended)

        #expect(model.selectedItems.count == 4)
        #expect(!model.selectedItems.contains { $0.safety == .danger })
        #expect(model.selectedItems.contains { $0.safety == .caution })
        // 되돌릴 수 없는 것만 빠졌으므로 회수량이 크게 늘어야 한다
        #expect(model.selectedItems.totalSize == 1_500)
    }

    // TC-4
    @Test("전체·해제 프리셋이 양 극단을 만든다")
    func allAndNonePresets() async {
        let model = await mixedModel()

        model.apply(.all)
        #expect(model.selection.count == 5)
        #expect(model.selectedItems.totalSize == 3_100)

        model.apply(.none)
        #expect(model.selection.isEmpty)
        #expect(!model.hasSelection)
    }

    // TC-5 · TC-6 · TC-7
    @Test("섹션 선택 상태가 세 가지로 판정된다")
    func sectionSelectionStates() async {
        let model = await mixedModel()
        let xcode = model.groups.first { $0.category == .xcode }!

        model.apply(.none)
        #expect(model.selectionState(of: xcode) == .none)

        model.setSelection(true, for: xcode.items[0])
        #expect(model.selectionState(of: xcode) == .partial)

        model.apply(.all)
        #expect(model.selectionState(of: xcode) == .all)
    }

    // TC-8 · TC-9
    @Test("섹션 토글이 부분 선택을 올리고 전체 선택을 내린다")
    func toggleAllRoundTrips() async {
        let model = await mixedModel()
        let xcode = model.groups.first { $0.category == .xcode }!

        model.apply(.none)
        model.setSelection(true, for: xcode.items[0])
        #expect(model.selectionState(of: xcode) == .partial)

        model.toggleAll(in: xcode)              // 부분 → 전체
        #expect(model.selectionState(of: xcode) == .all)

        model.toggleAll(in: xcode)              // 전체 → 해제
        #expect(model.selectionState(of: xcode) == .none)
    }

    // TC-10
    @Test("섹션 토글이 다른 카테고리 선택을 건드리지 않는다")
    func toggleAllLeavesOtherSectionsAlone() async {
        let model = await mixedModel()
        let devCache = model.groups.first { $0.category == .devCache }!
        let xcode = model.groups.first { $0.category == .xcode }!

        model.apply(.none)
        model.toggleAll(in: devCache)
        #expect(model.selectionState(of: devCache) == .all)

        model.toggleAll(in: xcode)
        #expect(model.selectionState(of: devCache) == .all, "다른 섹션이 함께 바뀌었다")

        model.toggleAll(in: xcode)
        #expect(model.selectionState(of: devCache) == .all)
    }
}
