import Testing
import Foundation
@testable import SweepKit

@Suite("ItemSort")
@MainActor
struct ItemSortTests {

    private func item(_ name: String, size: Int64 = 1_000, safety: SafetyLevel = .safe,
                      detail: String = "", lastUsed: Date? = nil,
                      category: ScanCategory = .devCache) -> CleanupItem {
        CleanupItem(url: URL(filePath: "/private/tmp/sort/\(name)"), size: size,
                    category: category, safety: safety, detail: detail,
                    dates: FileDates(lastUsed: lastUsed))
    }

    private func names(_ items: [CleanupItem]) -> [String] { items.map(\.displayName) }

    // TC-1
    @Test("기본은 크기 큰 것부터")
    func defaultIsSizeDescending() {
        let sorted = ItemSort.default.sorted([item("a", size: 1), item("b", size: 30), item("c", size: 7)])
        #expect(names(sorted) == ["b", "c", "a"])
    }

    @Test("크기순에서 iCloud에만 있는 큰 항목이 작은 Mac 항목보다 앞선다")
    func cloudOnlyItemsSortByCloudBytes() {
        let cloud = CleanupItem(url: URL(filePath: "/private/tmp/sort/cloud"), size: 0,
                                category: .trash, safety: .caution, cloudBytes: 5_000_000_000)
        let sorted = ItemSort.default.sorted([item("mac", size: 1_000_000), cloud])
        #expect(names(sorted) == ["cloud", "mac"])
    }

    // TC-2
    @Test("같은 열은 방향을 뒤집고 다른 열은 그 열의 처음 방향으로")
    func toggling() {
        let size = ItemSort.default
        #expect(size.toggled(.size) == ItemSort(key: .size, ascending: true))
        let name = size.toggled(.name)
        #expect(name == ItemSort(key: .name, ascending: true))
        #expect(name.toggled(.name) == ItemSort(key: .name, ascending: false))
        #expect(name.toggled(.size) == .default)
        #expect(size.toggled(.dates) == ItemSort(key: .dates, ascending: true))
    }

    // TC-3
    @Test("이름은 숫자를 숫자로 읽는다")
    func nameUsesLocalizedStandardOrder() {
        let sort = ItemSort(key: .name, ascending: true)
        #expect(names(sort.sorted([item("file10"), item("file2"), item("File1")])) == ["File1", "file2", "file10"])
        #expect(names(ItemSort(key: .name, ascending: false).sorted([item("a"), item("b")])) == ["b", "a"])
    }

    // TC-4
    @Test("날짜는 오래된 것부터, 날짜 없는 항목은 두 방향 모두 맨 뒤")
    func datesPutUnknownLast() {
        let old = item("old", lastUsed: Date(timeIntervalSince1970: 1_000))
        let new = item("new", lastUsed: Date(timeIntervalSince1970: 9_000))
        let none = item("none", size: 99_999)
        let up = ItemSort(key: .dates, ascending: true).sorted([none, new, old])
        let down = ItemSort(key: .dates, ascending: false).sorted([none, old, new])
        #expect(names(up) == ["old", "new", "none"])
        #expect(names(down) == ["new", "old", "none"])
    }

    // TC-5
    @Test("동점은 크기 큰 것이 먼저")
    func tiesBreakBySize() {
        let sort = ItemSort(key: .detail, ascending: true)
        let sorted = sort.sorted([item("small", size: 1, detail: "캐시"), item("big", size: 9, detail: "캐시"),
                                  item("first", size: 1, detail: "가")])
        #expect(names(sorted) == ["first", "big", "small"])
    }

    @Test("안전도는 안전한 것부터")
    func safetyAscending() {
        let sorted = ItemSort(key: .safety, ascending: true)
            .sorted([item("d", safety: .danger), item("s", safety: .safe), item("c", safety: .caution)])
        #expect(names(sorted) == ["s", "c", "d"])
    }

    // MARK: - ScanModel 연결

    private func model(_ items: [CleanupItem]) async -> ScanModel {
        let model = ScanModel(scan: {
            AsyncStream { continuation in
                continuation.yield(ScanCoordinator.Progress(
                    items: items, fraction: 1, elapsed: .seconds(1), estimatedRemaining: nil,
                    finishedScanners: 1, totalScanners: 1))
                continuation.finish()
            }
        })
        await model.scan()
        return model
    }

    // TC-6
    @Test("안전도로 거꾸로 정렬하면 판단 기준 묶음 순서가 뒤집힌다")
    func safetyDescendingReversesGroups() async {
        let model = await model([item("d", safety: .danger), item("s", safety: .safe),
                                 item("c", safety: .caution)])
        func levels() -> [SafetyLevel] {
            model.safetyGroups.compactMap { if case .safety(let l) = $0.kind { l } else { nil } }
        }
        #expect(levels() == [.safe, .caution, .danger])
        model.toggleSort(.safety)
        #expect(levels() == [.safe, .caution, .danger])
        model.toggleSort(.safety)
        #expect(model.sort == ItemSort(key: .safety, ascending: false))
        #expect(levels() == [.danger, .caution, .safe])
    }

    // TC-7
    @Test("이름으로 정렬하면 묶음 안 항목이 이름순")
    func toggleSortReordersWithinGroups() async {
        let model = await model([item("b", size: 9), item("c", size: 5), item("a", size: 1)])
        #expect(names(model.safetyGroups.flatMap(\.items)) == ["b", "c", "a"])
        model.toggleSort(.name)
        #expect(names(model.safetyGroups.flatMap(\.items)) == ["a", "b", "c"])
        #expect(names(model.groups.flatMap(\.items)) == ["a", "b", "c"])
    }
}
