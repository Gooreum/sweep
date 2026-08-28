import Testing
import Foundation
@testable import SweepKit

/// 정해진 항목을 그대로 뱉는 가짜 스캐너. 선택적으로 지연을 줄 수 있다.
private struct FakeScanner: CleanupScanner {
    let category: ScanCategory
    let items: [CleanupItem]
    var delay: Duration = .zero

    func scan() async -> [CleanupItem] {
        if delay != .zero { try? await Task.sleep(for: delay) }
        return items
    }
}

@Suite("ScanCoordinator")
struct ScanCoordinatorTests {

    private var home: URL { FileManager.default.homeDirectoryForCurrentUser }

    /// 허용 루트(~/Library/Caches) 하위의 통과 가능한 경로.
    private func allowed(_ name: String, size: Int64 = 1_000,
                         category: ScanCategory = .devCache) -> CleanupItem {
        CleanupItem(url: home.appending(path: "Library/Caches/\(name)"),
                    size: size, category: category, safety: .safe)
    }

    // TC-1
    @Test("여러 스캐너의 결과가 하나로 병합된다")
    func mergesResultsFromAllScanners() async {
        let coordinator = ScanCoordinator(scanners: [
            FakeScanner(category: .devCache, items: [allowed("a")]),
            FakeScanner(category: .devCache, items: [allowed("b")]),
            FakeScanner(category: .devCache, items: [allowed("c")]),
        ])

        let items = await coordinator.scan()
        #expect(Set(items.map(\.displayName)) == ["a", "b", "c"])
    }

    // TC-2
    @Test("허용 루트 밖 항목은 2차 방어선에서 걸러진다")
    func filtersOutItemsOutsideAllowedRoots() async {
        let leaked = CleanupItem(url: home.appending(path: "Documents/비밀.txt"),
                                 size: 5_000, category: .devCache, safety: .safe)
        let coordinator = ScanCoordinator(scanners: [
            FakeScanner(category: .devCache, items: [leaked, allowed("ok")]),
        ])

        let items = await coordinator.scan()

        #expect(items.count == 1)
        #expect(items.first?.displayName == "ok")
        #expect(!items.contains { $0.url.path.contains("Documents") }, "허용 밖 경로가 샜다")
    }

    // TC-3
    @Test("크기가 0인 항목은 걸러진다")
    func filtersOutZeroSizedItems() async {
        let coordinator = ScanCoordinator(scanners: [
            FakeScanner(category: .devCache, items: [allowed("empty", size: 0), allowed("real")]),
        ])

        let items = await coordinator.scan()
        #expect(items.map(\.displayName) == ["real"])
    }

    // TC-4
    @Test("카테고리 정렬 순서대로 위험한 것이 위로 온다")
    func sortsByCategoryOrder() async {
        let coordinator = ScanCoordinator(scanners: [
            FakeScanner(category: .duplicate, items: [allowed("dup", category: .duplicate)]),
            FakeScanner(category: .devCache, items: [allowed("cache", category: .devCache)]),
            FakeScanner(category: .xcode, items: [allowed("xc", category: .xcode)]),
            FakeScanner(category: .runawayTemp, items: [allowed("temp", category: .runawayTemp)]),
        ])

        let items = await coordinator.scan()
        #expect(items.map(\.category) == [.runawayTemp, .xcode, .devCache, .duplicate])
    }

    // TC-5
    @Test("같은 카테고리 안에서는 큰 항목이 먼저 온다")
    func sortsBySizeDescendingWithinCategory() async {
        let coordinator = ScanCoordinator(scanners: [
            FakeScanner(category: .devCache, items: [
                allowed("small", size: 100),
                allowed("large", size: 9_000),
                allowed("medium", size: 3_000),
            ]),
        ])

        let items = await coordinator.scan()
        #expect(items.map(\.displayName) == ["large", "medium", "small"])
    }

    // TC-6
    @Test("스캐너가 없으면 빈 배열을 반환한다")
    func noScannersYieldsEmpty() async {
        let items = await ScanCoordinator(scanners: []).scan()
        #expect(items.isEmpty)
    }

    // TC-7
    @Test("빈 결과를 내는 스캐너가 섞여도 나머지 결과는 유지된다")
    func toleratesEmptyScanners() async {
        let coordinator = ScanCoordinator(scanners: [
            FakeScanner(category: .devCache, items: []),
            FakeScanner(category: .devCache, items: [allowed("survivor")]),
            FakeScanner(category: .devCache, items: []),
        ])

        let items = await coordinator.scan()
        #expect(items.map(\.displayName) == ["survivor"])
    }

    // TC-8
    @Test("standard() 실행 결과가 모두 삭제 관문을 통과한다")
    func standardScanPassesSafetyGate() async {
        let items = await ScanCoordinator.standard().scan()
        for item in items {
            #expect(ProtectedPaths.isRemovable(item.url), "관문 미통과: \(item.url.path)")
            #expect(item.size > 0)
        }
    }

    // TC-9
    @Test("느린 스캐너가 섞여도 결과가 누락되지 않는다")
    func slowScannerResultsAreNotDropped() async {
        let coordinator = ScanCoordinator(scanners: [
            FakeScanner(category: .devCache, items: [allowed("fast")]),
            FakeScanner(category: .devCache, items: [allowed("slow")],
                        delay: .milliseconds(300)),
        ])

        let items = await coordinator.scan()
        #expect(Set(items.map(\.displayName)) == ["fast", "slow"])
    }
}
