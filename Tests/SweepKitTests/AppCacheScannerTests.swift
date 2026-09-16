import Testing
import Foundation
@testable import SweepKit

@Suite("AppCacheScanner")
struct AppCacheScannerTests {

    private func makeFakeHome() throws -> URL {
        let home = URL(filePath: NSTemporaryDirectory())
            .appending(path: "sweep-appcache-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        return home
    }

    private static let oneMB = 1024 * 1024

    /// `~/Library/Application Support/<path>` 아래에 파일 하나를 심는다.
    @discardableResult
    private func seed(_ path: String, in home: URL, bytes: Int = oneMB) throws -> URL {
        let dir = home.appending(path: "Library/Application Support").appending(path: path)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(repeating: 0x41, count: bytes).write(to: dir.appending(path: "blob.bin"))
        return dir
    }

    // TC-1
    @Test("깊이가 달라도 앱 캐시를 찾아낸다")
    func findsCachesAtVaryingDepths() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        try seed("Slack/Cache", in: home)                                    // depth 2
        try seed("Notion/Partitions/notion/Cache", in: home)                 // depth 4
        try seed("Google/Chrome/Default/Service Worker/CacheStorage", in: home) // depth 5

        let items = await AppCacheScanner(home: home).scan()

        #expect(items.count == 3)
        #expect(items.allSatisfy { $0.category == .appCache })
    }

    // TC-2
    @Test("사용자 데이터 폴더는 후보가 되지 않는다")
    func ignoresUserDataFolders() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        try seed("Slack/IndexedDB", in: home)
        try seed("Slack/Local Storage", in: home)
        try seed("Notion/File System", in: home)
        try seed("Google/Chrome/Default/Local Extension Settings", in: home)

        let items = await AppCacheScanner(home: home).scan()
        #expect(items.isEmpty)
    }

    // TC-3
    @Test("Service Worker는 CacheStorage만 잡고 등록 정보는 남긴다")
    func collectsOnlyCacheStorageUnderServiceWorker() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        try seed("Slack/Service Worker/CacheStorage", in: home, bytes: 4 * Self.oneMB)
        // 등록 정보. 지우면 켜져 있는 앱이 재등록에 실패한다.
        try seed("Slack/Service Worker/Database", in: home, bytes: 2 * Self.oneMB)
        try seed("Slack/Service Worker/ScriptCache", in: home, bytes: 2 * Self.oneMB)

        let items = await AppCacheScanner(home: home).scan()

        #expect(items.count == 1)
        #expect(items.first?.url.lastPathComponent == "CacheStorage")
        #expect(!items.contains { $0.url.lastPathComponent == "Database" })
        #expect(!items.contains { $0.url.lastPathComponent == "ScriptCache" })
    }

    // TC-4
    @Test("CacheStorage는 caution이라 기본 선택되지 않는다")
    func cacheStorageIsCaution() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        try seed("Slack/Service Worker/CacheStorage", in: home, bytes: 4 * Self.oneMB)
        try seed("Slack/Cache", in: home, bytes: 4 * Self.oneMB)

        let items = await AppCacheScanner(home: home).scan()
        let byName = Dictionary(uniqueKeysWithValues:
            items.map { ($0.url.lastPathComponent, $0) })

        // 오프라인 자산은 다시 받는 데 시간이 든다 — 전체 선택에 딸려가면 안 된다.
        #expect(byName["CacheStorage"]?.safety == .caution)
        #expect(byName["CacheStorage"]?.isSelectedByDefault == false)
        #expect(byName["Cache"]?.safety == .safe)
        #expect(byName["Cache"]?.isSelectedByDefault == true)
    }

    // TC-5
    @Test("캐시 폴더 안쪽은 다시 세지 않는다")
    func doesNotDoubleCountNestedCache() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        // Chromium이 실제로 만드는 구조: Cache/Cache_Data
        try seed("Slack/Cache/Cache_Data", in: home, bytes: 4 * Self.oneMB)

        let items = await AppCacheScanner(home: home).scan()

        // `Cache`만 한 번 올라와야 한다. 안쪽까지 세면 합계가 두 배가 된다.
        #expect(items.count == 1)
        #expect(items.first?.url.lastPathComponent == "Cache")
    }

    // TC-6
    @Test("같은 앱의 서로 다른 캐시는 각각 올라온다")
    func siblingCachesAreSeparateItems() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        // 서로의 조상이 아니므로 둘 다 후보다 — 중복이 아니다.
        try seed("Notion/Cache", in: home, bytes: 2 * Self.oneMB)
        try seed("Notion/Partitions/notion/Cache", in: home, bytes: 4 * Self.oneMB)

        let items = await AppCacheScanner(home: home).scan()

        #expect(items.count == 2)
        #expect(Set(items.map(\.url)).count == 2)
    }

    // TC-7
    @Test("1MB 미만 캐시는 목록을 채우지 않는다")
    func skipsTinyCaches() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        try seed("Claude/GPUCache", in: home, bytes: 100 * 1024)       // 100KB
        try seed("Claude/Cache", in: home, bytes: 2 * Self.oneMB)

        let items = await AppCacheScanner(home: home).scan()

        #expect(items.count == 1)
        #expect(items.first?.url.lastPathComponent == "Cache")
    }

    // TC-8
    @Test("너무 깊은 곳은 훑지 않는다")
    func stopsAtMaxDepth() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        try seed("a/b/c/d/e/f/Cache", in: home, bytes: 4 * Self.oneMB)

        let items = await AppCacheScanner(home: home).scan()
        #expect(items.isEmpty)
    }

    // TC-9
    @Test("설명에 어느 앱의 캐시인지 담는다")
    func detailNamesTheApp() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        try seed("Slack/Cache", in: home, bytes: 2 * Self.oneMB)

        let items = await AppCacheScanner(home: home).scan()
        // 경로만 보여주면 어느 앱 것인지 읽히지 않는다.
        #expect(items.first?.detail.contains("Slack") == true)
    }

    // TC-10
    @Test("브라우저 캐시도 함께 찾는다")
    func findsBrowserCacheUnderLibraryCaches() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        // ~/Library/Caches/Google — 허용 루트 안이지만 어느 스캐너도 안 보던 곳이다.
        let dir = home.appending(path: "Library/Caches/Google/Chrome/Default/Cache")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(repeating: 0x41, count: 4 * Self.oneMB)
            .write(to: dir.appending(path: "blob.bin"))

        let items = await AppCacheScanner(home: home).scan()

        #expect(items.count == 1)
        #expect(items.first?.category == .appCache)
    }

    // TC-11
    @Test("실제 홈 스캔이 던지지 않고 전부 관문을 통과한다")
    func realHomeScanIsConsistent() async {
        let items = await AppCacheScanner().scan()
        #expect(items.allSatisfy { $0.category == .appCache })
        for item in items {
            #expect(ProtectedPaths.isRemovable(item.url), "관문 미통과: \(item.url.path)")
        }
    }

    // TC-12
    @Test("앱이 없는 빈 홈에서는 빈 배열을 반환한다")
    func emptyHomeYieldsNothing() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        let items = await AppCacheScanner(home: home).scan()
        #expect(items.isEmpty)
    }
}
