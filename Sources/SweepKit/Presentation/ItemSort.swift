import Foundation

/// 정리 항목 표의 정렬. 헤더를 누르면 바뀐다.
///
/// 묶음(판단 기준·카테고리)은 그대로 두고 **묶음 안**을 정렬한다. 묶음은 판단이
/// 정반대인 것을 섞지 않으려고 나눈 것이라 정렬로 흐트러뜨리면 안 된다.
public struct ItemSort: Equatable, Sendable {
    public enum Key: Sendable, CaseIterable {
        case name, detail, dates, size, safety
    }

    public var key: Key
    public var ascending: Bool

    public init(key: Key, ascending: Bool) {
        self.key = key
        self.ascending = ascending
    }

    /// 큰 것부터. 무엇이 자리를 차지하는지가 첫 질문이다.
    public static let `default` = ItemSort(key: .size, ascending: false)

    /// 처음 누를 때 방향. 크기는 큰 것부터, 나머지는 오름차순 — 날짜는 오래 안 쓴 것부터.
    static func initialAscending(_ key: Key) -> Bool { key != .size }

    /// 같은 열이면 방향을 뒤집고, 다른 열이면 그 열의 처음 방향으로.
    public func toggled(_ key: Key) -> ItemSort {
        key == self.key
            ? ItemSort(key: key, ascending: !ascending)
            : ItemSort(key: key, ascending: Self.initialAscending(key))
    }

    public func sorted(_ items: [CleanupItem]) -> [CleanupItem] {
        items.sorted(by: precedes)
    }

    /// `a`가 `b`보다 앞에 오는가.
    func precedes(_ a: CleanupItem, _ b: CleanupItem) -> Bool {
        switch order(a, b) {
        case .unknownLast(let aFirst): return aFirst
        case .ordered(let aFirst): return ascending ? aFirst : !aFirst
        case .tie: break
        }
        // 동점은 크기 → 이름으로 갈라 다시 그릴 때마다 순서가 흔들리지 않게 한다.
        if a.sortSize != b.sortSize { return a.sortSize > b.sortSize }
        return a.displayName.localizedStandardCompare(b.displayName) == .orderedAscending
    }

    private enum Order {
        /// 오름차순 기준 비교. 방향에 따라 뒤집는다.
        case ordered(aFirst: Bool)
        /// 값을 모르는 쪽을 뒤로. 방향과 상관없다 — 빈 날짜가 맨 위로 오면 쓸모없다.
        case unknownLast(aFirst: Bool)
        case tie
    }

    private func order(_ a: CleanupItem, _ b: CleanupItem) -> Order {
        switch key {
        case .size:
            return a.sortSize == b.sortSize ? .tie : .ordered(aFirst: a.sortSize < b.sortSize)
        case .name:
            return Self.text(a.displayName, b.displayName)
        case .detail:
            return Self.text(a.detail, b.detail)
        case .safety:
            return a.safety == b.safety ? .tie : .ordered(aFirst: a.safety < b.safety)
        case .dates:
            switch (Self.date(of: a), Self.date(of: b)) {
            case (nil, nil): return .tie
            case (nil, _): return .unknownLast(aFirst: false)
            case (_, nil): return .unknownLast(aFirst: true)
            case (let l?, let r?): return l == r ? .tie : .ordered(aFirst: l < r)
            }
        }
    }

    /// 마지막 사용일을 먼저 본다. "얼마나 안 썼나"가 지울지 정하는 근거다.
    private static func date(of item: CleanupItem) -> Date? {
        item.dates.lastUsed ?? item.dates.created
    }

    private static func text(_ l: String, _ r: String) -> Order {
        switch l.localizedStandardCompare(r) {
        case .orderedSame: .tie
        case .orderedAscending: .ordered(aFirst: true)
        case .orderedDescending: .ordered(aFirst: false)
        }
    }
}

private extension CleanupItem {
    /// 크기순 정렬값. iCloud에만 있는 20GB가 Mac 크기 0이라 맨 아래로 가지 않게 둘을 더한다.
    var sortSize: Int64 { size + cloudBytes }
}
