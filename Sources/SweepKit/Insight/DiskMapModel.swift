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

    public var value: Int {
        lock.lock(); defer { lock.unlock() }
        return count
    }

    /// 절대값으로 덮어쓴다. 세기 패스는 자기 누적치를 그대로 보고한다.
    public func set(_ newValue: Int) {
        lock.lock(); defer { lock.unlock() }
        count = newValue
    }

    /// 0~100.
    ///
    /// **절삭이 아니라 반올림한다.** 두 패스가 서로 다른 시점에 돌아 분모와 분자가
    /// 완전히 같을 수 없다 — 실측에서 73,952 vs 73,947로 5개가 어긋났고,
    /// 절삭하면 99.99%가 99%가 되어 "멈춘 것처럼" 보인다.
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

    /// 로딩 단계. 분모가 생기기 전에는 퍼센트를 보여줄 수 없다.
    public enum LoadPhase: Equatable, Sendable {
        /// 항목 수를 세는 중. 총량을 모르므로 퍼센트 대신 지금까지 센 개수를 보여준다.
        /// 없는 분모로 퍼센트를 지어내지 않는다.
        case counting(scanned: Int)
        /// 크기를 재는 중. 0~100.
        case measuring(percent: Int)
    }

    /// 지금 보고 있는 지점까지의 경로. 첫 원소가 루트다.
    public private(set) var path: [DiskUsageNode] = []
    public private(set) var loadPhase: LoadPhase?

    /// Picker가 고른 시작 지점.
    ///
    /// 뷰가 들고 있으면 탭을 옮겼다 오는 순간 nil로 돌아가, 트리는 그대로인데
    /// 머리말만 "선택하세요"가 된다.
    public var selectedRoot: URL?

    public var isScanning: Bool { loadPhase != nil }

    private let countEntries: @Sendable (URL, @escaping @Sendable (Int) -> Void) -> Int
    private let buildTree: @Sendable (URL, @escaping @Sendable () -> Void) -> DiskUsageNode

    /// 세기·집계를 주입할 수 있게 열어 둔다 — 실제 스캔은 10초가 넘어 테스트에 쓸 수 없다.
    public init(
        countEntries: @escaping @Sendable (URL, @escaping @Sendable (Int) -> Void) -> Int
            = { DiskUsageTree.countEntries(at: $0, onCounted: $1) },
        buildTree: @escaping @Sendable (URL, @escaping @Sendable () -> Void) -> DiskUsageNode
            = { DiskUsageTree.build(at: $0, onEntryScanned: $1) }
    ) {
        self.countEntries = countEntries
        self.buildTree = buildTree
    }

    /// 사용자가 고를 수 있는 시작점. 정리 대상과 같은 범위만 보여준다.
    public var availableRoots: [URL] { ProtectedPaths.allowedRoots }

    public var current: DiskUsageNode? { path.last }
    public var tiles: [DiskUsageNode] { current?.children ?? [] }
    public var canGoUp: Bool { path.count > 1 }

    /// 세기와 집계를 **동시에** 돌린다.
    ///
    /// 순차로 하면 5.9 + 9.2 = 15.1초인데, 동시에 돌리면 벽시계 시간이
    /// 집계 패스 수준으로 줄어든다. 분모가 도착하기 전까지는 퍼센트 대신
    /// "세는 중"을 보여주는 것이 정직하다.
    public func load(_ root: URL) async {
        // 화면이 무엇을 보고 있는지도 모델이 안다. 뷰와 두 곳에 두면 어긋난다.
        selectedRoot = root
        loadPhase = .counting(scanned: 0)

        let measured = ScanCounter()
        let counted = ScanCounter()
        let counting = Task.detached { [countEntries] in
            countEntries(root) { counted.set($0) }
        }
        let building = Task.detached { [buildTree] in
            buildTree(root) { measured.increment() }
        }

        // 분모가 오기 전에는 센 개수를, 온 뒤에는 퍼센트를 보여준다.
        let ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(80))
                guard let self, case .counting = self.loadPhase else { return }
                self.loadPhase = .counting(scanned: counted.value)
            }
        }

        // countEntries는 루트 하위만 세고, build는 루트 자신도 방문한다.
        // 분모에 1을 더해야 둘이 같은 것을 세게 된다.
        let total = await counting.value + 1
        ticker.cancel()
        loadPhase = .measuring(percent: measured.percent(of: total))

        // 집계가 끝날 때까지 주기적으로 퍼센트를 갱신한다.
        let percentTicker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(80))
                guard let self else { return }
                self.loadPhase = .measuring(percent: measured.percent(of: total))
            }
        }
        let tree = await building.value
        percentTicker.cancel()

        // 집계가 끝났으면 정의상 100%다. 분모 오차로 99%에서 끝나지 않도록 확정한다.
        // 한 틱만 보여주고 넘어간다 — 사용자가 완료를 확인할 수 있어야 한다.
        loadPhase = .measuring(percent: 100)
        try? await Task.sleep(for: .milliseconds(120))

        path = [tree]
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
        guard let root = path.first?.url else { return }
        let trail = path.dropFirst().map(\.url)

        await load(root)

        for url in trail {
            guard let next = current?.children.first(where: { $0.url == url }),
                  !next.children.isEmpty
            else { break }
            path.append(next)
        }
    }

    // MARK: - 삭제

    /// 직전 삭제가 실패한 사유. 성공했으면 nil.
    public private(set) var removalFailure: String?

    public func clearRemovalFailure() { removalFailure = nil }

    /// 지금 보고 있는 지점의 자식 하나를 휴지통으로 보낸다.
    ///
    /// 관문은 `Remover`가 지킨다 — 디스크 맵이라고 다른 길로 가지 않는다.
    /// 허용 루트 자체는 `allowedRootItself`로 거부되므로 최상위는 지워지지 않는다.
    ///
    /// **성공했을 때만 트리에서 뺀다.** 실패했는데 화면에서 사라지면
    /// 사용자는 지워진 줄 안다.
    public func remove(_ node: DiskUsageNode, using remover: Remover = Remover()) async {
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
            children: rebuilt[leaf].children.filter { $0.id != node.id })

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
                })
            index = parent
        }
        path = rebuilt
    }

    /// 테스트에서 스캔 없이 트리를 넣기 위한 입구.
    public func seed(_ node: DiskUsageNode) { path = [node] }
}
