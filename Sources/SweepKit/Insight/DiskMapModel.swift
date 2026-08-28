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

    /// 0~100. 분모 오차가 있어도 100을 넘지 않는다 —
    /// 실측에서 세기와 집계가 0.32% 어긋났다(스캔 도중 사라지는 임시 파일).
    public func percent(of total: Int) -> Int {
        guard total > 0 else { return 0 }
        return min(100, max(0, value * 100 / total))
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

        let total = await counting.value
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

    /// 테스트에서 스캔 없이 트리를 넣기 위한 입구.
    public func seed(_ node: DiskUsageNode) { path = [node] }
}
