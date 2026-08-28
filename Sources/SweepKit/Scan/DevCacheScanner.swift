import Foundation

/// `~/Library/Caches`의 개발 도구 캐시와 `~/Library/Logs`의 로그를 찾는다.
/// 둘 다 다시 만들어지므로 safe다.
public struct DevCacheScanner: CleanupScanner {
    public let category: ScanCategory = .devCache

    private let home: URL

    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.home = home
    }

    /// 이름 화이트리스트다. `~/Library/Caches`를 통째로 열거하면
    /// 앱 로그인 상태·세션 캐시까지 후보에 섞여, 사용자가 "전체 선택 → 삭제"를 눌렀을 때
    /// 엉뚱하게 로그아웃이 발생한다.
    static let knownCaches: [(name: String, detail: String)] = [
        ("org.swift.swiftpm", "Swift Package Manager 캐시"),
        ("org.carthage.CarthageKit", "Carthage 캐시"),
        ("CocoaPods", "CocoaPods 캐시"),
        ("Homebrew", "Homebrew 내려받기 캐시"),
        ("com.apple.dt.Xcode", "Xcode 캐시"),
        ("go-build", "Go 빌드 캐시"),
        ("node-gyp", "node-gyp 캐시"),
        ("typescript", "TypeScript 캐시"),
        ("deno", "Deno 캐시"),
        ("JetBrains", "JetBrains IDE 캐시"),
        ("pnpm", "pnpm 스토어 캐시"),
        ("Yarn", "Yarn 캐시"),
        ("ms-playwright", "Playwright 브라우저 캐시"),
        ("Cypress", "Cypress 바이너리 캐시"),
        ("electron", "Electron 내려받기 캐시"),
        ("electron-builder", "electron-builder 캐시"),
        ("pip", "pip 내려받기 캐시"),
        ("uv", "uv 패키지 캐시"),
        ("bazelisk", "Bazelisk 캐시"),
    ]

    /// 화이트리스트 이름만 모아 둔다.
    /// `StaleCacheScanner`가 같은 항목을 두 번 보고하지 않도록 참조한다.
    static var knownCacheNames: Set<String> { Set(knownCaches.map(\.name)) }

    /// 실측 0.01초. 1초 안에 끝나므로 중간 보고 없이 완료 시점만 알린다.
    public var progressWeight: Double { 0.05 }

    public func scan() async -> [CleanupItem] {
        cacheItems() + logItems()
    }

    private func cacheItems() -> [CleanupItem] {
        let caches = home.appending(path: "Library/Caches")
        return Self.knownCaches.compactMap { known in
            let url = caches.appending(path: known.name)
            let size = DirectorySize.bytes(at: url)
            // 크기 0은 해당 도구가 없거나 캐시가 비었다는 뜻이다.
            guard size > 0 else { return nil }
            return CleanupItem(url: url, size: size, category: .devCache,
                               safety: .safe, detail: known.detail)
        }
    }

    /// 로그는 앱마다 이름이 달라 화이트리스트를 미리 만들 수 없다.
    /// 하위를 그대로 훑되, 앱이 다시 쓰면 재생성되므로 safe로 둔다.
    private func logItems() -> [CleanupItem] {
        children(of: home.appending(path: "Library/Logs")).compactMap { url in
            let size = DirectorySize.bytes(at: url)
            guard size > 0 else { return nil }
            return CleanupItem(url: url, size: size, category: .devCache,
                               safety: .safe, detail: "로그 파일입니다")
        }
    }
}
