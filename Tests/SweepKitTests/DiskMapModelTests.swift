import Testing
import Foundation
@testable import SweepKit

@Suite("DiskMapModel")
@MainActor
struct DiskMapModelTests {

    /// 3단 트리: root → [big(자식 2), small(자식 없음)]
    private func sampleTree() -> DiskUsageNode {
        let leafA = DiskUsageNode(url: URL(filePath: "/private/tmp/root/big/a"), size: 300)
        let leafB = DiskUsageNode(url: URL(filePath: "/private/tmp/root/big/b"), size: 200)
        let big = DiskUsageNode(url: URL(filePath: "/private/tmp/root/big"),
                                size: 500, children: [leafA, leafB])
        let small = DiskUsageNode(url: URL(filePath: "/private/tmp/root/small"), size: 100)
        return DiskUsageNode(url: URL(filePath: "/private/tmp/root"),
                             size: 600, children: [big, small])
    }

    private func loadedModel() -> DiskMapModel {
        let model = DiskMapModel()
        model.seed(sampleTree())
        return model
    }

    /// 세기·집계를 즉시 끝내는 가짜 모델.
    private func fakeModel(entries: Int = 3) -> DiskMapModel {
        let tree = sampleTree()
        return DiskMapModel(
            countEntries: { _, onCounted in onCounted(entries); return entries },
            buildTree: { _, onScanned in
                for _ in 0..<entries { onScanned() }
                return tree
            })
    }

    // TC-2
    @Test("초기 상태는 비어 있다")
    func initialStateIsEmpty() {
        let model = DiskMapModel()

        #expect(model.path.isEmpty)
        #expect(model.current == nil)
        #expect(model.tiles.isEmpty)
        #expect(!model.isScanning)
        #expect(!model.canGoUp)
    }

    // TC-3
    @Test("타일을 누르면 한 단계 내려간다")
    func drillDownPushesPath() {
        let model = loadedModel()
        let big = model.tiles.first { $0.name == "big" }!

        model.drillDown(into: big)

        #expect(model.path.count == 2)
        #expect(model.current?.name == "big")
        #expect(model.tiles.map(\.name).sorted() == ["a", "b"])
        #expect(model.canGoUp)
    }

    // TC-4
    @Test("자식이 없는 노드로는 내려가지 않는다")
    func drillDownIntoLeafIsIgnored() {
        let model = loadedModel()
        let small = model.tiles.first { $0.name == "small" }!

        model.drillDown(into: small)

        #expect(model.path.count == 1, "빈 화면으로 들어갔다")
        #expect(model.current?.name == "root")
    }

    // TC-5
    @Test("위로 가면 이전 단계로 돌아온다")
    func goUpPopsPath() {
        let model = loadedModel()
        model.drillDown(into: model.tiles.first { $0.name == "big" }!)
        #expect(model.canGoUp)

        model.goUp()

        #expect(model.path.count == 1)
        #expect(model.current?.name == "root")
        #expect(!model.canGoUp)

        // 루트에서 한 번 더 눌러도 비어버리지 않는다
        model.goUp()
        #expect(model.path.count == 1)
    }

    // TC-6
    @Test("breadcrumb을 누르면 그 지점까지만 남는다")
    func jumpTruncatesPath() {
        let model = loadedModel()
        model.drillDown(into: model.tiles.first { $0.name == "big" }!)
        #expect(model.path.count == 2)

        model.jump(to: 0)

        #expect(model.path.count == 1)
        #expect(model.current?.name == "root")

        // 범위 밖 인덱스는 무시된다
        model.jump(to: 99)
        #expect(model.path.count == 1)
    }

    // TC-7
    @Test("선택 가능한 시작점이 허용 루트와 같다")
    func rootsMatchAllowedRoots() {
        let model = DiskMapModel()
        #expect(model.availableRoots == ProtectedPaths.allowedRoots)
        #expect(!model.availableRoots.isEmpty)
    }

    // TC-1 · TC-2
    @Test("load가 주입된 트리로 경로를 초기화하고 단계가 전이된다")
    func loadSeedsPathFromInjectedTree() async {
        let model = fakeModel()

        #expect(model.loadPhase == nil)
        await model.load(URL(filePath: "/private/tmp/root"))

        #expect(model.path.count == 1)
        #expect(model.current?.name == "root")
        #expect(model.loadPhase == nil, "완료 후에도 로딩 상태가 남아 있다")
        #expect(!model.isScanning)
    }

    // TC-3 · TC-4
    @Test("퍼센트가 0~100을 벗어나지 않는다")
    func percentIsClamped() {
        let counter = ScanCounter()

        // 분모 0 — 0으로 나누지 않는다
        #expect(counter.percent(of: 0) == 0)

        for _ in 0..<150 { counter.increment() }
        // 분모보다 많이 세도 100을 넘지 않는다 (실측 0.32% 오차가 있다)
        #expect(counter.percent(of: 100) == 100)
        #expect(counter.percent(of: 300) == 50)
    }

    // TC-5
    @Test("진행 카운터가 동시 증가에서도 정확하다")
    func counterIsThreadSafe() async {
        let counter = ScanCounter()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<8 {
                group.addTask { for _ in 0..<1_000 { counter.increment() } }
            }
        }

        #expect(counter.value == 8_000)
    }

    // TC-2
    @Test("분모가 오기 전에는 세는 중 단계를 보여준다")
    func countingPhaseComesFirst() async {
        let tree = sampleTree()
        // 세기를 붙잡아 둔다. 시간에 기대면 부하에 따라 결과가 흔들린다.
        let gate = Gate()
        let model = DiskMapModel(
            countEntries: { _, onCounted in
                onCounted(5)
                gate.wait()
                return 10
            },
            buildTree: { _, onScanned in
                for _ in 0..<10 { onScanned() }
                return tree
            })

        async let load: Void = model.load(URL(filePath: "/private/tmp/root"))

        // load가 시작될 때까지 양보한다
        while model.loadPhase == nil { await Task.yield() }

        // 아직 분모가 없으므로 퍼센트를 지어내지 않는다
        guard case .counting = model.loadPhase else {
            Issue.record("세는 중이 아니다: \(String(describing: model.loadPhase))")
            gate.signal()
            await load
            return
        }

        gate.signal()
        await load
        #expect(model.loadPhase == nil)
        #expect(model.current?.name == "root")
    }

    // TC-3
    @Test("같은 루트로 두 번 로드해도 안전하다")
    func repeatedLoadIsSafe() async {
        let model = fakeModel()
        let root = URL(filePath: "/private/tmp/root")

        await model.load(root)
        #expect(model.path.count == 1)

        await model.load(root)

        #expect(model.path.count == 1, "경로가 쌓였다")
        #expect(model.loadPhase == nil)
    }

    // TC-4
    @Test("다른 루트를 로드하면 경로가 통째로 갈아끼워진다")
    func loadingAnotherRootReplacesPath() async {
        let model = fakeModel()
        await model.load(URL(filePath: "/private/tmp/root"))
        model.drillDown(into: model.tiles.first { $0.name == "big" }!)
        #expect(model.path.count == 2)

        // 새 루트를 로드하면 드릴다운 경로가 남으면 안 된다
        await model.load(URL(filePath: "/private/tmp/other"))

        #expect(model.path.count == 1)
        #expect(!model.canGoUp)
    }
}

/// 가짜 세기 패스를 원하는 시점까지 붙잡아 두는 문.
private final class Gate: @unchecked Sendable {
    private let semaphore = DispatchSemaphore(value: 0)
    func wait() { semaphore.wait() }
    func signal() { semaphore.signal() }
}