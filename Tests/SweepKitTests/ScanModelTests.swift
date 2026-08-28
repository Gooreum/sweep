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
        let model = ScanModel(scan: { [] })

        #expect(model.phase == .idle)
        #expect(model.items.isEmpty)
        #expect(model.selection.isEmpty)
        #expect(model.report == nil)
    }

    // TC-2
    @Test("스캔하면 results로 전이하고 항목이 채워진다")
    func scanPopulatesItems() async {
        let found = [item("a"), item("b")]
        let model = ScanModel(scan: { found })

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
        let model = ScanModel(scan: { found })

        await model.scan()

        #expect(model.selection.count == 1)
        #expect(model.selectedItems.map(\.displayName) == ["safe.bin"])
        // 되돌릴 수 없는 것이 기본 선택에 들어가면 안 된다
        #expect(!model.selectedItems.contains { $0.safety == .danger })
    }

    // TC-4
    @Test("결과가 0건이어도 results로 전이한다")
    func emptyScanStillTransitions() async {
        let model = ScanModel(scan: { [] })

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
        let model = ScanModel(scan: { found })

        await model.scan()

        #expect(model.groups.map(\.category) == [.runawayTemp, .xcode, .devCache, .duplicate])
        #expect(model.groups.allSatisfy { $0.items.count == 1 })
    }

    // TC-6
    @Test("삭제에 성공한 항목이 목록과 선택에서 빠진다")
    func successfulRemovalsLeaveTheList() async {
        let found = [item("a"), item("b")]
        let model = ScanModel(scan: { found }, removeOne: alwaysSucceeds())

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
        let model = ScanModel(scan: { found }, removeOne: fails(["blocked"]))

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
        let model = ScanModel(scan: { found }, removeOne: alwaysSucceeds())

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
        let model = ScanModel(scan: { found }, removeOne: alwaysSucceeds())

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
}
