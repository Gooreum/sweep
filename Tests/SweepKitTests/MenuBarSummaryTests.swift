import Testing
import Foundation
@testable import SweepKit

@Suite("MenuBarSummary")
@MainActor
struct MenuBarSummaryTests {

    private func item(_ name: String, _ category: ScanCategory, _ size: Int64) -> CleanupItem {
        CleanupItem(url: URL(filePath: "/private/tmp/\(name)"),
                    size: size, category: category, safety: .safe)
    }

    /// 결과를 한 번에 흘리고 끝나는 스트림.
    private func finishing(_ items: [CleanupItem])
        -> @Sendable () -> AsyncStream<ScanCoordinator.Progress> {
        { @Sendable in
            AsyncStream { continuation in
                continuation.yield(ScanCoordinator.Progress(
                    items: items, fraction: 1, elapsed: .seconds(2),
                    estimatedRemaining: nil, finishedScanners: 6, totalScanners: 6))
                continuation.finish()
            }
        }
    }

    /// 스캔 중 상태에서 멈춰 있는 스트림.
    private func stalled(at percent: Int, items: [CleanupItem])
        -> @Sendable () -> AsyncStream<ScanCoordinator.Progress> {
        { @Sendable in
            AsyncStream { continuation in
                continuation.yield(ScanCoordinator.Progress(
                    items: items, fraction: Double(percent) / 100, elapsed: .seconds(9),
                    estimatedRemaining: .seconds(20),
                    finishedScanners: 3, totalScanners: 6))
                // finish하지 않는다 — scanning에 머문다
            }
        }
    }

    // TC-1
    @Test("스캔한 적이 없으면 회수 가능량이 0이 아니라 nil이다")
    func neverScannedIsNilNotZero() {
        let model = ScanModel(scan: finishing([]))
        let summary = model.summary

        // "0바이트"라고 쓰면 "훑어봤는데 없다"는 뜻이 된다.
        // 아직 훑지 않은 것과 훑었는데 없는 것은 화면에서 달라야 한다.
        #expect(summary.reclaimable == nil)
        #expect(summary.breakdown.isEmpty)
        #expect(summary.isScanning == false)
        #expect(summary.scanPercent == nil)
    }

    // TC-2
    @Test("훑었는데 아무것도 못 찾아도 nil이다")
    func scannedButFoundNothing() async {
        let model = ScanModel(scan: finishing([]))
        await model.scan()

        let summary = model.summary
        #expect(summary.reclaimable == nil)
        #expect(summary.reclaimableBytes == 0)
        #expect(summary.breakdown.isEmpty)
    }

    // TC-3
    @Test("기능별 내역이 발견된 만큼 줄로 나온다")
    func breakdownHasOneRowPerFeature() async {
        let model = ScanModel(scan: finishing([
            item("임시", .runawayTemp, 400),
            item("빌드", .xcode, 600),
            item("큰것", .largeFile, 1_000),
            item("사본", .duplicate, 200),
        ]))
        await model.scan()

        let summary = model.summary

        #expect(summary.breakdown.count == 3)
        #expect(summary.breakdown.map(\.feature) == [.junk, .largeFile, .duplicate])
        // 정크는 임시 400 + 빌드 600
        let junk = try? #require(summary.breakdown.first)
        #expect(junk?.feature == .junk)
        #expect(junk?.bytes == 1_000)
        #expect(junk?.count == 2)

        for row in summary.breakdown {
            #expect(!row.formattedSize.isEmpty)
            #expect(row.count > 0)
        }
    }

    // TC-4
    @Test("발견량이 0인 기능은 내역에서 빠진다")
    func emptyFeaturesAreOmitted() async {
        let model = ScanModel(scan: finishing([item("캐시", .devCache, 500)]))
        await model.scan()

        let summary = model.summary

        // "중복 0개"는 알려줄 것이 아니다 — 자리만 차지한다
        #expect(summary.breakdown.count == 1)
        #expect(summary.breakdown.map(\.feature) == [.junk])
        #expect(!summary.breakdown.contains { $0.feature == .duplicate })
    }

    // TC-5
    @Test("내역 합계가 회수 가능량과 같다")
    func breakdownSumMatchesTotal() async {
        let items = [
            item("임시", .runawayTemp, 1_111),
            item("빌드", .xcode, 2_222),
            item("캐시", .devCache, 3_333),
            item("묵은", .staleCache, 4_444),
            item("큰것", .largeFile, 5_555),
            item("사본", .duplicate, 6_666),
        ]
        let model = ScanModel(scan: finishing(items))
        await model.scan()

        let summary = model.summary

        // 패널과 본 화면이 다른 숫자를 말하면 안 된다
        #expect(summary.breakdown.reduce(0) { $0 + $1.bytes } == summary.reclaimableBytes)
        #expect(summary.reclaimableBytes == items.totalSize)
        #expect(summary.reclaimable == items.formattedTotalSize)
    }

    // TC-6
    @Test("내역 개수 합계가 전체 항목 수와 같다")
    func breakdownCountMatchesItemCount() async {
        let items = [
            item("a", .runawayTemp, 10), item("b", .xcode, 20),
            item("c", .devCache, 30), item("d", .staleCache, 40),
            item("e", .largeFile, 50), item("f", .duplicate, 60),
            item("g", .duplicate, 70),
        ]
        let model = ScanModel(scan: finishing(items))
        await model.scan()

        let summary = model.summary

        // 어느 항목도 빠지거나 두 번 세어지면 안 된다
        #expect(summary.breakdown.reduce(0) { $0 + $1.count } == items.count)
    }

    // TC-7
    @Test("스캔 중이면 퍼센트를 들고 바쁨으로 답한다")
    func scanningReportsPercent() async {
        let model = ScanModel(scan: stalled(at: 43, items: [item("a", .devCache, 100)]))
        let running = Task { await model.scan() }
        // `scan()`은 진입 즉시 phase를 .scanning(0)으로 올린다. isBusy만 보고
        // 기다리면 Progress가 도착하기 전에 빠져나온다 — 결과가 들어올 때까지 기다린다.
        for _ in 0..<200 where model.items.isEmpty { await Task.yield() }

        let summary = model.summary
        #expect(summary.isScanning == true)
        #expect(summary.scanPercent == 43)
        // 도는 중에도 지금까지 찾은 것은 보여준다
        #expect(summary.reclaimable != nil)

        running.cancel()
    }

    // TC-8
    @Test("스캔이 끝나면 퍼센트가 사라진다")
    func finishedHasNoPercent() async {
        let model = ScanModel(scan: finishing([item("a", .devCache, 100)]))
        await model.scan()

        let summary = model.summary
        #expect(summary.isScanning == false)
        #expect(summary.scanPercent == nil)
        #expect(summary.reclaimable != nil)
    }

    @Test("내역이 발견량 큰 순서로 정렬된다")
    func breakdownSortedBySize() async {
        // 일부러 작은 것을 먼저 넣는다 — 입력 순서를 따라가면 안 된다.
        let model = ScanModel(scan: finishing([
            item("사본", .duplicate, 100),
            item("캐시", .devCache, 5_000),
            item("큰것", .largeFile, 900),
        ]))
        await model.scan()

        let rows = model.summary.breakdown

        #expect(rows.map(\.feature) == [.junk, .largeFile, .duplicate])
        #expect(rows.map(\.bytes) == [5_000, 900, 100])
        // 내림차순이 깨지지 않는지 직접 확인
        #expect(zip(rows, rows.dropFirst()).allSatisfy { $0.bytes >= $1.bytes })
    }

    @Test("요약은 AppModel이 아니라 그 모델 자신에서 나온다")
    func summaryComesFromItsOwnModel() async {
        // 주입된 모델로 그리는 화면(단계 하니스)에서 AppModel을 거치면
        // 전혀 다른(빈) 모델을 보게 되어 목록이 통째로 사라진다.
        let stub = ScanModel(scan: finishing([item("캐시", .devCache, 5_000)]))
        await stub.scan()

        let app = AppModel()   // 아무것도 스캔하지 않은 상태

        #expect(stub.summary.reclaimable != nil)
        #expect(stub.summary.breakdown.count == 1)
        // AppModel의 요약은 자기 smartScan 모델을 본다 — 비어 있다
        #expect(app.menuBarSummary.breakdown.isEmpty)
        // 둘이 같은 값을 주면 안 된다
        #expect(stub.summary.reclaimableBytes != app.menuBarSummary.reclaimableBytes)
    }
}
