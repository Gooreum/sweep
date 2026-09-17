import Foundation

/// 앱이 만든 웹 캐시를 찾는다. Electron·Chromium 앱이 공통 이름으로 쌓는다.
///
/// 경로를 조립하는 `DevCacheScanner` 방식이 여기서는 통하지 않는다 —
/// 실측한 깊이가 제각각이다.
///
/// ```
/// Slack/Cache                                              (2)
/// Notion/Partitions/notion/Cache                           (4)
/// Figma/DesktopProfile/v39/Cache                           (4)
/// Google/Chrome/Default/Service Worker/CacheStorage        (5)
/// ```
///
/// 앱 이름도, 프로필 버전도, 파티션 이름도 기계마다 다르다. 그래서 훑되
/// **끝 이름이 맞는 폴더만** 후보로 올린다. 무엇이 열리는지는 관문이 정한다
/// (`ProtectedPaths.appCacheSuffixes`) — 목록의 주인을 스캐너에 두면
/// 스캐너를 고칠 때 관문이 조용히 넓어진다.
public struct AppCacheScanner: CleanupScanner {
    public let category: ScanCategory = .appCache

    private let home: URL

    /// `Application Support`를 열어도 되는가.
    ///
    /// 전체 디스크 접근이 없으면 그 아래 **앱마다** "다른 앱의 데이터에 접근하려고
    /// 합니다"가 뜬다. 한 번 허용해도 다음 앱에서 또 묻는다 — 끝이 없다.
    /// 그래서 꺼져 있으면 아예 열지 않는다. 못 찾는 대신 화면의 배너가
    /// "켜면 앱 캐시까지 찾는다"고 말한다.
    private let canReadAppData: Bool

    public init(home: URL = Sandbox.userHome,
                canReadAppData: Bool = FullDiskAccess.isGranted) {
        self.home = home
        self.canReadAppData = canReadAppData
    }

    /// 실측 0.9초.
    public var progressWeight: Double { 0.9 }

    /// 1MB 미만은 올리지 않는다. 실측으로 84개 중 61개가 548KB짜리 빈 `Dawn*` 폴더였고,
    /// 다 합쳐야 20MB였다. `StaleCacheScanner`와 같은 값·같은 이유다.
    private static let minimumSize: Int64 = 1024 * 1024

    public func scan() async -> [CleanupItem] {
        var items: [CleanupItem] = []
        if canReadAppData {
            collect(in: home.appending(path: "Library/Application Support"),
                    depth: 0, into: &items)
        }
        // `Library/Caches`는 앱 데이터 보호 대상이 **아니다** — 전체 디스크 접근과
        // 무관하게 늘 훑는다.
        // 허용 루트 안이지만 어느 스캐너도 보지 않던 곳이다.
        // `DevCacheScanner` 화이트리스트에 없고, 매일 쓰는 브라우저라
        // `StaleCacheScanner`의 90일 조건에도 걸리지 않아 영영 잡히지 않았다.
        collect(in: home.appending(path: "Library/Caches/Google"), depth: 0, into: &items)
        return items
    }

    /// 끝 이름이 맞으면 후보로 올리고 **그 아래로는 내려가지 않는다.**
    ///
    /// 계속 내려가면 `Notion/Cache`와 `Notion/Cache/Cache_Data`를 둘 다 세서 합계가 부푼다.
    /// `ScanCoordinator.normalize`의 중복 제거는 **같은 경로**만 잡지 조상-자손 관계는
    /// 잡지 못하므로 여기서 막아야 한다.
    ///
    /// `Service Worker`는 이름이 맞지 않아 한 단계 더 내려가고, 거기서 `CacheStorage`가
    /// 2칸 suffix로 맞는다. 형제인 `Database`·`ScriptCache`는 맞지 않아 그대로 남는다.
    private func collect(in directory: URL, depth: Int, into items: inout [CleanupItem]) {
        guard depth < ProtectedPaths.appCacheMaxDepth else { return }

        for child in children(of: directory) {
            guard (try? child.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
            else { continue }

            guard ProtectedPaths.matchesAppCacheName(child) else {
                collect(in: child, depth: depth + 1, into: &items)
                continue
            }

            let found = DirectorySize.summary(at: child)
            guard found.bytes >= Self.minimumSize else { continue }

            items.append(CleanupItem(url: child, size: found.bytes, category: .appCache,
                                     safety: Self.safety(of: child),
                                     detail: Self.detail(for: child),
                                     dates: found.dates))
        }
    }

    /// 오프라인 자산은 다시 받는 데 시간이 든다 — `caution`은 기본 선택에서 빠지므로
    /// "전체 선택 → 삭제"에 4GB가 통째로 딸려가지 않는다.
    private static func safety(of url: URL) -> SafetyLevel {
        url.lastPathComponent == "CacheStorage" ? .caution : .safe
    }

    private static func detail(for url: URL) -> String {
        let app = appName(of: url)
        return url.lastPathComponent == "CacheStorage"
            ? "\(app) 오프라인 자산 — 다시 내려받습니다"
            : "\(app)이(가) 다시 만듭니다"
    }

    /// `.../Application Support/Slack/Cache` → `Slack`.
    /// 경로만 보여주면 어느 앱 것인지 알기 어렵다.
    private static func appName(of url: URL) -> String {
        let parts = url.pathComponents
        guard let anchor = parts.lastIndex(where: {
            $0 == "Application Support" || $0 == "Caches"
        }), anchor + 1 < parts.count else { return "앱" }
        return parts[anchor + 1]
    }
}
