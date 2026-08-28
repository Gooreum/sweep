import Testing
import Foundation
@testable import SweepKit

@Suite("DevCacheScanner")
struct DevCacheScannerTests {

    private func makeFakeHome() throws -> URL {
        let home = URL(filePath: NSTemporaryDirectory())
            .appending(path: "sweep-devcache-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        return home
    }

    /// `~/Library/Caches/<name>` 아래에 1MB 파일 하나를 심는다.
    private func seedCache(_ name: String, in home: URL, bytes: Int = 1024 * 1024) throws {
        let dir = home.appending(path: "Library/Caches").appending(path: name)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(repeating: 0x41, count: bytes).write(to: dir.appending(path: "blob.bin"))
    }

    // TC-1
    @Test("화이트리스트 캐시가 safe·설명과 함께 후보로 올라온다")
    func findsWhitelistedCache() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        try seedCache("org.swift.swiftpm", in: home)

        let items = await DevCacheScanner(home: home).scan()

        #expect(items.count == 1)
        #expect(items.first?.category == .devCache)
        #expect(items.first?.safety == .safe)
        #expect(items.first?.detail == "Swift Package Manager 캐시")
    }

    // TC-2
    @Test("화이트리스트에 없는 앱 캐시는 후보로 올라오지 않는다")
    func ignoresUnlistedAppCache() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        try seedCache("com.apple.Safari", in: home)

        let items = await DevCacheScanner(home: home).scan()
        #expect(items.isEmpty, "앱 세션 캐시가 후보로 샜다")
    }

    // TC-3
    @Test("비어 있는 캐시 디렉토리는 결과에서 제외된다")
    func excludesEmptyCacheDirectory() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        try FileManager.default.createDirectory(
            at: home.appending(path: "Library/Caches/CocoaPods"),
            withIntermediateDirectories: true)

        let items = await DevCacheScanner(home: home).scan()
        #expect(items.isEmpty)
    }

    // TC-4
    @Test("Library/Caches 자체가 없어도 던지지 않는다")
    func missingCachesDirectoryIsEmpty() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        let items = await DevCacheScanner(home: home).scan()
        #expect(items.isEmpty)
    }

    // TC-5
    @Test("여러 화이트리스트 캐시가 모두 safe로 반환된다")
    func findsMultipleCaches() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        try seedCache("Homebrew", in: home)
        try seedCache("go-build", in: home)
        try seedCache("typescript", in: home)

        let items = await DevCacheScanner(home: home).scan()

        #expect(items.count == 3)
        #expect(items.allSatisfy { $0.safety == .safe })
        #expect(Set(items.map(\.displayName)) == ["Homebrew", "go-build", "typescript"])
    }

    // TC-6
    @Test("개발 캐시는 전부 기본 선택 대상이다")
    func allAreSelectedByDefault() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        try seedCache("deno", in: home)
        try seedCache("node-gyp", in: home)

        let items = await DevCacheScanner(home: home).scan()
        #expect(items.count == 2)
        #expect(items.allSatisfy { $0.isSelectedByDefault })
    }

    // TC-7
    @Test("실제 홈 스캔 결과가 모두 삭제 관문을 통과한다")
    func realHomeItemsPassSafetyGate() async {
        let items = await DevCacheScanner().scan()
        for item in items {
            #expect(ProtectedPaths.isRemovable(item.url), "관문 미통과: \(item.url.path)")
        }
    }

    // TC-8
    @Test("화이트리스트 이름의 접두사만 같은 디렉토리는 제외된다")
    func doesNotMatchPrefixSiblings() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        try seedCache("org.swift.swiftpm-backup", in: home)

        let items = await DevCacheScanner(home: home).scan()
        #expect(items.isEmpty, "접두사가 같다는 이유로 잘못 매칭됐다")
    }
}
