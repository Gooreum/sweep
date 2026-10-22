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
        cache: DiskMapCache? = nil
    ) {
        self.buildTree = buildTree
        self.expectedBytes = expectedBytes
        self.cache = cache
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
        let flag = CancelFlag()
        cancelFlag = flag

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
        let tree = await building.value
        ticker.cancel()

        // 중단됐으면 반쪽 트리로 화면을 덮지 않는다.
        // 보던 것(지난 결과 포함)은 그대로 둔다 — 멈췄다고 화면까지 비면 처음부터 다시 해야 한다.
        guard !flag.isCancelled else {
            loadPhase = nil
            return
        }

        // 집계가 끝났으면 정의상 100%다. 한 틱만 보여주고 넘어간다 — 사용자가 완료를 확인할 수 있어야 한다.
        if total != nil {
            loadPhase = .measuring(percent: 100)
            try? await Task.sleep(for: .milliseconds(120))
        }

        // 보던 자리를 **URL로 다시 찾아 내려간다.** 세 단계 파고든 뒤 새로 읽었다고
        // 맨 위로 튕기면 세 번 다시 눌러야 한다. 중간이 사라졌으면 거기서 멈춘다.
        let trail = path.first?.url == root ? path.dropFirst().map(\.url) : []
        var rebuilt = [tree]
        for url in trail {
            guard let next = rebuilt.last?.children.first(where: { $0.url == url }),
                  !next.children.isEmpty
            else { break }
            rebuilt.append(next)
        }
        path = rebuilt
        cachedAt = nil
        loadPhase = nil
        completedAt = Date()
        cache?.save(tree, for: root)
        onCompleted?()
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
        let failure = await Task.detached { remover.removeFile(at: url) }.value

        removalFailure = failure
        if failure == nil { drop(node) }
    }

    /// 지운 노드를 트리에서 뺀다.
    ///
    /// 다시 훑으면 10초가 걸린다. 조상의 크기도 함께 줄여야
    /// 상위 합계와 막대 비율이 어긋나지 않는다.
    func drop(_ node: DiskUsageNode) {
        guard let leaf = path.indices.last,
              path[leaf].children.contains(where: { $0.id == node.id })
        else { return }

        var rebuilt = path
        rebuilt[leaf] = DiskUsageNode(
            url: rebuilt[leaf].url,
            size: max(0, rebuilt[leaf].size - node.size),
            children: rebuilt[leaf].children.filter { $0.id != node.id },
            // 안 넘기면 기본값 true로 되살아나 "읽을 수 없음"이 사라진다
            isReadable: rebuilt[leaf].isReadable)

        // 조상으로 올라가며 크기를 줄이고, 바뀐 자식으로 교체한다.
        // 교체하지 않으면 breadcrumb으로 위에 올라갔을 때 지운 노드가 되살아난다.
        var index = leaf
        while index > 0 {
            let parent = index - 1
            let updated = rebuilt[index]
            rebuilt[parent] = DiskUsageNode(
                url: rebuilt[parent].url,
                size: max(0, rebuilt[parent].size - node.size),
                children: rebuilt[parent].children.map {
                    $0.id == updated.id ? updated : $0
                },
                isReadable: rebuilt[parent].isReadable)
            index = parent
        }
        path = rebuilt
        // 지운 것이 다음에 지난 결과로 되살아나면 안 된다.
        if let root = path.first { cache?.save(root, for: root.url, at: cachedAt ?? completedAt ?? Date()) }
    }

    /// 테스트에서 스캔 없이 트리를 넣기 위한 입구.
    public func seed(_ node: DiskUsageNode) { path = [node] }
}
