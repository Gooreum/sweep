import Foundation

/// 큰 파일·중복 파일을 찾는 곳. 스캐너와 관문(`RemovalScope.userFiles`)이 **같은 목록**을 본다.
///
/// 두 벌로 두면 스캐너가 찾은 것을 관문이 버린다 — 예전에는 스캐너도 관문도
/// `~/Downloads` 하나만 알아서, Desktop의 4GB 영상은 찾을 길이 없었다.
///
/// 홈 자체를 루트로 두지 않는다. 그러면 `~/Library`가 통째로 열린다.
/// **홈 바로 아래의 보이는 폴더 하나씩**이 루트다.
public enum UserFolders {

    /// 추가할 수 없는 폴더와 그 이유.
    public enum Rejection: Error, Equatable, Sendable {
        /// `/`, 홈 자체, 홈을 품는 폴더. 홈 아래 보이는 폴더는 이미 다 본다.
        case tooWide(URL)
        /// `~/Library` 안. 앱 데이터라 다른 검사들이 이름으로 골라 본다.
        case insideLibrary(URL)
        /// 시스템 폴더. 내 파일이 아니다.
        case systemFolder(URL)
        /// 이미 보는 곳이거나 그 안이다.
        case alreadyCovered(URL)
        /// 샌드박스에서 접근 권한(북마크)을 저장하지 못했다.
        case bookmark(String)

        public var message: String {
            switch self {
            case .tooWide:
                String(localized: "내 폴더 안은 이미 모두 찾고 있어요. 내 폴더 전체나 그 상위 폴더는 추가할 수 없어요.")
            case .insideLibrary:
                String(localized: "Library는 여기에 추가할 수 없어요. 앱이 만든 파일은 ‘정리할 파일’에서 확인하세요.")
            case .systemFolder:
                String(localized: "컴퓨터에 필요한 폴더라 추가할 수 없어요.")
            case .alreadyCovered(let url):
                String(localized: "따로 추가하지 않아도 찾는 곳이에요: \(CleanupItem.abbreviating(url.path, home: Sandbox.userHome.path))")
            case .bookmark(let reason):
                String(localized: "이 폴더를 다시 열 수 있도록 저장하는 데 실패했어요. \(reason)")
            }
        }
    }

    /// 홈 바로 아래에서 뺄 폴더. Library는 다른 스캐너들 몫이고 사용자 파일이 아니다.
    /// Applications는 앱 번들 규칙(`ProtectedPaths.isApplicationBundle`)이 따로 다룬다.
    static let excludedHomeChildren: Set<String> = ["Library", "Applications"]

    /// 열거할 때 아래로 내려가지 않는 폴더 이름. 다시 만들어지는 의존성·빌드 산출물이라
    /// 큰 파일 목록을 뒤덮고, 안의 파일 하나만 지우면 프로젝트가 깨진다.
    static let skippedDirectoryNames: Set<String> = ["node_modules", "Pods", "DerivedData", "Carthage"]

    /// 추가를 막는 시스템 폴더. 자신과 그 아래 전부.
    static let systemFolders: [URL] = [
        "/System", "/Library", "/private", "/usr", "/bin", "/sbin", "/opt",
        "/Applications", "/cores", "/dev",
    ].map { URL(filePath: $0) }

    /// 홈 바로 아래의 보이는 폴더. Downloads는 샌드박스에서 링크라 푼다(`DownloadsFolder`).
    ///
    /// 링크는 뺀다 — 링크 너머는 홈 밖일 수 있고, 같은 폴더를 두 번 훑게 된다.
    /// 번들(`.app` 등)도 뺀다. 안의 파일 하나만 지우면 번들이 깨진다.
    static func homeFolders(in home: URL) -> [URL] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey]
        let children = (try? FileManager.default.contentsOfDirectory(
            at: home, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])) ?? []

        let folders = children.filter { url in
            guard !excludedHomeChildren.contains(url.lastPathComponent),
                  url.lastPathComponent != "Downloads",
                  let v = try? url.resourceValues(forKeys: Set(keys))
            else { return false }
            return v.isDirectory == true && v.isSymbolicLink != true && v.isPackage != true
        }
        // Downloads는 늘 넣는다. 샌드박스에서는 홈을 열거하지 못해도 entitlement로 열린다.
        return [DownloadsFolder.url(in: home)]
            + folders.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// 큰 파일·중복 파일을 찾는 루트 전부. 홈의 보이는 폴더 + 사용자가 추가한 폴더.
    ///
    /// 샌드박스에서는 Downloads와 허락받은 곳 안에 있는 것만 남긴다 — 막힌 곳을
    /// 훑는 스캐너는 결과 없이 시간만 쓴다(`Feature.scanners`와 같은 이유).
    /// 같은 곳이 두 번 나오거나 한 루트가 다른 루트 안에 있으면 바깥 것만 남긴다.
    public static func roots(home: URL = Sandbox.userHome,
                             custom: [URL] = shared.custom,
                             sandboxed: Bool = Sandbox.isActive,
                             granted: [URL] = FolderAccess.shared.urls) -> [URL] {
        let downloads = DownloadsFolder.url(in: home)
        let candidates = homeFolders(in: home) + custom

        let open = candidates.filter { root in
            guard sandboxed else { return true }
            if root.isSameOrDescendant(of: downloads) { return true }
            let canonicalRoot = root.resolvingSymlinksInPath()
            return granted.contains { canonicalRoot.isSameOrDescendant(of: $0) }
        }

        var kept: [URL] = []
        for root in open where !kept.contains(where: { root.isSameOrDescendant(of: $0) }) {
            kept.removeAll { $0.isDescendant(of: root) }
            kept.append(root)
        }
        return kept
    }

    /// 사용자가 이 폴더를 추가할 수 있는가. 되면 nil, 안 되면 이유.
    ///
    /// `existing`은 지금 보는 루트다. 샌드박스에서 홈을 허락하지 않았으면 Documents가
    /// 거기 없으므로 추가할 수 있다 — 그게 샌드박스 사용자가 폴더를 여는 길이다.
    public static func validateCustom(_ url: URL, home: URL = Sandbox.userHome,
                                      existing: [URL]) -> Rejection? {
        let picked = url.resolvingSymlinksInPath().standardizedFileURL
        let realHome = home.resolvingSymlinksInPath().standardizedFileURL

        if picked.pathComponents == ["/"] || realHome.isSameOrDescendant(of: picked) {
            return .tooWide(picked)
        }
        if picked.isSameOrDescendant(of: realHome.appending(path: "Library")) {
            return .insideLibrary(picked)
        }
        // `/Volumes` 자체는 막고 그 아래(외장 디스크)는 연다.
        // 홈 안은 시스템 폴더가 아니다 — 홈이 `/private/var/...`에 있는 경우(테스트)도 같다.
        if picked.path == "/Volumes"
            || (!picked.isDescendant(of: realHome)
                && systemFolders.contains(where: { picked.isSameOrDescendant(of: $0.resolvingSymlinksInPath()) })) {
            return .systemFolder(picked)
        }
        if existing.contains(where: { picked.isSameOrDescendant(of: $0.resolvingSymlinksInPath()) }) {
            return .alreadyCovered(picked)
        }
        return nil
    }

    /// 사용자가 추가한 폴더의 허락 단위. 샌드박스에서 북마크를 저장·복원할 때 쓴다.
    ///
    /// 라벨이 북마크 키가 되므로(`Grantable.key`) 경로 그대로 둔다 — 폴더마다 달라야 한다.
    public static func grantable(for url: URL) -> FolderAccess.Grantable {
        FolderAccess.Grantable(folder: url, label: url.standardizedFileURL.path,
                               purpose: String(localized: "큰 파일과 중복 파일 찾기"))
    }

    // MARK: - 관문용 캐시

    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var cached: (at: Date, components: [[String]])?

    /// 관문이 후보마다 묻는 루트 구성요소. **1초 동안 재사용한다.**
    ///
    /// 홈 열거는 싸지 않다. 후보 수천 개를 거를 때마다 홈을 다시 열거하면
    /// `ProtectedPaths`가 루트를 캐시하는 이유(실측 6초)를 그대로 되풀이한다.
    static func cachedRootComponents(now: Date = Date()) -> [[String]] {
        cacheLock.lock(); defer { cacheLock.unlock() }
        if let cached, now.timeIntervalSince(cached.at) < 1 { return cached.components }
        let components = roots().map {
            ProtectedPaths.canonical($0).standardizedFileURL.pathComponents
        }
        cached = (now, components)
        return components
    }

    /// 폴더를 추가·제거하면 바로 반영되도록 캐시를 버린다.
    static func invalidateCache() {
        cacheLock.lock(); defer { cacheLock.unlock() }
        cached = nil
    }

    // MARK: - 사용자가 추가한 폴더

    /// 앱 전체가 공유하는 목록.
    public static let shared = Registry()

    /// 사용자가 추가한 폴더 목록. 경로 문자열로 UserDefaults에 둔다.
    ///
    /// 샌드박스의 접근 권한(북마크)은 여기서 다루지 않는다 — `FolderAccess`가 맡는다.
    /// 이 목록은 "어디를 볼지"만 기억한다.
    public final class Registry: @unchecked Sendable {
        static let key = "customScanFolders"

        private let defaults: UserDefaults
        private let lock = NSLock()

        /// 저장소를 주입할 수 있게 연다 — 테스트가 `.standard`를 건드리지 않게.
        init(defaults: UserDefaults = .standard) {
            self.defaults = defaults
        }

        public var custom: [URL] {
            lock.lock(); defer { lock.unlock() }
            return paths.map { URL(filePath: $0, directoryHint: .isDirectory) }
        }

        private var paths: [String] { defaults.stringArray(forKey: Self.key) ?? [] }

        /// 검사를 통과하면 저장한다. `existing`은 지금 보는 루트다.
        public func add(_ url: URL, home: URL = Sandbox.userHome,
                        existing: [URL]) throws(Rejection) {
            let picked = url.resolvingSymlinksInPath().standardizedFileURL
            if let rejection = UserFolders.validateCustom(picked, home: home,
                                                          existing: existing + custom) {
                throw rejection
            }
            lock.lock()
            defaults.set(paths + [picked.path], forKey: Self.key)
            lock.unlock()
            UserFolders.invalidateCache()
        }

        public func remove(_ url: URL) {
            let target = FolderAccess.components(of: url)
            lock.lock()
            defaults.set(paths.filter {
                FolderAccess.components(of: URL(filePath: $0)) != target
            }, forKey: Self.key)
            lock.unlock()
            UserFolders.invalidateCache()
        }
    }
}
