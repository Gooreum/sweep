import Foundation

/// 개발 프로젝트를 찾는 폴더(예: `~/Code`). 사용자가 직접 등록한 곳만 본다.
///
/// 스캐너(`ProjectArtifactScanner`)와 관문(`RemovalScope.projectArtifacts`)이 **같은 목록**을 본다.
/// 큰 파일 탭의 「직접 추가한 폴더」(`UserFolders`)와는 따로 둔다 — 합치면 프로젝트 폴더를
/// 등록하는 것만으로 큰 파일 탐색 범위까지 넓어지고, 한쪽을 빼면 다른 쪽까지 닫힌다.
public enum ProjectFolders {

    /// 등록할 수 있는 폴더인가. 되면 nil, 안 되면 이유.
    ///
    /// 홈·`/`·Library·시스템 폴더를 막는 규칙은 `UserFolders.validateCustom`을 그대로 쓴다.
    /// `existing`은 이미 등록한 프로젝트 폴더다. 그 안은 `alreadyCovered`다.
    public static func validate(_ url: URL, home: URL = Sandbox.userHome,
                                existing: [URL]) -> UserFolders.Rejection? {
        UserFolders.validateCustom(url, home: home, existing: existing)
    }

    /// 거절 사유를 이 화면의 말로 바꾼다. `UserFolders`의 문구는 큰 파일 탭 기준이다.
    public static func message(for rejection: UserFolders.Rejection) -> String {
        switch rejection {
        case .tooWide:
            String(localized: "내 폴더 전체는 너무 넓어요. ~/Code처럼 코드만 모인 폴더를 골라 주세요.")
        case .insideLibrary:
            String(localized: "Library 안은 프로젝트 폴더로 등록할 수 없어요.")
        case .alreadyCovered(let url):
            String(localized: "이미 보고 있는 폴더 안이에요: \(CleanupItem.abbreviating(url.path, home: Sandbox.userHome.path))")
        case .systemFolder, .bookmark:
            rejection.message
        }
    }

    /// 「보는 폴더」 줄에 쓰는 경로. 홈은 `~`로 줄인다.
    public static func displayPath(_ url: URL) -> String {
        CleanupItem.abbreviating(url.path, home: Sandbox.userHome.path)
    }

    /// 샌드박스 북마크 단위. 키 접두사를 `UserFolders`와 따로 둔다 —
    /// 같은 폴더를 양쪽에 등록했을 때 한쪽을 빼면 다른 쪽 북마크까지 지워지지 않게.
    public static func grantable(for url: URL) -> FolderAccess.Grantable {
        FolderAccess.Grantable(folder: url, label: url.standardizedFileURL.path,
                               purpose: String(localized: "개발 프로젝트의 설치·빌드 폴더 찾기"),
                               keyPrefix: "projectFolder.")
    }

    /// 스캔할 루트. 샌드박스에서는 허락받은 곳 안의 것만 남긴다 — 막힌 곳을 훑는
    /// 스캐너는 결과 없이 시간만 쓴다. 한 루트가 다른 루트 안이면 바깥 것만 남긴다.
    public static func roots(custom: [URL] = shared.custom,
                             sandboxed: Bool = Sandbox.isActive,
                             granted: [URL] = FolderAccess.shared.urls) -> [URL] {
        let open = custom.filter { root in
            guard sandboxed else { return true }
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

    // MARK: - 관문용 캐시

    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var cached: (at: Date, components: [[String]])?

    /// 관문이 후보마다 묻는 루트 구성요소. `UserFolders.cachedRootComponents`와 같은 이유로
    /// 1초 동안 재사용한다.
    static func cachedRootComponents(now: Date = Date()) -> [[String]] {
        cacheLock.lock(); defer { cacheLock.unlock() }
        if let cached, now.timeIntervalSince(cached.at) < 1 { return cached.components }
        let components = roots().map {
            ProtectedPaths.canonical($0).standardizedFileURL.pathComponents
        }
        cached = (now, components)
        return components
    }

    static func invalidateCache() {
        cacheLock.lock(); defer { cacheLock.unlock() }
        cached = nil
    }

    /// 등록한 프로젝트 폴더 안(자기 포함)인가. 관문과 같은 캐시를 쓴다.
    static func contains(_ url: URL, now: Date = Date()) -> Bool {
        let parts = ProtectedPaths.canonical(url).standardizedFileURL.pathComponents
        return cachedRootComponents(now: now).contains { root in
            parts.count >= root.count && Array(parts.prefix(root.count)) == root
        }
    }

    // MARK: - 등록한 폴더

    public static let shared = Registry()

    /// 등록한 프로젝트 폴더 목록. 경로 문자열로 UserDefaults에 둔다.
    /// 접근 권한(북마크)은 `FolderAccess`가 맡는다.
    public final class Registry: @unchecked Sendable {
        static let key = "projectScanFolders"

        private let defaults: UserDefaults
        private let lock = NSLock()

        init(defaults: UserDefaults = .standard) {
            self.defaults = defaults
        }

        public var custom: [URL] {
            lock.lock(); defer { lock.unlock() }
            return paths.map { URL(filePath: $0, directoryHint: .isDirectory) }
        }

        private var paths: [String] { defaults.stringArray(forKey: Self.key) ?? [] }

        /// 검사를 통과하면 저장한다.
        public func add(_ url: URL, home: URL = Sandbox.userHome) throws(UserFolders.Rejection) {
            let picked = url.resolvingSymlinksInPath().standardizedFileURL
            if let rejection = ProjectFolders.validate(picked, home: home, existing: custom) {
                throw rejection
            }
            lock.lock()
            defaults.set(paths + [picked.path], forKey: Self.key)
            lock.unlock()
            ProjectFolders.invalidateCache()
        }

        public func remove(_ url: URL) {
            let target = FolderAccess.components(of: url)
            lock.lock()
            defaults.set(paths.filter {
                FolderAccess.components(of: URL(filePath: $0)) != target
            }, forKey: Self.key)
            lock.unlock()
            ProjectFolders.invalidateCache()
        }
    }
}
