import Testing
import Foundation
import CoreGraphics
@testable import SweepKit

@Suite("DiskUsageTree")
struct DiskUsageTreeTests {

    private var fm: FileManager { .default }
    private static let oneMB = 1024 * 1024

    private func makeSandbox() throws -> URL {
        let dir = URL(filePath: NSTemporaryDirectory())
            .appending(path: "sweep-tree-\(UUID().uuidString)")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func write(_ megabytes: Int, to url: URL) throws {
        try fm.createDirectory(at: url.deletingLastPathComponent(),
                               withIntermediateDirectories: true)
        try Data(repeating: 0x41, count: megabytes * Self.oneMB).write(to: url)
    }

    // TC-1
    @Test("루트 크기가 하위 전체 합계와 일치한다")
    func rootSizeMatchesTotal() throws {
        let root = try makeSandbox()
        defer { try? fm.removeItem(at: root) }
        try write(3, to: root.appending(path: "a/big.bin"))
        try write(2, to: root.appending(path: "b/mid.bin"))

        let tree = DiskUsageTree.build(at: root, minimumSize: Int64(Self.oneMB))

        #expect(tree.size >= Int64(5 * Self.oneMB))
        #expect(tree.size < Int64(6 * Self.oneMB))
        #expect(tree.children.map(\.name).sorted() == ["a", "b"])
        // 자식 합계가 루트를 넘지 않는다
        #expect(tree.children.reduce(0) { $0 + $1.size } <= tree.size)
    }

    // TC-2
    @Test("maxDepth로 깊이가 제한된다")
    func maxDepthLimitsRecursion() throws {
        let root = try makeSandbox()
        defer { try? fm.removeItem(at: root) }
        try write(3, to: root.appending(path: "a/b/deep.bin"))

        let tree = DiskUsageTree.build(at: root, maxDepth: 1, minimumSize: Int64(Self.oneMB))

        #expect(tree.children.count == 1)
        #expect(tree.children.first?.name == "a")
        #expect(tree.children.first?.children.isEmpty == true, "maxDepth를 넘어 내려갔다")
    }

    // TC-3
    @Test("작은 자식은 목록에서 빠지지만 부모 크기에는 남는다")
    func smallChildrenArePrunedButCounted() throws {
        let root = try makeSandbox()
        defer { try? fm.removeItem(at: root) }
        try write(5, to: root.appending(path: "big/large.bin"))
        try write(1, to: root.appending(path: "tiny/small.bin"))

        let tree = DiskUsageTree.build(at: root, minimumSize: Int64(3 * Self.oneMB))

        #expect(tree.children.map(\.name) == ["big"])
        // 잘려나간 tiny도 합계에는 포함되어야 면적 비교가 성립한다
        #expect(tree.size >= Int64(6 * Self.oneMB))
    }

    // TC-4
    @Test("존재하지 않는 경로는 크기 0 노드가 된다")
    func missingPathYieldsEmptyNode() {
        let ghost = URL(filePath: "/private/tmp/sweep-tree-ghost-\(UUID().uuidString)")
        let tree = DiskUsageTree.build(at: ghost)

        #expect(tree.size == 0)
        #expect(tree.children.isEmpty)
    }

    // TC-5
    @Test("노드가 이름과 사람이 읽는 크기를 제공한다")
    func nodeExposesDisplayInfo() {
        let node = DiskUsageNode(url: URL(filePath: "/private/tmp/things"),
                                 size: 5_000_000_000)
        #expect(node.name == "things")
        #expect(node.formattedSize.contains("GB"))
        #expect(!node.formattedSize.contains("5000000000"))
    }
}

@Suite("Treemap")
struct TreemapTests {

    private func node(_ name: String, _ size: Int64) -> DiskUsageNode {
        DiskUsageNode(url: URL(filePath: "/private/tmp/\(name)"), size: size)
    }

    private let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)

    // TC-6
    @Test("타일 면적 합이 전체 사각형 면적과 일치한다")
    func tileAreasFillBounds() {
        let tiles = Treemap.layout([node("a", 500), node("b", 300), node("c", 200)],
                                   in: bounds)
        let covered = tiles.reduce(0.0) { $0 + Double($1.rect.width * $1.rect.height) }
        let expected = Double(bounds.width * bounds.height)

        #expect(tiles.count == 3)
        #expect(abs(covered - expected) / expected < 0.01, "면적 오차 \(covered) vs \(expected)")
    }

    // TC-7
    @Test("타일끼리 겹치지 않는다")
    func tilesDoNotOverlap() {
        let tiles = Treemap.layout(
            [node("a", 600), node("b", 250), node("c", 100), node("d", 50)], in: bounds)

        for i in tiles.indices {
            for j in tiles.indices where j > i {
                let overlap = tiles[i].rect.intersection(tiles[j].rect)
                let area = overlap.isNull ? 0 : Double(overlap.width * overlap.height)
                #expect(area < 0.01,
                        "\(tiles[i].node.name)와 \(tiles[j].node.name)가 겹친다: \(area)")
            }
        }
    }

    // TC-8
    @Test("빈 입력은 빈 결과를 준다")
    func emptyInputYieldsNoTiles() {
        #expect(Treemap.layout([], in: bounds).isEmpty)
        #expect(Treemap.layout([node("a", 100)], in: .zero).isEmpty)
        #expect(Treemap.layout([node("zero", 0)], in: bounds).isEmpty)
    }

    // TC-9
    @Test("노드가 하나면 전체를 차지한다")
    func singleNodeFillsBounds() {
        let tiles = Treemap.layout([node("only", 100)], in: bounds)

        #expect(tiles.count == 1)
        let rect = tiles[0].rect
        #expect(abs(rect.width - bounds.width) < 0.01)
        #expect(abs(rect.height - bounds.height) < 0.01)
    }

    // TC-10
    @Test("크기가 큰 노드가 더 넓은 면적을 받는다")
    func areaIsProportionalToSize() {
        let tiles = Treemap.layout([node("big", 800), node("small", 200)], in: bounds)
        let byName = Dictionary(uniqueKeysWithValues:
            tiles.map { ($0.node.name, Double($0.rect.width * $0.rect.height)) })

        let big = try! #require(byName["big"])
        let small = try! #require(byName["small"])
        #expect(big > small)
        // 4:1 비율이 대략 유지되어야 한다
        #expect(abs(big / small - 4.0) < 0.2)
    }

    // TC-11
    @Test("극단적으로 가늘고 긴 타일이 생기지 않는다")
    func aspectRatiosStayReasonable() {
        let sizes: [Int64] = [600, 300, 250, 200, 150, 120, 100, 80, 60, 40]
        let tiles = Treemap.layout(
            sizes.enumerated().map { node("n\($0.offset)", $0.element) }, in: bounds)

        for tile in tiles {
            let w = Double(tile.rect.width), h = Double(tile.rect.height)
            guard w > 0, h > 0 else { Issue.record("면적 0 타일: \(tile.node.name)"); continue }
            let ratio = max(w / h, h / w)
            #expect(ratio < 20, "\(tile.node.name) 종횡비 \(ratio)")
        }
    }
}
