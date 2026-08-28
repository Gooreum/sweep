import Testing
import Foundation
@testable import SweepKit

@Suite("StaleCacheScanner")
struct StaleCacheScannerTests {

    private var fm: FileManager { .default }
    private static let oneMB = 1024 * 1024

    private func makeFakeHome() throws -> URL {
        let home = URL(filePath: NSTemporaryDirectory())
            .appending(path: "sweep-stale-\(UUID().uuidString)")
        try fm.createDirectory(at: home.appending(path: "Library/Caches"),
                               withIntermediateDirectories: true)
        return home
    }

    /// 캐시 항목을 만들고 수정 시각을 원하는 만큼 과거로 돌린다.
    @discardableResult
    private func seed(_ name: String, in home: URL,
                      daysAgo: Int, bytes: Int = oneMB) throws -> URL {
        let dir = home.appending(path: "Library/Caches").appending(path: name)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appending(path: "blob.bin")
        try Data(repeating: 0x41, count: bytes).write(to: file)

        let when = Date().addingTimeInterval(-Double(daysAgo) * 86_400)
        try fm.setAttributes([.modificationDate: when], ofItemAtPath: file.path)
        try fm.setAttributes([.modificationDate: when], ofItemAtPath: dir.path)
        return dir
    }

    // TC-1
    @Test("200일 묵은 캐시가 검출되고 일수가 표시된다")
    func detectsStaleCache() async throws {
        let home = try makeFakeHome()
        defer { try? fm.removeItem(at: home) }
        try seed("dotslash", in: home, daysAgo: 200)

        let items = await StaleCacheScanner(home: home).scan()

        #expect(items.count == 1)
        #expect(items.first?.category == .staleCache)
        #expect(items.first?.displayName == "dotslash")
        #expect(items.first?.detail.contains("일 동안 쓰이지 않았습니다") == true)
    }

    // TC-2
    @Test("오늘 쓴 캐시는 검출되지 않는다")
    func ignoresFreshCache() async throws {
        let home = try makeFakeHome()
        defer { try? fm.removeItem(at: home) }
        try seed("active-tool", in: home, daysAgo: 0)

        let items = await StaleCacheScanner(home: home).scan()
        #expect(items.isEmpty)
    }

    // TC-3
    @Test("DevCacheScanner 화이트리스트 항목은 중복 보고되지 않는다")
    func skipsItemsAlreadyReportedByDevCacheScanner() async throws {
        let home = try makeFakeHome()
        defer { try? fm.removeItem(at: home) }
        // pnpm은 화이트리스트에 있으므로 아무리 묵어도 여기서는 보고하지 않는다
        try seed("pnpm", in: home, daysAgo: 400)
        try seed("unknown-tool", in: home, daysAgo: 400)

        let items = await StaleCacheScanner(home: home).scan()

        #expect(items.map(\.displayName) == ["unknown-tool"])
        #expect(DevCacheScanner.knownCacheNames.contains("pnpm"))
    }

    // TC-4
    @Test("minimumSize 미만인 묵은 항목은 제외된다")
    func skipsSmallStaleItems() async throws {
        let home = try makeFakeHome()
        defer { try? fm.removeItem(at: home) }
        try seed("tiny", in: home, daysAgo: 400, bytes: 1024)

        let items = await StaleCacheScanner(home: home).scan()
        #expect(items.isEmpty)
    }

    // TC-5
    @Test("묵은 캐시는 caution이라 기본 선택되지 않는다")
    func staleItemsAreCaution() async throws {
        let home = try makeFakeHome()
        defer { try? fm.removeItem(at: home) }
        try seed("old-tool", in: home, daysAgo: 300)

        let items = await StaleCacheScanner(home: home).scan()

        #expect(items.first?.safety == .caution)
        #expect(items.first?.isSelectedByDefault == false)
    }

    // TC-6
    @Test("Library/Caches가 없는 홈에서도 던지지 않는다")
    func missingCachesDirectoryIsEmpty() async throws {
        let home = URL(filePath: NSTemporaryDirectory())
            .appending(path: "sweep-stale-none-\(UUID().uuidString)")
        try fm.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: home) }

        let items = await StaleCacheScanner(home: home).scan()
        #expect(items.isEmpty)
    }

    // TC-7
    @Test("존재하지 않는 경로의 idleInterval은 nil이다")
    func idleIntervalOfMissingPathIsNil() {
        let ghost = URL(filePath: "/private/tmp/sweep-stale-ghost-\(UUID().uuidString)")
        #expect(StaleCacheScanner.idleInterval(of: ghost) == nil)
    }

    // TC-8
    @Test("하위 파일 하나만 최근이어도 살아 있는 캐시로 본다")
    func recentChildKeepsCacheAlive() async throws {
        let home = try makeFakeHome()
        defer { try? fm.removeItem(at: home) }

        let dir = try seed("mixed", in: home, daysAgo: 400)
        // 오래된 트리 안에 오늘 쓴 파일 하나를 넣는다
        let fresh = dir.appending(path: "fresh.bin")
        try Data(repeating: 0x42, count: Self.oneMB).write(to: fresh)

        let items = await StaleCacheScanner(home: home).scan()
        #expect(items.isEmpty, "하위에 최근 파일이 있는데 묵은 것으로 판정됐다")
    }

    // TC-9
    @Test("실제 홈 스캔이 관문을 통과하고 카테고리가 일관된다")
    func realHomeScanIsConsistent() async {
        let items = await StaleCacheScanner().scan()

        #expect(items.allSatisfy { $0.category == .staleCache })
        for item in items {
            #expect(ProtectedPaths.isRemovable(item.url), "관문 미통과: \(item.url.path)")
            #expect(item.safety == .caution)
        }
    }
}
