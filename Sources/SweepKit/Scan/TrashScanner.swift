import Foundation

/// 휴지통에 든 것을 찾는다. Finder 휴지통이 합쳐 보여주는 곳을 모두 본다 —
/// `~/.Trash`, iCloud Drive 휴지통, 외장 디스크의 `.Trashes/<uid>`.
///
/// 이미 버린 것이라 지워도 잃는 게 없어 보이지만, **비우면 되돌릴 수 없다.**
/// 다른 항목은 지우면 휴지통으로 가서 되살릴 수 있는데 이것만은 아니다.
/// 그래서 caution이다 — 자동 선택하지 않는다.
///
/// 전체 디스크 접근이 없으면 읽지 못한다(TCC). 그때는 빈 배열이다.
public struct TrashScanner: CleanupScanner {
    public let category: ScanCategory = .trash

    private let home: URL
    private let volumes: URL
    private let isDataless: @Sendable (URL) -> Bool

    /// `volumes`·`isDataless`는 테스트가 갈아끼운다 — 진짜 외장 디스크를 읽으면 안 되고,
    /// iCloud 자리표시자는 테스트에서 만들 수 없다.
    public init(home: URL = Sandbox.userHome, volumes: URL = URL(filePath: "/Volumes")) {
        self.init(home: home, volumes: volumes, isDataless: UserFileWalker.isDataless)
    }

    init(home: URL, volumes: URL, isDataless: @escaping @Sendable (URL) -> Bool) {
        self.home = home
        self.volumes = volumes
        self.isDataless = isDataless
    }

    /// 바로 아래 항목마다 크기를 잰다. 휴지통이 크면 몇 초까지 걸린다.
    public var progressWeight: Double { 1 }

    /// 읽을 휴지통과 그 안 항목에 붙일 설명. 설명이 곧 출처 표시다.
    func locations() -> [(folder: URL, detail: String)] {
        var found = [
            (home.appending(path: ".Trash"), String(localized: "비우면 되돌릴 수 없습니다")),
            (Self.iCloudTrash(in: home),
             String(localized: "iCloud Drive 휴지통 — 비우면 다른 기기에서도 사라집니다")),
        ]
        // 시동 디스크는 `/Volumes/Macintosh HD → /`라 홈 휴지통과 겹친다. 실경로가 `/`인 것은 뺀다.
        for volume in children(of: volumes) where volume.resolvingSymlinksInPath().path != "/" {
            found.append((volume.appending(path: ".Trashes/\(getuid())"),
                          String(localized: "\(volume.lastPathComponent) 휴지통 — 비우면 되돌릴 수 없습니다")))
        }
        return found
    }

    public func scan() async -> [CleanupItem] {
        locations().flatMap { folder, detail in
            children(of: folder).compactMap { url in
                let found = DirectorySize.summary(at: url)
                // iCloud에만 있고 이 Mac에 내용이 없는 항목은 할당 크기가 0이다. 지워도 이 Mac의
                // 공간은 그대로지만 iCloud 공간이 비워지고, 남겨 두면 Finder 휴지통에 계속 보인다.
                let cloudOnly = found.bytes == 0 && isDataless(url)
                guard found.bytes > 0 || cloudOnly else { return nil }
                return CleanupItem(url: url, size: found.bytes, category: .trash, safety: .caution,
                                   detail: cloudOnly
                                       ? String(localized: "iCloud에만 있음 — 지우면 iCloud 공간만 비워집니다")
                                       : detail,
                                   dates: found.dates)
            }
        }
    }

    static func iCloudTrash(in home: URL) -> URL {
        home.appending(path: "Library/Mobile Documents/.Trash")
    }

    /// iCloud Drive 휴지통 안의 항목인가. 비우면 다른 기기에서도 지워져 확인 창이 따로 말한다.
    public static func isInICloudTrash(_ url: URL, home: URL = Sandbox.userHome) -> Bool {
        url.standardizedFileURL.isDescendant(of: iCloudTrash(in: home))
    }
}
