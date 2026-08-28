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

    // MARK: - 화이트리스트 확대 · 로그 수집

    /// `~/Library/Logs/<name>` 아래에 파일 하나를 심는다.
    private func seedLog(_ name: String, in home: URL, bytes: Int = 1024 * 1024) throws {
        let dir = home.appending(path: "Library/Logs").appending(path: name)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(repeating: 0x41, count: bytes).write(to: dir.appending(path: "app.log"))
    }

    // TC-1
    @Test("신규 개발 도구 캐시 9종이 화이트리스트에 있다")
    func newToolsAreWhitelisted() {
        let names = DevCacheScanner.knownCacheNames
        for expected in ["pnpm", "Yarn", "ms-playwright", "Cypress", "electron",
                         "electron-builder", "pip", "uv", "bazelisk"] {
            #expect(names.contains(expected), "화이트리스트에 없음: \(expected)")
        }
    }

    // TC-2
    @Test("화이트리스트에 이름 중복이 없다")
    func whitelistHasNoDuplicates() {
        #expect(DevCacheScanner.knownCacheNames.count == DevCacheScanner.knownCaches.count)
    }

    // TC-3
    @Test("Library/Logs 하위 항목이 safe로 수집된다")
    func collectsLogs() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        try seedLog("MyApp", in: home)

        let items = await DevCacheScanner(home: home).scan()

        #expect(items.count == 1)
        #expect(items.first?.category == .devCache)
        #expect(items.first?.safety == .safe)
        #expect(items.first?.detail == "로그 파일입니다")
        #expect(items.first?.displayName == "MyApp")
    }

    // TC-4
    @Test("캐시와 로그가 함께 수집되고 설명이 구분된다")
    func collectsBothCachesAndLogs() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        try seedCache("pnpm", in: home)
        try seedLog("Simulator", in: home)

        let items = await DevCacheScanner(home: home).scan()
        let byName = Dictionary(uniqueKeysWithValues: items.map { ($0.displayName, $0) })

        #expect(items.count == 2)
        #expect(byName["pnpm"]?.detail == "pnpm 스토어 캐시")
        #expect(byName["Simulator"]?.detail == "로그 파일입니다")
    }

    // TC-5
    @Test("Library/Logs가 없어도 캐시 항목은 정상 반환된다")
    func missingLogsDirectoryIsFine() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        try seedCache("uv", in: home)

        let items = await DevCacheScanner(home: home).scan()
        #expect(items.map(\.displayName) == ["uv"])
    }

    // TC-6
    @Test("비어 있는 로그 디렉토리는 결과에서 제외된다")
    func emptyLogDirectoryIsExcluded() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        try FileManager.default.createDirectory(
            at: home.appending(path: "Library/Logs/Empty"), withIntermediateDirectories: true)

        let items = await DevCacheScanner(home: home).scan()
        #expect(items.isEmpty)
    }

    // TC-7 · TC-8
    @Test("Library/Logs는 하위만 삭제 가능하고 자체는 거부된다")
    func logsRootAllowsChildrenOnly() {
        let logs = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Logs")

        #expect(!ProtectedPaths.isRemovable(logs), "로그 루트 자체가 통과했다")
        #expect(ProtectedPaths.isRemovable(logs.appending(path: "SomeApp")))
    }

    // TC-9
    @Test("실제 홈 스캔 결과가 전부 devCache이고 관문을 통과한다")
    func realHomeScanIsConsistent() async {
        let items = await DevCacheScanner().scan()
        #expect(items.allSatisfy { $0.category == .devCache })
        for item in items {
            #expect(ProtectedPaths.isRemovable(item.url), "관문 미통과: \(item.url.path)")
        }
    }
}
