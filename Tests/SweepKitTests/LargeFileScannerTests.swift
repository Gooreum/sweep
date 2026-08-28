import Testing
import Foundation
@testable import SweepKit

@Suite("LargeFileScanner")
struct LargeFileScannerTests {

    private var fm: FileManager { .default }
    private static let oneMB = 1024 * 1024

    private func makeFakeHome() throws -> URL {
        let home = URL(filePath: NSTemporaryDirectory())
            .appending(path: "sweep-large-\(UUID().uuidString)")
        try fm.createDirectory(at: home.appending(path: "Downloads"),
                               withIntermediateDirectories: true)
        return home
    }

    @discardableResult
    private func place(_ name: String, megabytes: Int, in home: URL,
                       subdirectory: String? = nil) throws -> URL {
        var dir = home.appending(path: "Downloads")
        if let subdirectory {
            dir = dir.appending(path: subdirectory)
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let url = dir.appending(path: name)
        try Data(repeating: 0x41, count: megabytes * Self.oneMB).write(to: url)
        return url
    }

    /// 테스트에서 100MB 파일을 만들 수는 없으므로 임계를 낮춰 쓴다.
    private func scanner(_ home: URL, thresholdMB: Int = 3) -> LargeFileScanner {
        LargeFileScanner(minimumSize: Int64(thresholdMB * Self.oneMB), home: home)
    }

    // TC-1
    @Test("임계 이상 파일이 largeFile·caution으로 검출된다")
    func detectsLargeFile() async throws {
        let home = try makeFakeHome()
        defer { try? fm.removeItem(at: home) }
        try place("project.zip", megabytes: 5, in: home)

        let items = await scanner(home).scan()

        #expect(items.count == 1)
        #expect(items.first?.category == .largeFile)
        #expect(items.first?.safety == .caution)
        #expect(items.first?.isSelectedByDefault == false)
        #expect(items.first?.displayName == "project.zip")
    }

    // TC-2
    @Test("임계 미만 파일은 제외된다")
    func skipsSmallFiles() async throws {
        let home = try makeFakeHome()
        defer { try? fm.removeItem(at: home) }
        try place("small.txt", megabytes: 1, in: home)

        let items = await scanner(home).scan()
        #expect(items.isEmpty)
    }

    // TC-3
    @Test("큰 파일을 가리키는 심볼릭 링크는 후보가 아니다")
    func skipsSymlinks() async throws {
        let home = try makeFakeHome()
        defer { try? fm.removeItem(at: home) }

        let real = try place("real.bin", megabytes: 5, in: home, subdirectory: "keep")
        try fm.createSymbolicLink(at: home.appending(path: "Downloads/link.bin"),
                                  withDestinationURL: real)

        let items = await scanner(home).scan()

        #expect(items.map(\.displayName) == ["real.bin"])
        #expect(!items.contains { $0.displayName == "link.bin" })
    }

    // TC-4
    @Test("하위 디렉토리의 큰 파일도 검출된다")
    func findsFilesInSubdirectories() async throws {
        let home = try makeFakeHome()
        defer { try? fm.removeItem(at: home) }
        try place("nested.dmg", megabytes: 5, in: home, subdirectory: "old/archive")

        let items = await scanner(home).scan()
        #expect(items.map(\.displayName) == ["nested.dmg"])
    }

    // TC-5
    @Test("Downloads가 없는 홈에서도 던지지 않는다")
    func missingDownloadsIsEmpty() async throws {
        let home = URL(filePath: NSTemporaryDirectory())
            .appending(path: "sweep-large-none-\(UUID().uuidString)")
        try fm.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: home) }

        let items = await scanner(home).scan()
        #expect(items.isEmpty)
    }

    // TC-6 · TC-7
    @Test("받은 시점이 오늘·일·개월로 구분되어 표시된다")
    func detailDescribesAge() {
        let now = Date()
        func detail(daysAgo: Int) -> String {
            LargeFileScanner.detail(modified: now.addingTimeInterval(-Double(daysAgo) * 86_400),
                                    now: now)
        }

        #expect(detail(daysAgo: 0) == "오늘 받았습니다")
        #expect(detail(daysAgo: 10) == "10일 전에 받았습니다")
        #expect(detail(daysAgo: 29) == "29일 전에 받았습니다")
        // 30일이 경계 — 여기서 개월 표기로 넘어간다
        #expect(detail(daysAgo: 30) == "1개월 전에 받았습니다")
        #expect(detail(daysAgo: 100) == "3개월 전에 받았습니다")
    }

    // TC-11
    @Test("실제 홈 스캔이 Downloads 하위만 반환하고 관문을 통과한다")
    func realHomeScanIsScopedAndSafe() async {
        let downloads = fm.homeDirectoryForCurrentUser.appending(path: "Downloads")
        let items = await LargeFileScanner().scan()

        for item in items {
            #expect(item.category == .largeFile)
            #expect(item.url.isDescendant(of: downloads), "Downloads 밖: \(item.url.path)")
            #expect(ProtectedPaths.isRemovable(item.url), "관문 미통과: \(item.url.path)")
        }
    }
}
