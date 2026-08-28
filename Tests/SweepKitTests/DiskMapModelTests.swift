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

    // TC-7
    @Test("선택 가능한 시작점이 허용 루트와 같다")
    func rootsMatchAllowedRoots() {
        let model = DiskMapModel()
        #expect(model.availableRoots == ProtectedPaths.allowedRoots)
        #expect(!model.availableRoots.isEmpty)
    }

    @Test("load가 주입된 트리로 경로를 초기화한다")
    func loadSeedsPathFromInjectedTree() async {
        let tree = sampleTree()
        let model = DiskMapModel(buildTree: { _ in tree })

        await model.load(URL(filePath: "/private/tmp/root"))

        #expect(model.path.count == 1)
        #expect(model.current?.name == "root")
        #expect(!model.isScanning)
    }
}
