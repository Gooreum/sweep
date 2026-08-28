import Foundation

/// `~/Library/Caches` 안의 개발 도구 캐시. 전부 재생성되므로 safe다.
public struct DevCacheScanner: CleanupScanner {
    public let category: ScanCategory = .devCache

    private let home: URL

    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.home = home
    }

    /// 이름 화이트리스트다. `~/Library/Caches`를 통째로 열거하면
    /// 앱 로그인 상태·세션 캐시까지 후보에 섞여, 사용자가 "전체 선택 → 삭제"를 눌렀을 때
    /// 엉뚱하게 로그아웃이 발생한다.
    private static let knownCaches: [(name: String, detail: String)] = [
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
    ]

    public func scan() async -> [CleanupItem] {
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
}
