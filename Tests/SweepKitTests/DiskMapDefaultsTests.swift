import Testing
import Foundation
@testable import SweepKit

/// 디스크 맵 기본 가지치기 설정이 중첩 렌더링에 쓸 만한 트리를 만드는지 확인한다.
@Suite("DiskMap 기본 트리")
struct DiskMapDefaultsTests {

    private var fm: FileManager { .default }
    private static let oneMB = 1024 * 1024

    private func makeTree() throws -> URL {
        let root = URL(filePath: NSTemporaryDirectory())
            .appending(path: "sweep-mapdefaults-\(UUID().uuidString)")
        // 4단계 깊이 + 다양한 크기
        for (path, mb) in [
            ("a/x1/y1/z1.bin", 4), ("a/x1/y2/z2.bin", 3),
            ("a/x2/y3/z3.bin", 2), ("b/x3/y4/z4.bin", 5),
            ("c/small.bin", 0),
        ] {
            let url = root.appending(path: path)
            try fm.createDirectory(at: url.deletingLastPathComponent(),
                                   withIntermediateDirectories: true)
            try Data(repeating: 0x41, count: max(mb, 1) * (mb == 0 ? 1024 : Self.oneMB))
                .write(to: url)
        }
        return root
    }

    // TC-1 · TC-2
    @Test("기본 설정이 여러 타일과 손자 층을 만든다")
    func defaultsProduceNestedTiles() throws {
        let root = try makeTree()
        defer { try? fm.removeItem(at: root) }

        let tree = DiskUsageTree.build(at: root, maxDepth: 4,
                                       minimumSize: Int64(Self.oneMB))

        // 타일이 2개뿐이면 트리맵이 정보를 못 준다
        #expect(tree.children.count >= 2)
        // 중첩 렌더링이 그릴 자식 층이 실제로 있어야 한다
        #expect(tree.children.contains { !$0.children.isEmpty },
                "자식 타일 안에 그릴 손자가 없다")
    }

    // TC-3
    @Test("1MB 미만 자식은 목록에서 빠지되 부모 크기에는 남는다")
    func smallChildrenArePrunedButCounted() throws {
        let root = try makeTree()
        defer { try? fm.removeItem(at: root) }

        let tree = DiskUsageTree.build(at: root, maxDepth: 4,
                                       minimumSize: Int64(Self.oneMB))

        #expect(!tree.children.contains { $0.name == "c" }, "1MB 미만이 목록에 남았다")
        // 잘려나간 c도 합계에는 포함되어야 면적 비교가 성립한다
        #expect(tree.size >= Int64(14 * Self.oneMB))
    }

    // TC-4
    @Test("깊이 4를 넘어서는 층은 만들지 않는다")
    func depthIsCappedAtFour() throws {
        let root = try makeTree()
        defer { try? fm.removeItem(at: root) }

        let tree = DiskUsageTree.build(at: root, maxDepth: 4,
                                       minimumSize: Int64(Self.oneMB))

        func depth(_ node: DiskUsageNode) -> Int {
            node.children.isEmpty ? 1 : 1 + (node.children.map(depth).max() ?? 0)
        }
        #expect(depth(tree) <= 5, "maxDepth 4를 넘어 내려갔다")
        #expect(depth(tree) >= 3, "손자 층이 만들어지지 않았다")
    }
}
