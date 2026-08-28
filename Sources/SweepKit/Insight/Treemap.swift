import Foundation
import CoreGraphics

/// 트리맵에서 노드 하나가 차지하는 자리.
public struct TreemapTile: Sendable, Hashable {
    public let node: DiskUsageNode
    public let rect: CGRect

    public init(node: DiskUsageNode, rect: CGRect) {
        self.node = node
        self.rect = rect
    }
}

/// 사각형을 크기에 비례해 나눠 담는 squarified 트리맵.
public enum Treemap {

    /// 노드들을 `bounds` 안에 크기 비례로 배치한다.
    ///
    /// 단순 slice-and-dice(한 방향으로만 자르기)를 쓰지 않는 이유는
    /// 가늘고 긴 띠가 생겨 면적으로 크기를 비교할 수 없기 때문이다.
    /// squarified는 행을 채우다 종횡비가 나빠지는 순간 행을 끊어 정사각형에 가깝게 만든다.
    public static func layout(_ nodes: [DiskUsageNode], in bounds: CGRect) -> [TreemapTile] {
        let candidates = nodes.filter { $0.size > 0 }.sorted { $0.size > $1.size }
        guard !candidates.isEmpty, bounds.width > 0, bounds.height > 0 else { return [] }

        let total = candidates.reduce(0.0) { $0 + Double($1.size) }
        let scale = Double(bounds.width) * Double(bounds.height) / total

        var tiles: [TreemapTile] = []
        var remaining = candidates[...]
        var area = bounds

        while let first = remaining.first {
            // 짧은 변을 따라 행을 쌓는다. 그래야 종횡비가 덜 벌어진다.
            let side = Double(min(area.width, area.height))
            var row: [DiskUsageNode] = [first]
            var rowAreas: [Double] = [Double(first.size) * scale]
            var rest = remaining.dropFirst()

            while let next = rest.first {
                let nextArea = Double(next.size) * scale
                // 하나 더 넣어 종횡비가 나빠지면 거기서 행을 끊는다.
                guard worstAspectRatio(rowAreas + [nextArea], side: side)
                        <= worstAspectRatio(rowAreas, side: side) else { break }
                row.append(next)
                rowAreas.append(nextArea)
                rest = rest.dropFirst()
            }

            area = place(row, areas: rowAreas, in: area, into: &tiles)
            remaining = rest
        }
        return tiles
    }

    /// 이 면적들로 행을 만들었을 때 가장 나쁜(1에서 먼) 종횡비.
    static func worstAspectRatio(_ areas: [Double], side: Double) -> Double {
        guard let maxArea = areas.max(), let minArea = areas.min(),
              side > 0, minArea > 0 else { return .infinity }
        let sum = areas.reduce(0, +)
        guard sum > 0 else { return .infinity }

        let sumSquared = sum * sum
        let sideSquared = side * side
        return max(sideSquared * maxArea / sumSquared, sumSquared / (sideSquared * minArea))
    }

    /// 행 하나를 배치하고 남은 사각형을 돌려준다.
    private static func place(_ row: [DiskUsageNode],
                              areas: [Double],
                              in area: CGRect,
                              into tiles: inout [TreemapTile]) -> CGRect {
        let sum = areas.reduce(0, +)
        guard sum > 0 else { return .zero }

        // 짧은 변을 따라 쌓으므로, 가로가 짧으면 행은 가로로 눕는다.
        let alongWidth = area.width <= area.height
        let thickness = CGFloat(sum / Double(alongWidth ? area.width : area.height))

        var offset: CGFloat = 0
        for (node, nodeArea) in zip(row, areas) {
            let length = CGFloat(nodeArea) / thickness
            let rect = alongWidth
                ? CGRect(x: area.minX + offset, y: area.minY, width: length, height: thickness)
                : CGRect(x: area.minX, y: area.minY + offset, width: thickness, height: length)
            tiles.append(TreemapTile(node: node, rect: rect))
            offset += length
        }

        return alongWidth
            ? CGRect(x: area.minX, y: area.minY + thickness,
                     width: area.width, height: area.height - thickness)
            : CGRect(x: area.minX + thickness, y: area.minY,
                     width: area.width - thickness, height: area.height)
    }
}
