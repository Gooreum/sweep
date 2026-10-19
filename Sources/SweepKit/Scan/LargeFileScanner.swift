import Foundation

/// 사용자 폴더(`UserFolders.roots`)의 크고 독립적인 파일을 찾는다.
///
/// 허용 루트 전체를 훑지 않는 이유: 실측 결과 100MB 이상 파일 11개 중 8개가
/// 다른 스캐너가 이미 보고하는 디렉토리의 **내부** 파일이었다.
/// 같은 바이트를 두 번 세는 데다, 번들 안의 바이너리 하나만 지우면 번들이 깨지고
/// 회수도 되지 않는다. 그래서 `~/Library`는 빼고, 번들 내부·의존성 폴더도 내려가지 않는다
/// (`UserFileWalker`). 통째로 지울 수 있는 독립 파일만 후보로 올린다.
public struct LargeFileScanner: CleanupScanner {
    public let category: ScanCategory = .largeFile

    public let minimumSize: Int64

    private let home: URL
    private let roots: [URL]
    private let isDataless: @Sendable (URL) -> Bool

    /// `roots`를 주지 않으면 그 홈의 사용자 폴더 전부다.
    public init(minimumSize: Int64 = 100 * 1024 * 1024,
                home: URL = Sandbox.userHome,
                roots: [URL]? = nil) {
        self.init(minimumSize: minimumSize, home: home, roots: roots,
                  isDataless: { UserFileWalker.isDataless($0) })
    }

    /// iCloud 자리표시자 판정을 갈아끼운다 — 테스트에서 그런 파일은 만들 수 없다.
    init(minimumSize: Int64, home: URL, roots: [URL]?,
         isDataless: @escaping @Sendable (URL) -> Bool) {
        self.minimumSize = minimumSize
        self.home = home
        self.roots = roots ?? UserFolders.roots(home: home)
        self.isDataless = isDataless
    }

    /// Downloads 하나일 때 실측 0.29초였다. 홈의 보이는 폴더 전부(이 기계 17곳)로 넓히자
    /// 테스트 실행 중 실측 10.7초가 됐다.
    public var progressWeight: Double { 10 }

    public func scan() async -> [CleanupItem] {
        await scan(onProgress: { _ in })
    }

    /// 루트 하나를 끝낼 때마다 알린다. 홈 전체는 몇 초가 걸려 끝에 한 번만 알리면 멈춰 보인다.
    public func scan(onProgress: @escaping @Sendable (Double) -> Void) async -> [CleanupItem] {
        let downloads = DownloadsFolder.url(in: home)
        var items: [CleanupItem] = []

        for (index, root) in roots.enumerated() {
            let downloaded = root.isSameOrDescendant(of: downloads)
            items += UserFileWalker.files(under: root, minimumSize: minimumSize, isDataless: isDataless)
                .filter { $0.allocatedSize >= minimumSize }
                .map { found in
                    CleanupItem(
                        url: found.url,
                        size: found.allocatedSize,
                        category: .largeFile,
                        // 사용자가 일부러 받거나 만든 파일이다. 자동 선택하지 않는다.
                        safety: .caution,
                        detail: Self.detail(modified: found.modified ?? .distantPast,
                                            downloaded: downloaded),
                        dates: FileDates(created: found.created, lastUsed: found.modified))
                }
            onProgress(Double(index + 1) / Double(roots.count))
        }
        if roots.isEmpty { onProgress(1) }
        return items
    }

    /// "3개월 전에 받았습니다"처럼 판단 근거가 되는 시점을 준다.
    ///
    /// Downloads 밖의 파일은 받은 것이 아니다. 같은 시점을 "수정했습니다"로 말한다.
    static func detail(modified: Date, downloaded: Bool = true, now: Date = Date()) -> String {
        let days = Int(now.timeIntervalSince(modified) / 86_400)
        if downloaded {
            switch days {
            case ..<1: return String(localized: "오늘 받았어요")
            case ..<30: return String(localized: "\(days)일 전에 받았어요")
            default: return String(localized: "\(days / 30)개월 전에 받았어요")
            }
        }
        switch days {
        case ..<1: return String(localized: "오늘 수정했어요")
        case ..<30: return String(localized: "\(days)일 전에 수정했어요")
        default: return String(localized: "\(days / 30)개월 전에 수정했어요")
        }
    }
}
