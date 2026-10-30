import Foundation
import Observation

/// 여러 스레드에서 올라오는 진행 신호를 모으는 카운터.
///
/// 항목마다 `@MainActor`로 건너오면 보고가 스캔보다 비싸진다.
/// 여기에 쌓아 두고 UI가 주기적으로 읽어간다.
public final class ScanCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    public init() {}

    public func increment() {
        lock.lock(); defer { lock.unlock() }
        count += 1
    }

    /// 읽은 바이트처럼 한 번에 여러 개를 더한다.
    public func add(_ amount: Int64) {
        lock.lock(); defer { lock.unlock() }
        count += Int(amount)
    }

    public var value: Int {
        lock.lock(); defer { lock.unlock() }
        return count
    }

    /// 절대값으로 덮어쓴다. 세기 패스는 자기 누적치를 그대로 보고한다.
    public func set(_ newValue: Int) {
        lock.lock(); defer { lock.unlock() }
        count = newValue
    }

    /// 0~100. 반올림한다.
    public func percent(of total: Int) -> Int {
        guard total > 0 else { return 0 }
        return min(100, max(0, (value * 200 + total) / (total * 2)))
    }
}

/// 디스크 맵 화면의 상태. 드릴다운 경로를 스택으로 들고 있는다.
///
/// SwiftUI를 import하지 않는다. 뷰 없이 드릴다운·복귀 로직을 테스트할 수 있어야 한다.
@MainActor
@Observable
public final class DiskMapModel {

    /// 로딩 단계.
    ///
    /// 예전에는 항목 수를 먼저 세서 분모로 썼다. 그 세기가 디스크를 한 번 더 훑어
    /// 집계와 읽기를 나눠 먹었다. 이제 분모는 **이미 아는 크기**다 — 이 시작점의
    /// 지난 결과, 없으면 볼륨 사용량. 둘 다 없으면 퍼센트를 지어내지 않는다.
    public enum LoadPhase: Equatable, Sendable {
        /// 얼마나 읽어야 하는지 모른다. 지금까지 읽은 양만 보여 준다.
        case reading(bytes: Int64)
        /// 크기를 재는 중. 0~100. 분모가 추정이라 끝나기 전에는 99를 넘지 않는다.
        case measuring(percent: Int)
    }

    /// 지금 보고 있는 지점까지의 경로. 첫 원소가 루트다.
    public private(set) var path: [DiskUsageNode] = [] {
        didSet { refreshVerdicts() }
    }

    /// 지금 보이는 자식들의 판정 — 지워도 됨 / 확인 필요 / 보호됨.
    ///
    /// `ProtectedPaths.validate`는 경로를 정규화하고 캐시를 훑는다. 매 렌더마다
    /// 행 수만큼 부르면 스크롤이 버벅인다 — `path`가 바뀔 때만 계산한다.
    public private(set) var tileVerdicts: [URL: RemovalVerdict] = [:]
    public private(set) var loadPhase: LoadPhase?

    /// Picker가 고른 시작 지점.
    ///
    /// 뷰가 들고 있으면 탭을 옮겼다 오는 순간 nil로 돌아가, 트리는 그대로인데
    /// 머리말만 "선택하세요"가 된다.
    public var selectedRoot: URL?

    public var isScanning: Bool { loadPhase != nil }

    /// 마지막으로 끝까지 읽은 때. 중단하면 바뀌지 않는다. 사이드바 완료 표시가 읽는다.
    public private(set) var completedAt: Date?

    /// 지금 보이는 트리가 **지난번에 읽은 것**이면 그때. 새로 다 읽으면 nil.
    ///
    /// 볼륨 전체는 몇 분이 걸린다. 그동안 빈 진행 화면 대신 지난 결과를 보여 주고
    /// 뒤에서 새로 읽는다. 화면은 이 값으로 "지난 결과"라고 알린다.
    public private(set) var cachedAt: Date?

    /// 끝까지 읽었을 때 한 번. 앱이 완료 알림을 보낸다 — 알림 센터는 SweepKit 밖의 일이다.
    public var onCompleted: (@MainActor () -> Void)?

    private let buildTree:
        @Sendable (URL, CancelFlag, @escaping @Sendable (Int64) -> Void) -> DiskUsageNode
    private let expectedBytes: @Sendable (URL) -> Int64?
    private let cache: DiskMapCache?
    /// 한 자리만 다시 잰다. 읽는 동안 옮긴 것을 맞춰 볼 때 쓴다(`reconcile`).
    private let rebuild: @Sendable (URL, Int) -> DiskUsageNode
    private let maxDepth: Int

    /// 읽는 동안 다른 화면에서 옮긴 것. 다 읽은 트리에 다시 맞춰 본다.
    private var movesDuringLoad: [TrashMove] = []

    /// 지금 도는 순회의 중단 신호.
    private var cancelFlag: CancelFlag?

    /// 집계·분모·저장소를 주입할 수 있게 열어 둔다 — 실제 스캔은 10초가 넘어 테스트에 쓸 수 없다.
    /// `cache`가 nil이면 지난 결과를 쓰지도 남기지도 않는다.
    public init(
        buildTree: @escaping @Sendable
            (URL, CancelFlag, @escaping @Sendable (Int64) -> Void) -> DiskUsageNode
            = { url, flag, onBytes in
                DiskUsageTree.build(at: url,
                                    isCancelled: { flag.isCancelled },
                                    onBytesScanned: onBytes)
            },
        expectedBytes: @escaping @Sendable (URL) -> Int64? = DiskMapModel.volumeUsedBytes,
        cache: DiskMapCache? = nil,
        rebuild: @escaping @Sendable (URL, Int) -> DiskUsageNode
            = { DiskUsageTree.build(at: $0, maxDepth: $1) },
        maxDepth: Int = DiskUsageTree.defaultMaxDepth
    ) {
        self.buildTree = buildTree
        self.expectedBytes = expectedBytes
        self.cache = cache
        self.rebuild = rebuild
        self.maxDepth = maxDepth
    }

    /// 시작점이 볼륨 자신(`/`, 외장 디스크)이면 그 볼륨의 사용량. 아니면 모른다.
    public static let volumeUsedBytes: @Sendable (URL) -> Int64? = { url in
        guard let values = try? url.resourceValues(forKeys: [
            .isVolumeKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey,
        ]), values.isVolume == true,
            let total = values.volumeTotalCapacity,
            let available = values.volumeAvailableCapacity
        else { return nil }
        return Int64(max(0, total - available))
    }

    /// 사용자가 고를 수 있는 시작점.
    ///
    /// 정리 범위와 **일부러 다르다.** 디스크 맵은 "용량이 어디 갔나"를 찾는
    /// 도구라 못 지우는 곳도 보여야 한다. 지울 수 있는지는 행마다 따로 알린다.
    public var availableRoots: [DiskMapRoot] { DiskMapRoot.all }

    public var current: DiskUsageNode? { path.last }
    public var tiles: [DiskUsageNode] { current?.children ?? [] }

    public var canGoUp: Bool { path.count > 1 }

    /// 한 번만 훑는다. 진행률의 분모는 이미 아는 크기다(`LoadPhase` 참고).
    ///
    /// 다른 시작점에서 왔고 지난 결과가 있으면 **그것부터 보여 주고** 뒤에서 새로 읽는다.
    /// 같은 시작점을 다시 읽을 때는 지금 화면을 그대로 둔다 — 파고든 자리까지 지켜야 한다.
    public func load(_ root: URL) async {
        // 화면이 무엇을 보고 있는지도 모델이 안다. 뷰와 두 곳에 두면 어긋난다.
        selectedRoot = root
        let previous = cache?.load(root)
        // 다른 시작점으로 옮겼으면 보던 트리를 내린다. 읽는 동안에도 목록이 보이므로
        // 남겨 두면 새로 고른 곳 이름 아래 엉뚱한 폴더가 보인다.
        if path.first?.url != root {
            path = previous.map { [$0.tree] } ?? []
            cachedAt = previous?.date
        }

        let total = previous?.tree.size ?? expectedBytes(root)
        loadPhase = Self.phase(read: 0, of: total)

        // 볼륨 전체는 몇 분이 걸린다. 시작한 순회를 멈출 수 있어야 한다.
        // 도는 순회가 있으면 먼저 멈춘다 — 허락이 바뀌면 화면이 읽는 중에도 다시 부른다.
        // 플래그를 덮어쓰기만 하면 앞 순회는 멈출 길이 없고, 먼저 끝나 진행 표시를 내린다.
        cancelFlag?.cancel()
        let flag = CancelFlag()
        cancelFlag = flag
        movesDuringLoad = []

        let measured = ScanCounter()
        let building = Task.detached { [buildTree] in
            buildTree(root, flag) { measured.add($0) }
        }

        let ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(80))
                // 중단했는데 티커가 진행률을 되살리면 "중단" 버튼이 안 먹은 것처럼 보인다.
                // 다 읽은 뒤 깨어난 경우도 같다 — 끝난 화면에 "읽는 중"을 되살린다.
                guard !Task.isCancelled, let self, !flag.isCancelled else { return }
                self.loadPhase = Self.phase(read: Int64(measured.value), of: total)
            }
        }
        var tree = await building.value
        ticker.cancel()

        // 중단됐으면 반쪽 트리로 화면을 덮지 않는다.
        // 보던 것(지난 결과 포함)은 그대로 둔다 — 멈췄다고 화면까지 비면 처음부터 다시 해야 한다.
        // 진행 표시·모아 둔 옮김은 건드리지 않는다. 사용자가 멈췄으면 `cancelLoad`가 이미 치웠고,
        // 새 순회가 이어받았으면 그쪽 것이다.
        guard isCurrent(flag) else { return }

        // 읽는 동안 다른 화면에서 옮긴 것. 그 폴더를 옮기기 전에 읽었으면 지운 것이 되살아난다.
        let pending = movesDuringLoad
        movesDuringLoad = []
        if !pending.isEmpty {
            let built = tree
            tree = await Task.detached { [rebuild, maxDepth] in
                Self.reconcile(built, with: pending, maxDepth: maxDepth, rebuild: rebuild)
            }.value
            guard isCurrent(flag) else { return }
        }

        // 집계가 끝났으면 정의상 100%다. 한 틱만 보여주고 넘어간다 — 사용자가 완료를 확인할 수 있어야 한다.
        if total != nil {
            loadPhase = .measuring(percent: 100)
            try? await Task.sleep(for: .milliseconds(120))
            guard isCurrent(flag) else { return }
        }

        // 보던 자리를 **URL로 다시 찾아 내려간다.** 세 단계 파고든 뒤 새로 읽었다고
        // 맨 위로 튕기면 세 번 다시 눌러야 한다. 중간이 사라졌으면 거기서 멈춘다.
        path = path.first?.url == root ? retrace(in: tree, skippingEmpty: true) : [tree]
        cachedAt = nil
        loadPhase = nil
        completedAt = Date()
        cache?.save(tree, for: root)
        onCompleted?()
    }

    /// 이 순회가 아직 화면의 몫인가. 중단됐거나 더 새 `load`가 시작됐으면 결과를 버린다.
    private func isCurrent(_ flag: CancelFlag) -> Bool {
        !flag.isCancelled && cancelFlag === flag
    }

    /// 읽은 양과 분모로 단계를 정한다. 분모가 추정이라 다 읽기 전에는 99%에서 멈춘다.
    static func phase(read: Int64, of total: Int64?) -> LoadPhase {
        guard let total, total > 0 else { return .reading(bytes: read) }
        let percent = Int((Double(read) / Double(total) * 100).rounded())
        return .measuring(percent: min(99, max(0, percent)))
    }

    /// 이 항목의 판정. 지금 보고 있는 지점의 자식이 아니면 nil —
    /// 화면이 그리지 않으므로 쓰이지 않는다.
    public func verdict(for node: DiskUsageNode) -> RemovalVerdict? {
        tileVerdicts[node.url]
    }

    /// 막는 사유만 필요할 때. 판정이 없으면 nil(= 막지 않음).
    public func veto(for node: DiskUsageNode) -> RemovalVeto? {
        tileVerdicts[node.url]?.veto
    }

    private func refreshVerdicts() {
        var map: [URL: RemovalVerdict] = [:]
        for child in path.last?.children ?? [] {
            map[child.url] = RemovalVerdict.forDiskMap(child.url)
        }
        tileVerdicts = map
    }

    /// 도는 순회를 멈춘다.
    ///
    /// **이미 그리고 있던 트리는 건드리지 않는다.** 멈췄다고 보던 것까지
    /// 사라지면 사용자가 처음부터 다시 해야 한다.
    public func cancelLoad() {
        cancelFlag?.cancel()
        cancelFlag = nil
        movesDuringLoad = []
        loadPhase = nil
    }

    /// 타일을 눌러 한 단계 내려간다. 자식이 없으면 아무 일도 하지 않는다 —
    /// 빈 화면으로 들어가면 사용자가 길을 잃는다.
    public func drillDown(into node: DiskUsageNode) {
        guard !node.children.isEmpty else { return }
        path.append(node)
    }

    public func goUp() {
        guard canGoUp else { return }
        path.removeLast()
    }

    /// breadcrumb의 N번째를 눌렀을 때 그 지점까지만 남긴다.
    public func jump(to index: Int) {
        guard path.indices.contains(index) else { return }
        path = Array(path.prefix(index + 1))
    }

    /// 지금 보고 있는 트리를 디스크에서 다시 읽는다.
    ///
    /// 삭제는 메모리 트리에서 바로 빼지만, 앱 밖에서 생긴 변화는 다시 읽어야 보인다.
    ///
    /// 다시 읽으면 `path`가 루트 하나로 초기화된다. **같은 경로를 URL로 다시 찾아
    /// 내려간다** — 세 단계 파고든 뒤 새로고침했다고 맨 위로 튕기면 세 번 다시 눌러야 한다.
    /// 중간이 사라졌으면 거기서 멈춘다. 없는 자리를 지어내지 않는다.
    public func reload() async {
        // 중단하면 트리가 없다. 그래도 고른 시작점이 있으면 다시 훑을 수 있어야 한다 —
        // 없으면 중단한 순간 되돌아갈 길이 막힌다.
        guard let root = path.first?.url ?? selectedRoot else { return }
        await load(root)
    }

    // MARK: - 삭제

    /// 직전 삭제가 실패한 사유. 성공했으면 nil.
    public private(set) var removalFailure: String?

    public func clearRemovalFailure() { removalFailure = nil }

    /// 지금 보고 있는 지점의 자식 하나를 휴지통으로 보낸다.
    ///
    /// 관문은 `Remover`가 지킨다 — 디스크 맵이라고 다른 길로 가지 않는다. 다만 **범위**는
    /// 디스크 맵 것이다. 화면이 "지워도 됨"이라 쓴 것과 같은 판정으로 지운다.
    /// 허용 루트 자체는 `allowedRootItself`로 거부되므로 최상위는 지워지지 않는다.
    ///
    /// **성공했을 때만 트리에서 뺀다.** 실패했는데 화면에서 사라지면
    /// 사용자는 지워진 줄 안다.
    public func remove(_ node: DiskUsageNode,
                       using remover: Remover = Remover(scope: .diskMap)) async {
        let url = node.url
        let (trashed, failure) = await Task.detached { remover.trash(at: url) }.value

        removalFailure = failure?.reason
        guard failure == nil else { return }
        let move = TrashMove(from: url, to: trashed, size: node.size)
        apply([move])
        // 스캔 탭이 들고 있는 같은 파일·그 아래 파일을 빼고, 휴지통 탭에 넣게 한다.
        onMoved?([move])
    }

    /// 여기서 휴지통으로 옮겼을 때 한 번. 앱이 다른 화면에 알린다.
    public var onMoved: (@MainActor ([TrashMove]) -> Void)?

    /// 지운 노드를 트리에서 뺀다. 지금 보고 있는 지점의 자식만 받는다.
    func drop(_ node: DiskUsageNode) {
        guard let leaf = path.last, leaf.children.contains(where: { $0.id == node.id }) else { return }
        apply([TrashMove(from: node.url, to: nil, size: node.size)])
    }

    /// 옮긴 것을 트리에 반영한다. 다시 훑으면 몇 분이 걸린다.
    ///
    /// 트리 어디에 있든 빼고 조상 크기를 줄인다 — 다른 탭에서 지운 것은 지금 보고 있는
    /// 지점과 상관없는 곳에 있다. 휴지통으로 갔으면 휴지통 폴더(가 목록에 없으면 가장 깊은
    /// 조상) 크기에 더한다. 같은 디스크 안에서 옮긴 것이라 합계는 그대로여야 맞다.
    ///
    /// 크기는 트리가 아는 값을 먼저 쓴다. 스캐너가 잰 값과 조금 달라도 막대 합이 어긋나지 않는다.
    public func apply(_ moves: [TrashMove]) {
        guard !moves.isEmpty else { return }
        // 읽는 중이면 다 읽은 트리에도 맞춰 봐야 한다. 지금 보이는 것은 지난 트리다.
        if isScanning { movesDuringLoad += moves }
        guard var root = path.first else { return }
        for move in moves {
            let size = root.node(at: move.from)?.size ?? move.size
            root = root.adjusting(move.from, by: -size, removing: true) ?? root
            if let to = move.to {
                root = root.adjusting(to.deletingLastPathComponent(), by: size, removing: false) ?? root
            }
        }
        // 조상을 바꿔 끼우지 않으면 breadcrumb으로 올라갔을 때 지운 노드가 되살아난다.
        path = retrace(in: root, skippingEmpty: false)
        // 지운 것이 다음에 지난 결과로 되살아나면 안 된다.
        cache?.save(root, for: root.url, at: cachedAt ?? completedAt ?? Date())
    }

    /// 다 읽은 트리에 읽는 동안 옮긴 것을 맞춰 본다.
    ///
    /// 순회가 그 폴더를 옮기기 전에 읽었는지 뒤에 읽었는지는 알 수 없다. 그냥 다시 빼면
    /// 뒤에 읽은 경우 두 번 빠진다. 그래서 결과 트리를 보고 정한다.
    /// - 보낸 쪽: 노드가 남아 있으면 전에 읽은 것이라 뺀다. 없는데 품은 노드가 최대 깊이라
    ///   자식 목록이 없으면 알 수 없으니 그 자리만 다시 잰다. 그 밖은 이미 빠졌거나 1MB 미만이다.
    /// - 받는 쪽: 휴지통 폴더(목록에 없으면 최대 깊이 조상, 또는 부모 아래 새로)를 다시 잰다.
    ///   전에 읽었는지 뒤에 읽었는지와 상관없이 맞는 값이 된다. 휴지통은 보통 작다.
    nonisolated static func reconcile(_ built: DiskUsageNode, with moves: [TrashMove], maxDepth: Int,
                                      rebuild: (URL, Int) -> DiskUsageNode) -> DiskUsageNode {
        var tree = built
        var targets: [URL] = []
        for move in moves {
            if move.from.pathKey != tree.url.pathKey, let stale = tree.node(at: move.from) {
                tree = tree.adjusting(move.from, by: -stale.size, removing: true) ?? tree
            } else if let holder = tree.deepestNode(containing: move.from), holder.depth >= maxDepth {
                targets.append(holder.node.url)
            }

            guard let to = move.to else { continue }
            let folder = to.deletingLastPathComponent()
            guard let holder = tree.deepestNode(containing: folder) else { continue }
            if holder.node.url.pathKey == folder.pathKey || holder.depth >= maxDepth {
                targets.append(holder.node.url)
            } else if holder.node.url.pathKey == folder.deletingLastPathComponent().pathKey {
                targets.append(folder)
            }
        }

        // 겹치면 바깥 하나만 잰다. 안쪽은 바깥을 잴 때 같이 잰다.
        var kept: [URL] = []
        for target in targets.sorted(by: { $0.pathKey.count < $1.pathKey.count })
        where !kept.contains(where: { target.isSameOrInside($0) }) {
            kept.append(target)
        }
        for target in kept {
            guard let holder = tree.deepestNode(containing: target) else { continue }
            let depth = holder.node.url.pathKey == target.pathKey ? holder.depth : holder.depth + 1
            tree = tree.replacing(rebuild(target, max(0, maxDepth - depth))) ?? tree
        }
        return tree
    }

    /// 보던 자리를 **URL로 다시 찾아 내려간다.** 중간이 사라졌으면 거기서 멈춘다.
    ///
    /// 새로 읽었을 때는 빈 폴더에 들어가 있지 않는다(`skippingEmpty`) — 빈 화면에서 길을 잃는다.
    /// 지워서 비었을 때는 그 자리에 둔다. 방금 지운 곳에서 튕겨 나가면 무엇이 지워졌는지 못 본다.
    private func retrace(in tree: DiskUsageNode, skippingEmpty: Bool) -> [DiskUsageNode] {
        var rebuilt = [tree]
        for url in path.dropFirst().map(\.url) {
            guard let next = rebuilt.last?.children.first(where: { $0.url == url }),
                  !(skippingEmpty && next.children.isEmpty)
            else { break }
            rebuilt.append(next)
        }
        return rebuilt
    }

    /// 테스트에서 스캔 없이 트리를 넣기 위한 입구.
    public func seed(_ node: DiskUsageNode) { path = [node] }
}
