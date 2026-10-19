import Foundation

/// `~/Library/Caches`의 개발 도구 캐시와 `~/Library/Logs`의 로그를 찾는다.
/// 둘 다 다시 만들어지므로 safe다.
public struct DevCacheScanner: CleanupScanner {
    public let category: ScanCategory = .devCache

    private let home: URL

    public init(home: URL = Sandbox.userHome) {
        self.home = home
    }

    /// 이름 화이트리스트다. `~/Library/Caches`를 통째로 열거하면
    /// 앱 로그인 상태·세션 캐시까지 후보에 섞여, 사용자가 "전체 선택 → 삭제"를 눌렀을 때
    /// 엉뚱하게 로그아웃이 발생한다.
    static let knownCaches: [(name: String, detail: String)] = [
        ("org.swift.swiftpm", String(localized: "Swift Package Manager 캐시")),
        ("org.carthage.CarthageKit", String(localized: "Carthage 캐시")),
        ("CocoaPods", String(localized: "CocoaPods 캐시")),
        ("Homebrew", String(localized: "Homebrew 내려받기 캐시")),
        ("com.apple.dt.Xcode", String(localized: "Xcode 캐시")),
        ("go-build", String(localized: "Go 빌드 캐시")),
        ("node-gyp", String(localized: "node-gyp 캐시")),
        ("typescript", String(localized: "TypeScript 캐시")),
        ("deno", String(localized: "Deno 캐시")),
        ("JetBrains", String(localized: "JetBrains IDE 캐시")),
        ("pnpm", String(localized: "pnpm 스토어 캐시")),
        ("Yarn", String(localized: "Yarn 캐시")),
        ("ms-playwright", String(localized: "Playwright 브라우저 캐시")),
        ("Cypress", String(localized: "Cypress 바이너리 캐시")),
        ("electron", String(localized: "Electron 내려받기 캐시")),
        ("electron-builder", String(localized: "electron-builder 캐시")),
        ("pip", String(localized: "pip 내려받기 캐시")),
        ("uv", String(localized: "uv 패키지 캐시")),
        ("bazelisk", String(localized: "Bazelisk 캐시")),
    ]

    /// 화이트리스트 이름만 모아 둔다.
    /// `StaleCacheScanner`가 같은 항목을 두 번 보고하지 않도록 참조한다.
    static var knownCacheNames: Set<String> { Set(knownCaches.map(\.name)) }

    /// 홈 바로 아래 개발 도구가 만드는 캐시. 홈 기준 상대 경로다.
    ///
    /// `~/.npm`이나 `~/.expo` 폴더 자체를 올리지 않고 **안의 캐시 폴더만** 짚는다.
    /// `~/.expo`에는 `ngrok.yml`(인증 토큰)과 `state.json`(로그인 상태)이 캐시와 같은 층에 있다.
    /// 아래처럼 경로를 조립해 존재를 확인하는 방식이라 열거를 하지 않고, 그래서
    /// 목록에 없는 파일은 후보가 될 길이 없다.
    static let homeCaches: [(path: String, detail: String)] = [
        (".npm/_cacache", String(localized: "npm 내려받기 캐시")),
        (".npm/_npx", String(localized: "npx 실행 캐시")),
        (".expo/native-modules-cache", String(localized: "Expo 네이티브 모듈 캐시")),
        (".expo/versions-cache", String(localized: "Expo 버전 캐시")),
        (".expo/schema-cache", String(localized: "Expo 스키마 캐시")),
        (".expo/ios-simulator-app-cache", String(localized: "Expo 시뮬레이터 앱 캐시")),
        (".expo/expo-go", String(localized: "Expo Go 내려받기 캐시")),
    ]

    /// 홈 바로 아래 도구의 캐시 폴더. 이 폴더들은 관문의 **루트**라 통째로 지울 수 없다
    /// (`ProtectedPaths.homeToolRoots`) — 바로 아래 항목을 하나씩 올린다.
    ///
    /// 도구 폴더(`~/.gradle`)가 아니라 캐시 폴더를 짚는 이유는 `homeCaches`와 같다.
    /// 같은 층에 `gradle.properties`·`settings.xml`(인증 정보)과 `~/.cargo/bin`(실행 파일)이 있다.
    static let homeCacheRoots: [(path: String, detail: String)] = [
        (".gradle/caches", String(localized: "Gradle 캐시")),
        (".cargo/registry", String(localized: "Cargo 레지스트리 캐시")),
        (".m2/repository", String(localized: "Maven 저장소 캐시")),
    ]

    /// 실측 0.01초. 1초 안에 끝나므로 중간 보고 없이 완료 시점만 알린다.
    public var progressWeight: Double { 0.05 }

    public func scan() async -> [CleanupItem] {
        cacheItems() + homeCacheItems() + homeCacheRootItems() + logItems()
    }

    private func homeCacheItems() -> [CleanupItem] {
        Self.homeCaches.compactMap { known in
            let url = home.appending(path: known.path)
            let found = DirectorySize.summary(at: url)
            // 크기 0은 해당 도구가 없거나 캐시가 비었다는 뜻이다.
            guard found.bytes > 0 else { return nil }
            return CleanupItem(url: url, size: found.bytes, category: .devCache,
                               safety: .safe, detail: known.detail, dates: found.dates)
        }
    }

    private func homeCacheRootItems() -> [CleanupItem] {
        Self.homeCacheRoots.flatMap { known in
            children(of: home.appending(path: known.path)).compactMap { url -> CleanupItem? in
                let found = DirectorySize.summary(at: url)
                guard found.bytes > 0 else { return nil }
                return CleanupItem(url: url, size: found.bytes, category: .devCache,
                                   safety: .safe, detail: known.detail, dates: found.dates)
            }
        }
    }

    private func cacheItems() -> [CleanupItem] {
        let caches = home.appending(path: "Library/Caches")
        return Self.knownCaches.compactMap { known in
            let url = caches.appending(path: known.name)
            let found = DirectorySize.summary(at: url)
            // 크기 0은 해당 도구가 없거나 캐시가 비었다는 뜻이다.
            guard found.bytes > 0 else { return nil }
            return CleanupItem(url: url, size: found.bytes, category: .devCache,
                               safety: .safe, detail: known.detail, dates: found.dates)
        }
    }

    /// 로그는 앱마다 이름이 달라 화이트리스트를 미리 만들 수 없다.
    /// 하위를 그대로 훑되, 앱이 다시 쓰면 재생성되므로 safe로 둔다.
    private func logItems() -> [CleanupItem] {
        children(of: home.appending(path: "Library/Logs")).compactMap { url in
            let found = DirectorySize.summary(at: url)
            guard found.bytes > 0 else { return nil }
            return CleanupItem(url: url, size: found.bytes, category: .devCache,
                               safety: .safe, detail: String(localized: "로그 파일입니다"), dates: found.dates)
        }
    }
}
