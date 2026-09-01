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
            countEntries: { _, _, onCounted in onCounted(entries); return entries },
            buildTree: { _, _, onScanned in
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

    // TC-8
    @Test("선택 가능한 시작점이 정리 루트보다 넓다")
    func rootsGoBeyondCleanupScope() {
        let model = DiskMapModel()
        let paths = Set(model.availableRoots.map { $0.url.standardizedFileURL.path })

        #expect(!model.availableRoots.isEmpty)
        // 정리 루트는 하나도 잃지 않는다.
        // 임시 컨테이너(`.../C`, `.../T`)만 "앱 임시 폴더" 하나로 묶인다 —
        // 같은 라벨이 두 줄 뜨면 고를 때 헷갈린다.
        func isTemporary(_ path: String) -> Bool {
            path.hasPrefix("/var/folders/") || path.hasPrefix("/private/var/folders/")
        }
        for root in ProtectedPaths.allowedRoots where !isTemporary(root.path) {
            #expect(paths.contains(root.standardizedFileURL.path),
                    "정리 루트가 빠졌다: \(root.path)")
        }
        // 그리고 그보다 넓어야 한다 — 정리 범위와 같으면 고치기 전으로 돌아간 것이다
        #expect(model.availableRoots.count > ProtectedPaths.allowedRoots.count)
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
            countEntries: { _, _, onCounted in
                onCounted(5)
                gate.wait()
                return 10
            },
            buildTree: { _, _, onScanned in
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

    // MARK: - 시작 지점 (탭 왕복에도 머리말이 남아야 한다)

    // TC-5
    @Test("새 모델은 아직 아무 시작 지점도 고르지 않았다")
    func selectedRootStartsNil() {
        #expect(DiskMapModel().selectedRoot == nil)
    }

    // TC-4
    @Test("load가 시작 지점을 모델에 남긴다")
    func loadRecordsSelectedRoot() async {
        let model = fakeModel()
        let root = URL(filePath: "/private/tmp/root")

        await model.load(root)

        // 뷰가 들고 있으면 탭을 옮겼다 오는 순간 nil로 돌아가,
        // 트리는 그대로인데 머리말만 "선택하세요"가 된다.
        #expect(model.selectedRoot == root)
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

    // TC-6
    @Test("drop이 조상의 '읽을 수 없음'을 지우지 않는다")
    func dropPreservesReadability() {
        // 조상을 다시 만들 때 isReadable을 안 넘기면 기본값 true로 되살아나
        // "읽을 수 없음" 표시가 조용히 사라진다.
        let dir = URL(filePath: "/private/tmp/root")
        let child = DiskUsageNode(url: dir.appending(path: "지울것"), size: 100)
        let model = DiskMapModel()
        model.seed(DiskUsageNode(url: dir, size: 100, children: [child],
                                 isReadable: false))

        model.drop(child)

        #expect(model.current?.isReadable == false)
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

    // MARK: - 지울 수 있는지 (범위 확대)

    /// 정리 루트 안(지울 수 있음)과 밖(못 지움)을 한 지점에 섞어 둔 트리.
    private func mixedRemovabilityTree() -> DiskUsageNode {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let ok = DiskUsageNode(url: home.appending(path: "Library/Caches/지울수있음"),
                               size: 300)
        let blocked = DiskUsageNode(url: home.appending(path: "Documents/못지움"),
                                    size: 200,
                                    children: [DiskUsageNode(
                                        url: home.appending(path: "Documents/못지움/안"),
                                        size: 200)])
        return DiskUsageNode(url: home, size: 500, children: [ok, blocked])
    }

    // TC-6
    @Test("트리를 넣으면 지금 자식들의 삭제 가능 여부가 채워진다")
    func vetoesFillOnSeed() {
        let model = DiskMapModel()
        model.seed(mixedRemovabilityTree())

        let ok = model.tiles.first { $0.name == "지울수있음" }!
        let blocked = model.tiles.first { $0.name == "못지움" }!

        #expect(model.veto(for: ok) == nil, "정리 루트 안인데 막혔다")
        #expect(model.veto(for: blocked) != nil, "허용 루트 밖인데 통과했다")
    }

    // TC-7
    @Test("드릴다운하면 새 지점의 자식들로 갈아 끼워진다")
    func vetoesFollowDrillDown() {
        let model = DiskMapModel()
        model.seed(mixedRemovabilityTree())
        let blocked = model.tiles.first { $0.name == "못지움" }!

        model.drillDown(into: blocked)

        // 이전 지점의 키가 남아 있으면 화면과 어긋난다
        #expect(model.tileVetoes.count == 1)
        #expect(model.tileVetoes.keys.first?.lastPathComponent == "안")
    }

    // TC-8
    @Test("목록에 없는 노드를 물으면 nil을 돌려주고 크래시하지 않는다")
    func vetoForUnknownNodeIsNil() {
        let model = DiskMapModel()
        model.seed(mixedRemovabilityTree())

        let stranger = DiskUsageNode(url: URL(filePath: "/private/tmp/남의것"), size: 1)
        #expect(model.veto(for: stranger) == nil)
    }

    // MARK: - 중단 (긴 순회)

    // TC-2
    @Test("CancelFlag는 cancel 전후로 값이 바뀐다")
    func cancelFlagFlips() {
        let flag = CancelFlag()
        #expect(flag.isCancelled == false)
        flag.cancel()
        #expect(flag.isCancelled == true)
    }

    // TC-3
    @Test("중단 신호가 서 있으면 순회가 자식으로 내려가지 않는다")
    func buildStopsWhenCancelled() throws {
        let fm = FileManager.default
        let root = URL(filePath: NSTemporaryDirectory())
            .appending(path: "sweep-cancel-\(UUID().uuidString)")
        try fm.createDirectory(at: root.appending(path: "안쪽"),
                               withIntermediateDirectories: true)
        try Data(count: 2048).write(to: root.appending(path: "안쪽/파일.bin"))
        defer { try? fm.removeItem(at: root) }

        let tree = DiskUsageTree.build(at: root, minimumSize: 1,
                                       isCancelled: { true })

        // 첫 자식으로 내려가기 전에 끊긴다
        #expect(tree.children.isEmpty)
        #expect(tree.size == 0)
    }

    // TC-4 · TC-6
    @Test("중단하면 보던 트리가 그대로 남고 반쪽 결과로 덮이지 않는다")
    func cancelKeepsExistingTree() async {
        let replacement = DiskUsageNode(url: URL(filePath: "/private/tmp/other"), size: 1)
        let gate = Gate()
        let model = DiskMapModel(
            countEntries: { _, _, onCounted in onCounted(1); return 1 },
            buildTree: { _, _, onScanned in
                onScanned()
                gate.wait()          // 중단을 누를 때까지 붙잡아 둔다
                return replacement
            })
        model.seed(sampleTree())
        let before = model.path

        let running = Task { await model.load(URL(filePath: "/private/tmp/root")) }
        for _ in 0..<200 where !model.isScanning { await Task.yield() }
        #expect(model.isScanning, "로드가 시작되지 않아 TC가 공허하다")

        model.cancelLoad()
        gate.signal()
        await running.value

        // 멈췄다고 보던 것까지 사라지면 처음부터 다시 해야 한다
        #expect(model.path == before, "중단했는데 트리가 바뀌었다")
        #expect(model.loadPhase == nil)
    }

    @Test("중단해서 트리가 없어도 고른 시작점으로 다시 훑는다")
    func reloadRecoversAfterCancel() async {
        let tree = deepTree()
        let source = TreeSource([tree])
        let model = sourcedModel(source)
        model.selectedRoot = URL(filePath: "/private/tmp/root")
        #expect(model.path.isEmpty, "트리가 있으면 이 TC는 다른 것을 잰다")

        await model.reload()

        // path만 보고 판단하면 중단한 순간 되돌아갈 길이 막힌다
        #expect(model.path.map(\.name) == ["root"])
        #expect(source.callCount == 1)
    }

    // TC-5
    @Test("로드 중이 아닐 때 중단해도 아무 일도 없다")
    func cancelWhenIdleIsHarmless() {
        let model = loadedModel()
        let before = model.path

        model.cancelLoad()

        #expect(model.path == before)
        #expect(model.loadPhase == nil)
    }

    // MARK: - 다시 읽기 (Phase 2)

    /// 3단 트리: root → big → a → a1
    private func deepTree(missingA: Bool = false, emptyA: Bool = false) -> DiskUsageNode {
        let dir = URL(filePath: "/private/tmp/root")
        let a1 = DiskUsageNode(url: dir.appending(path: "big/a/a1"), size: 200)
        let a = DiskUsageNode(url: dir.appending(path: "big/a"), size: 300,
                              children: emptyA ? [] : [a1])
        let b = DiskUsageNode(url: dir.appending(path: "big/b"), size: 200)
        let big = DiskUsageNode(url: dir.appending(path: "big"), size: 500,
                                children: missingA ? [b] : [a, b])
        let small = DiskUsageNode(url: dir.appending(path: "small"), size: 100)
        return DiskUsageNode(url: dir, size: 600, children: [big, small])
    }

    private func sourcedModel(_ source: TreeSource) -> DiskMapModel {
        DiskMapModel(
            countEntries: { _, _, onCounted in onCounted(1); return 1 },
            buildTree: { _, _, onScanned in onScanned(); return source.next() })
    }

    /// root → big → a 까지 내려간 모델을 만든다.
    private func drilledThreeDeep(_ model: DiskMapModel) async {
        await model.load(URL(filePath: "/private/tmp/root"))
        model.drillDown(into: model.tiles.first { $0.name == "big" }!)
        model.drillDown(into: model.tiles.first { $0.name == "a" }!)
    }

    // TC-2
    @Test("다시 읽어도 파고든 자리를 잃지 않는다")
    func reloadRestoresDrillPath() async {
        let source = TreeSource([deepTree(), deepTree()])
        let model = sourcedModel(source)
        await drilledThreeDeep(model)
        #expect(model.path.map(\.name) == ["root", "big", "a"])

        await model.reload()

        // 세 단계 파고든 뒤 맨 위로 튕기면 세 번 다시 눌러야 한다
        #expect(model.path.map(\.url) == [
            URL(filePath: "/private/tmp/root"),
            URL(filePath: "/private/tmp/root/big"),
            URL(filePath: "/private/tmp/root/big/a"),
        ])
        #expect(model.tiles.map(\.name) == ["a1"])
    }

    // TC-3
    @Test("다시 읽었더니 중간이 사라졌으면 거기서 멈춘다")
    func reloadStopsWhereTheTrailBreaks() async {
        // 두 번째로 읽을 때 big 아래 a가 없어졌다 (앱 밖에서 지워진 상황)
        let source = TreeSource([deepTree(), deepTree(missingA: true)])
        let model = sourcedModel(source)
        await drilledThreeDeep(model)

        await model.reload()

        // 없는 자리를 지어내지 않는다. 있는 데까지만 복원한다.
        #expect(model.path.map(\.name) == ["root", "big"])
        #expect(model.tiles.map(\.name) == ["b"])
    }

    // TC-3
    @Test("다시 읽었더니 그 폴더가 비었으면 들어가지 않는다")
    func reloadStopsBeforeEmptiedFolder() async {
        // 폴더는 남아 있는데 안이 통째로 비워진 상황
        let source = TreeSource([deepTree(), deepTree(emptyA: true)])
        let model = sourcedModel(source)
        await drilledThreeDeep(model)

        await model.reload()

        // `drillDown`이 빈 노드 진입을 막는 것과 같은 이유다 —
        // 빈 화면으로 들어가면 사용자가 길을 잃는다.
        #expect(model.path.map(\.name) == ["root", "big"])
    }

    // TC-4
    @Test("아직 아무것도 안 읽었으면 다시 읽기는 아무 일도 하지 않는다")
    func reloadDoesNothingWithoutTree() async {
        let source = TreeSource([deepTree()])
        let model = sourcedModel(source)

        await model.reload()

        #expect(model.path.isEmpty)
        // 무엇을 다시 읽을지 모르는데 순회부터 시작하면 안 된다
        #expect(source.callCount == 0)
    }

    // TC-5
    @Test("루트만 보고 있을 때 다시 읽으면 루트가 새 트리로 바뀐다")
    func reloadAtRootReplacesTree() async {
        let smaller = DiskUsageNode(url: URL(filePath: "/private/tmp/root"), size: 100,
                                    children: [DiskUsageNode(
                                        url: URL(filePath: "/private/tmp/root/small"), size: 100)])
        let source = TreeSource([deepTree(), smaller])
        let model = sourcedModel(source)
        await model.load(URL(filePath: "/private/tmp/root"))

        await model.reload()

        #expect(model.path.count == 1)
        #expect(model.current?.size == 100)
        #expect(model.tiles.map(\.name) == ["small"])
    }

    // TC-6
    @Test("다시 읽기는 순회를 정확히 한 번만 돈다")
    func reloadScansExactlyOnce() async {
        let source = TreeSource([deepTree(), deepTree()])
        let model = sourcedModel(source)
        await drilledThreeDeep(model)
        let afterLoad = source.callCount

        await model.reload()

        // 10초짜리 순회가 두 번 돌면 20초가 된다
        #expect(source.callCount - afterLoad == 1)
    }

}

/// 호출할 때마다 다른 트리를 내주고 몇 번 불렸는지 센다.
///
/// `buildTree`는 `Task.detached`에서 불리므로 잠금이 필요하다.
private final class TreeSource: @unchecked Sendable {
    private let lock = NSLock()
    private var queue: [DiskUsageNode]
    private let last: DiskUsageNode
    private var calls = 0

    init(_ trees: [DiskUsageNode]) {
        queue = trees
        last = trees[trees.count - 1]
    }

    /// 준비한 트리를 순서대로, 다 쓰면 마지막 것을 계속 내준다.
    func next() -> DiskUsageNode {
        lock.lock(); defer { lock.unlock() }
        calls += 1
        return queue.isEmpty ? last : queue.removeFirst()
    }

    var callCount: Int {
        lock.lock(); defer { lock.unlock() }
        return calls
    }
}

/// 가짜 세기 패스를 원하는 시점까지 붙잡아 두는 문.
private final class Gate: @unchecked Sendable {
    private let semaphore = DispatchSemaphore(value: 0)
    func wait() { semaphore.wait() }
    func signal() { semaphore.signal() }
}