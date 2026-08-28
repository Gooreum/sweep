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

    // MARK: - URL 중복 제거

    // TC-8
    @Test("같은 경로를 두 스캐너가 잡아도 결과에 한 번만 나온다")
    func deduplicatesByURL() async {
        let shared = allowed("shared.zip", size: 5_000, category: .largeFile)
        let sameURLAsDuplicate = CleanupItem(
            url: shared.url, size: 5_000, category: .duplicate, safety: .safe)

        let coordinator = ScanCoordinator(scanners: [
            FakeScanner(category: .largeFile, items: [shared]),
            FakeScanner(category: .duplicate, items: [sameURLAsDuplicate]),
        ])

        let items = await coordinator.scan()

        #expect(items.count == 1, "같은 경로가 두 번 잡혀 합계가 두 배가 된다")
        #expect(items.totalSize == 5_000)
    }

    // TC-9
    @Test("중복 제거 시 위에 오는 카테고리가 이긴다")
    func dedupeKeepsHigherPriorityCategory() async {
        let url = home.appending(path: "Library/Caches/contested.bin")
        let asLarge = CleanupItem(url: url, size: 9_000, category: .largeFile, safety: .caution)
        let asDuplicate = CleanupItem(url: url, size: 9_000, category: .duplicate, safety: .safe)

        // 넣는 순서를 바꿔도 결과가 같아야 한다
        for scanners in [[asDuplicate, asLarge], [asLarge, asDuplicate]] {
            let items = await ScanCoordinator(scanners: [
                FakeScanner(category: .largeFile, items: scanners),
            ]).scan()

            #expect(items.count == 1)
            // largeFile(sortOrder 4) < duplicate(sortOrder 5) 이므로 largeFile이 남는다
            #expect(items.first?.category == .largeFile)
        }
    }

    // TC-10
    @Test("중복이 없으면 기존 정렬이 그대로 유지된다")
    func dedupeDoesNotDisturbOrdering() async {
        let coordinator = ScanCoordinator(scanners: [
            FakeScanner(category: .devCache, items: [
                allowed("small", size: 100),
                allowed("large", size: 9_000),
            ]),
            FakeScanner(category: .runawayTemp, items: [
                allowed("temp", size: 50, category: .runawayTemp),
            ]),
        ])

        let items = await coordinator.scan()

        #expect(items.map(\.displayName) == ["temp", "large", "small"])
        #expect(items.count == 3)
    }

    // MARK: - 증분 스트림

    private func collect(_ coordinator: ScanCoordinator) async -> [ScanCoordinator.Progress] {
        var got: [ScanCoordinator.Progress] = []
        for await progress in coordinator.stream() { got.append(progress) }
        return got
    }

    // TC-1 · TC-7
    @Test("완료 이벤트가 스캐너 수만큼 나오고 마지막이 100%다")
    func streamReportsEveryScannerCompletion() async {
        let coordinator = ScanCoordinator(scanners: [
            FakeScanner(category: .devCache, items: [allowed("a")]),
            FakeScanner(category: .devCache, items: [allowed("b")]),
            FakeScanner(category: .devCache, items: [allowed("c")]),
        ])

        let progresses = await collect(coordinator)

        // 진행 보고마다 yield하므로 개수는 스캐너 수보다 많다.
        // 계약은 "완료 수가 1..3을 모두 거치고 마지막이 100%"다.
        #expect(Set(progresses.map(\.finishedScanners)).isSuperset(of: [1, 2, 3]))
        #expect(progresses.map(\.finishedScanners) == progresses.map(\.finishedScanners).sorted())
        #expect(progresses.allSatisfy { $0.totalScanners == 3 })
        #expect(progresses.last?.fraction == 1.0)
        #expect(progresses.last?.items.count == 3)
        #expect(progresses.last?.estimatedRemaining == nil, "완료 시점에 남은 시간이 남아 있다")
    }

    @Test("진행률이 단조 증가한다")
    func fractionNeverGoesBackwards() async {
        let coordinator = ScanCoordinator(scanners: [
            FakeScanner(category: .devCache, items: [allowed("a")]),
            FakeScanner(category: .devCache, items: [allowed("b")], delay: .milliseconds(80)),
        ])

        let fractions = await collect(coordinator).map(\.fraction)

        #expect(fractions == fractions.sorted(), "진행률이 뒤로 갔다: \(fractions)")
        #expect(fractions.allSatisfy { $0 >= 0 && $0 <= 1 })
    }

    // TC-2
    @Test("마지막 중간 결과가 scan() 결과와 같다")
    func finalProgressMatchesScan() async {
        let coordinator = ScanCoordinator(scanners: [
            FakeScanner(category: .runawayTemp, items: [allowed("t", size: 50, category: .runawayTemp)]),
            FakeScanner(category: .devCache, items: [allowed("big", size: 9_000), allowed("small", size: 10)]),
        ])

        let progresses = await collect(coordinator)
        let scanned = await coordinator.scan()

        #expect(progresses.last?.items == scanned)
    }

    // TC-3
    @Test("중간 결과에도 허용 루트 필터가 걸린다")
    func intermediateResultsAreFiltered() async {
        let leaked = CleanupItem(url: home.appending(path: "Documents/비밀.txt"),
                                 size: 5_000, category: .devCache, safety: .safe)
        let coordinator = ScanCoordinator(scanners: [
            FakeScanner(category: .devCache, items: [leaked, allowed("ok")]),
            FakeScanner(category: .devCache, items: [allowed("ok2")], delay: .milliseconds(100)),
        ])

        let progresses = await collect(coordinator)

        for progress in progresses {
            #expect(!progress.items.contains { $0.url.path.contains("Documents") },
                    "중간 결과에 허용 밖 경로가 샜다")
        }
    }

    // TC-4
    @Test("중간 결과도 카테고리·크기 순으로 정렬돼 있다")
    func intermediateResultsAreSorted() async {
        let coordinator = ScanCoordinator(scanners: [
            FakeScanner(category: .devCache, items: [
                allowed("small", size: 10), allowed("large", size: 9_000),
            ]),
            FakeScanner(category: .runawayTemp, items: [
                allowed("temp", size: 5, category: .runawayTemp),
            ], delay: .milliseconds(80)),
        ])

        for progress in await collect(coordinator) {
            let orders = progress.items.map(\.category.sortOrder)
            #expect(orders == orders.sorted(), "카테고리 정렬이 깨졌다")
        }
    }

    // TC-5
    @Test("중간 결과에도 경로 중복 제거가 적용된다")
    func intermediateResultsAreDeduplicated() async {
        let shared = allowed("shared", size: 5_000, category: .largeFile)
        let twin = CleanupItem(url: shared.url, size: 5_000,
                               category: .duplicate, safety: .safe)
        let coordinator = ScanCoordinator(scanners: [
            FakeScanner(category: .largeFile, items: [shared]),
            FakeScanner(category: .duplicate, items: [twin], delay: .milliseconds(60)),
        ])

        let progresses = await collect(coordinator)

        for progress in progresses {
            #expect(Set(progress.items.map(\.url)).count == progress.items.count)
        }
        #expect(progresses.last?.items.count == 1)
    }

    // TC-6
    @Test("스캐너가 없어도 100%로 끝맺는다")
    func emptyCoordinatorFinishesAtFullProgress() async {
        let progresses = await collect(ScanCoordinator(scanners: []))

        // 진행 막대가 0%에 멈춘 채로 끝나면 안 된다
        #expect(progresses.count == 1)
        #expect(progresses.first?.fraction == 1.0)
        #expect(progresses.first?.items.isEmpty == true)
    }

    // TC-8
    @Test("빠른 스캐너 결과가 느린 것을 기다리지 않고 먼저 나온다")
    func fastScannerYieldsFirst() async {
        let coordinator = ScanCoordinator(scanners: [
            FakeScanner(category: .devCache, items: [allowed("fast")]),
            FakeScanner(category: .devCache, items: [allowed("slow")],
                        delay: .milliseconds(250)),
        ])

        let progresses = await collect(coordinator)
        let completions = progresses.filter { $0.finishedScanners > 0 }

        // 느린 스캐너를 기다리지 않고 빠른 쪽 결과가 먼저 완료로 보고된다
        #expect(completions.first?.items.map(\.displayName) == ["fast"])
        #expect(Set(progresses.last?.items.map(\.displayName) ?? []) == ["fast", "slow"])
    }
}
