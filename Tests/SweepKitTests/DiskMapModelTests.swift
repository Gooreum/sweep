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
        // 분모보다 많이 세도 100을 넘지 않는다
        #expect(counter.percent(of: 100) == 100)
        #expect(counter.percent(of: 300) == 50)
    }

    // TC-5 · TC-6 (Phase 1)
    @Test("근소한 분모 오차가 100%를 막지 않는다")
    func nearCompleteRoundsToHundred() {
        let counter = ScanCounter()
        // 실측과 같은 상황: 73,947 / 73,953 = 99.99% — 절삭하면 99%가 된다
        for _ in 0..<73_947 { counter.increment() }

        #expect(counter.percent(of: 73_953) == 100, "반올림하지 않아 99%에서 멈춘다")

        // 반올림이 과하지 않은지도 확인한다
        let half = ScanCounter()
        for _ in 0..<50 { half.increment() }
        #expect(half.percent(of: 100) == 50)

        let low = ScanCounter()
        for _ in 0..<1 { low.increment() }
        #expect(low.percent(of: 100) == 1)
        // 99.4%는 아직 99% — 0.5% 미만은 올리지 않는다
        let notYet = ScanCounter()
        for _ in 0..<994 { notYet.increment() }
        #expect(notYet.percent(of: 1_000) == 99)
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

    // MARK: - 삭제 (Step 2)
    //
    // **안전 규칙**: 실패 경로 TC의 대상은 관문이 깨져도 지울 것이 없어야 한다.
    // 실제 삭제를 하는 것은 TC-5 하나뿐이고, 그 대상은 이 테스트가 직접 만든다.

    // TC-2
    @Test("drop이 자식을 빼고 현재 노드 크기를 그만큼 줄인다")
    func dropRemovesChildAndShrinksCurrent() {
        let model = loadedModel()
        let big = model.tiles.first { $0.name == "big" }!

        model.drop(big)

        #expect(model.tiles.map(\.name) == ["small"])
        // 600 - 500. 합계가 안 맞으면 막대 비율이 통째로 틀어진다.
        #expect(model.current?.size == 100)
    }

    // TC-3
    @Test("깊은 곳에서 drop하면 루트 크기까지 줄어든다")
    func dropPropagatesToRoot() {
        let model = loadedModel()
        model.drillDown(into: model.tiles.first { $0.name == "big" }!)
        let leafA = model.tiles.first { $0.name == "a" }!

        model.drop(leafA)

        #expect(model.tiles.map(\.name) == ["b"])
        #expect(model.current?.size == 200)      // big: 500 - 300
        #expect(model.path[0].size == 300)       // root: 600 - 300

        // 위로 올라갔을 때 지운 노드가 되살아나면 안 된다
        model.goUp()
        let big = model.tiles.first { $0.name == "big" }!
        #expect(big.size == 200)
        #expect(big.children.map(\.name) == ["b"])
    }

    // TC-4
    @Test("현재 지점의 자식이 아닌 노드를 drop하면 트리가 그대로다")
    func dropIgnoresNonChild() {
        let model = loadedModel()
        let before = model.path

        // 손자 — 지금 보고 있는 지점의 직접 자식이 아니다
        let grandchild = model.tiles.first { $0.name == "big" }!.children[0]
        model.drop(grandchild)
        // 트리에 아예 없는 노드
        model.drop(DiskUsageNode(url: URL(filePath: "/private/tmp/nowhere"), size: 999))

        #expect(model.path == before, "엉뚱한 노드로 크기가 깎였다")
    }

    // TC-5
    @Test("허용 루트 안의 실제 파일은 지워지고 트리에서도 빠진다")
    func removeDeletesRealFileAndUpdatesTree() async throws {
        let fm = FileManager.default
        let dir = fm.homeDirectoryForCurrentUser
            .appending(path: "Library/Caches/sweep-diskmap-\(UUID().uuidString)")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        let file = dir.appending(path: "target.bin")
        try Data(count: 128).write(to: file)

        let model = DiskMapModel()
        let child = DiskUsageNode(url: file, size: 128)
        model.seed(DiskUsageNode(url: dir, size: 128, children: [child]))

        await model.remove(child, using: Remover(movesToTrash: false))

        #expect(model.removalFailure == nil)
        #expect(model.tiles.isEmpty)
        #expect(model.current?.size == 0)
        #expect(!fm.fileExists(atPath: file.path))
    }

    // TC-6
    @Test("관문이 거부하면 사유가 남고 트리는 변하지 않는다")
    func removeKeepsTreeWhenGateRefuses() async {
        // 만들지도 않은, 허용 루트 밖 경로. 관문이 빠져도 지울 것이 없다.
        let outside = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Documents/sweep-never-exists-\(UUID().uuidString)")

        let model = DiskMapModel()
        let child = DiskUsageNode(url: outside, size: 500)
        model.seed(DiskUsageNode(url: URL(filePath: "/private/tmp/root"),
                                 size: 500, children: [child]))
        let before = model.path

        await model.remove(child)

        #expect(model.removalFailure?.contains("정리 대상 범위 밖입니다") == true)
        // 실패했는데 화면에서 사라지면 사용자는 지워진 줄 안다
        #expect(model.path == before)
    }

    // TC-7
    @Test("clearRemovalFailure가 사유를 지운다")
    func clearRemovalFailureResetsState() async {
        let outside = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Documents/sweep-never-exists-\(UUID().uuidString)")
        let model = DiskMapModel()
        model.seed(DiskUsageNode(url: URL(filePath: "/private/tmp/root"), size: 1,
                                 children: [DiskUsageNode(url: outside, size: 1)]))

        await model.remove(model.tiles[0])
        #expect(model.removalFailure != nil)

        model.clearRemovalFailure()
        #expect(model.removalFailure == nil)
    }

    // TC-8
    @Test("가지치기로 자식 합이 부모보다 커도 크기가 음수로 가지 않는다")
    func dropClampsSizeAtZero() {
        // build가 maxDepth·minimumSize로 가지를 쳐도 부모 size는 전체를 담는다.
        // 그 반대(자식이 부모보다 큰 상태)가 들어와도 음수 크기를 만들면 안 된다.
        let model = DiskMapModel()
        let child = DiskUsageNode(url: URL(filePath: "/private/tmp/root/huge"), size: 900)
        model.seed(DiskUsageNode(url: URL(filePath: "/private/tmp/root"),
                                 size: 100, children: [child]))

        model.drop(child)

        #expect(model.current?.size == 0)
        #expect(model.tiles.isEmpty)
    }

    // TC-10
    @Test("조상 크기도 음수로 가지 않는다")
    func dropClampsAncestorSizeAtZero() {
        // TC-8은 1단 트리라 잎 쪽 클램프만 지난다. 조상 갱신 루프에도
        // 같은 클램프가 있어야 하는데, 그쪽은 별도 트리로만 닿는다.
        let leaf = DiskUsageNode(url: URL(filePath: "/private/tmp/root/mid/leaf"), size: 900)
        let mid = DiskUsageNode(url: URL(filePath: "/private/tmp/root/mid"),
                                size: 100, children: [leaf])
        let model = DiskMapModel()
        model.seed(DiskUsageNode(url: URL(filePath: "/private/tmp/root"),
                                 size: 50, children: [mid]))
        model.drillDown(into: mid)

        model.drop(leaf)

        #expect(model.current?.size == 0)   // mid: 100 - 900
        #expect(model.path[0].size == 0)    // root: 50 - 900
    }
}

/// 가짜 세기 패스를 원하는 시점까지 붙잡아 두는 문.
private final class Gate: @unchecked Sendable {
    private let semaphore = DispatchSemaphore(value: 0)
    func wait() { semaphore.wait() }
    func signal() { semaphore.signal() }
}