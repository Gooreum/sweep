import Foundation

/// 휴지통(`~/.Trash`)에 든 것을 찾는다.
///
/// 이미 버린 것이라 지워도 잃는 게 없어 보이지만, **비우면 되돌릴 수 없다.**
/// 다른 항목은 지우면 휴지통으로 가서 되살릴 수 있는데 이것만은 아니다.
/// 그래서 caution이다 — 자동 선택하지 않는다.
///
/// 전체 디스크 접근이 없으면 읽지 못한다(TCC). 그때는 빈 배열이다.
public struct TrashScanner: CleanupScanner {
    public let category: ScanCategory = .trash

    private let home: URL

    public init(home: URL = Sandbox.userHome) {
        self.home = home
    }

    /// 바로 아래 항목마다 크기를 잰다. 휴지통이 크면 몇 초까지 걸린다.
    public var progressWeight: Double { 1 }

    public func scan() async -> [CleanupItem] {
        children(of: home.appending(path: ".Trash")).compactMap { url in
            let found = DirectorySize.summary(at: url)
            guard found.bytes > 0 else { return nil }
            return CleanupItem(url: url, size: found.bytes, category: .trash,
                               safety: .caution,
                               detail: String(localized: "비우면 되돌릴 수 없습니다"),
                               dates: found.dates)
        }
    }
}
