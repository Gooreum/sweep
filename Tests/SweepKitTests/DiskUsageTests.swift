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

    // MARK: - 단일 순회 재작성 (Phase 1)

    // TC-4
    @Test("깊이 제한을 넘는 파일도 부모 크기에 반영된다")
    func deepFilesStillCountTowardParentSize() throws {
        let root = try makeSandbox()
        defer { try? fm.removeItem(at: root) }
        try write(4, to: root.appending(path: "a/b/c/deep.bin"))

        let tree = DiskUsageTree.build(at: root, maxDepth: 1,
                                       minimumSize: Int64(Self.oneMB))

        // children은 한 겹만 있지만 크기는 3단계 아래 파일까지 합산돼야 한다
        #expect(tree.children.count == 1)
        #expect(tree.children.first?.children.isEmpty == true)
        #expect(tree.size >= Int64(4 * Self.oneMB))
    }

    // TC-5
    @Test("항목을 정확히 한 번씩만 본다")
    func everyEntryIsVisitedOnce() throws {
        let root = try makeSandbox()
        defer { try? fm.removeItem(at: root) }
        // 디렉토리 3개 + 파일 3개 = 6개 (루트 자신 포함하면 7개)
        try write(2, to: root.appending(path: "a/x.bin"))
        try write(2, to: root.appending(path: "b/y.bin"))
        try write(2, to: root.appending(path: "c/z.bin"))

        let counter = VisitCounter()
        _ = DiskUsageTree.build(at: root, maxDepth: 4,
                                minimumSize: Int64(Self.oneMB)) { counter.increment() }

        // 루트 1 + 디렉토리 3 + 파일 3
        #expect(counter.value == 7, "방문 횟수가 항목 수와 다르다: \(counter.value)")
    }

    // TC-6
    @Test("심볼릭 링크 대상 용량이 합계에 섞이지 않는다")
    func symlinkTargetsAreNotCounted() throws {
        let root = try makeSandbox()
        let outside = try makeSandbox()
        defer {
            try? fm.removeItem(at: root)
            try? fm.removeItem(at: outside)
        }
        try write(2, to: root.appending(path: "real.bin"))
        let fat = outside.appending(path: "fat.bin")
        try write(8, to: fat)
        try fm.createSymbolicLink(at: root.appending(path: "link.bin"), withDestinationURL: fat)

        let tree = DiskUsageTree.build(at: root, minimumSize: 1)

        #expect(tree.size >= Int64(2 * Self.oneMB))
        #expect(tree.size < Int64(3 * Self.oneMB), "링크를 따라가 8MB가 섞였다")
    }
}

/// 방문 횟수를 세는 잠금 카운터. 재귀가 여러 스레드를 쓰지는 않지만
/// 콜백이 `@Sendable`이라 참조 타입이 필요하다.
private final class VisitCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func increment() {
        lock.lock(); defer { lock.unlock() }
        count += 1
    }

    var value: Int {
        lock.lock(); defer { lock.unlock() }
        return count
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

    // MARK: - 중첩 렌더링 지원 (Phase 4)

    // TC-1
    @Test("인접 인덱스의 색상이 충분히 벌어진다")
    func adjacentHuesAreDistinct() {
        let hues = (0..<12).map(Treemap.hue(for:))

        for i in 0..<(hues.count - 1) {
            // 색상환은 순환하므로 양방향 거리 중 가까운 쪽을 본다
            let raw = abs(hues[i] - hues[i + 1])
            let distance = min(raw, 1 - raw)
            #expect(distance > 0.2,
                    "인덱스 \(i)와 \(i+1)의 색이 너무 가깝다: \(distance)")
        }
    }

    // TC-2
    @Test("색상 값이 0 이상 1 미만에 머문다")
    func huesStayInRange() {
        for index in 0..<200 {
            let hue = Treemap.hue(for: index)
            #expect(hue >= 0 && hue < 1, "인덱스 \(index)에서 범위 이탈: \(hue)")
        }
    }

    // TC-3
    @Test("자식 타일이 부모 사각형 안에 들어간다")
    func childTilesStayInsideParent() {
        let children = (0..<4).map {
            DiskUsageNode(url: URL(filePath: "/private/tmp/c\($0)"),
                          size: Int64(400 - $0 * 80))
        }
        let parent = DiskUsageNode(url: URL(filePath: "/private/tmp/p"),
                                   size: 1_000, children: children)
        let outer = CGRect(x: 0, y: 0, width: 300, height: 200)
        let inner = CGRect(x: 6, y: 36, width: outer.width - 12, height: outer.height - 46)

        #expect(Treemap.fitsChildren(inner))
        for tile in Treemap.layout(parent.children, in: inner) {
            #expect(inner.contains(tile.rect.origin), "자식이 부모 밖에서 시작한다")
            #expect(tile.rect.maxX <= inner.maxX + 0.01)
            #expect(tile.rect.maxY <= inner.maxY + 0.01)
        }
    }

    // TC-4
    @Test("작은 사각형에는 자식을 그리지 않는다")
    func tinyRectsSkipChildren() {
        #expect(!Treemap.fitsChildren(CGRect(x: 0, y: 0, width: 39, height: 100)))
        #expect(!Treemap.fitsChildren(CGRect(x: 0, y: 0, width: 100, height: 23)))
        #expect(!Treemap.fitsChildren(.zero))
        #expect(Treemap.fitsChildren(CGRect(x: 0, y: 0, width: 41, height: 25)))
    }
}
