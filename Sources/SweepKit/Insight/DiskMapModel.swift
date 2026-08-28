import Foundation
import Observation

/// 디스크 맵 화면의 상태. 드릴다운 경로를 스택으로 들고 있는다.
///
/// SwiftUI를 import하지 않는다. 뷰 없이 드릴다운·복귀 로직을 테스트할 수 있어야 한다.
@MainActor
@Observable
public final class DiskMapModel {

    /// 지금 보고 있는 지점까지의 경로. 첫 원소가 루트다.
    public private(set) var path: [DiskUsageNode] = []
    public private(set) var isScanning = false

    private let buildTree: @Sendable (URL) -> DiskUsageNode

    /// 트리 생성을 주입할 수 있게 열어 둔다 — 실제 스캔은 느려서 테스트에 쓸 수 없다.
    public init(buildTree: @escaping @Sendable (URL) -> DiskUsageNode
                    = { DiskUsageTree.build(at: $0) }) {
        self.buildTree = buildTree
    }

    /// 사용자가 고를 수 있는 시작점. 정리 대상과 같은 범위만 보여준다.
    public var availableRoots: [URL] { ProtectedPaths.allowedRoots }

    public var current: DiskUsageNode? { path.last }
    public var tiles: [DiskUsageNode] { current?.children ?? [] }
    public var canGoUp: Bool { path.count > 1 }

    public func load(_ root: URL) async {
        isScanning = true
        let build = buildTree
        let tree = await Task.detached { build(root) }.value
        path = [tree]
        isScanning = false
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
