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
    @Test("실제 홈 스캔이 사용자 폴더 하위만 반환하고 관문을 통과한다")
    func realHomeScanIsScopedAndSafe() async {
        let roots = UserFolders.roots()
        let items = await LargeFileScanner().scan()

        for item in items {
            #expect(item.category == .largeFile)
            #expect(roots.contains { item.url.isDescendant(of: $0) }, "사용자 폴더 밖: \(item.url.path)")
            #expect(ProtectedPaths.isRemovable(item.url, scope: item.category.removalScope),
                    "관문 미통과: \(item.url.path)")
            #expect(!item.url.path.contains("/Library/"), "Library 안: \(item.url.path)")
        }
    }

    // MARK: - 사용자 폴더 전체

    /// 홈 기준 상대 경로에 파일을 만든다.
    @discardableResult
    private func put(_ relative: String, megabytes: Int, in home: URL) throws -> URL {
        let url = home.appending(path: relative)
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 0x41, count: megabytes * Self.oneMB).write(to: url)
        return url
    }

    @Test("Downloads 밖의 사용자 폴더에서도 찾고, 받은 파일이 아니면 수정 시점을 말한다")
    func findsFilesOutsideDownloads() async throws {
        let home = try makeFakeHome()
        defer { try? fm.removeItem(at: home) }
        try put("Desktop/영상.mov", megabytes: 5, in: home)
        try put("Code/앱/에셋.psd", megabytes: 5, in: home)

        let items = await scanner(home).scan()

        #expect(Set(items.map(\.displayName)) == ["영상.mov", "에셋.psd"])
        #expect(items.allSatisfy { $0.detail.hasSuffix("수정했습니다") })
    }

    @Test("Library·의존성 폴더·번들 안·숨김 폴더는 훑지 않는다")
    func skipsLibraryDependenciesAndBundles() async throws {
        let home = try makeFakeHome()
        defer { try? fm.removeItem(at: home) }
        try put("Library/Caches/큰캐시.bin", megabytes: 5, in: home)
        try put("Code/웹/node_modules/esbuild/bin", megabytes: 5, in: home)
        try put("Code/앱/Pods/Big/lib.a", megabytes: 5, in: home)
        try put("Pictures/사진 보관함.photoslibrary/originals/IMG.heic", megabytes: 5, in: home)
        try put("Applications/Tool.app/Contents/MacOS/Tool", megabytes: 5, in: home)
        try put("Code/.git/objects/pack.pack", megabytes: 5, in: home)
        try put("Code/남길것.zip", megabytes: 5, in: home)

        let items = await scanner(home).scan()
        #expect(items.map(\.displayName) == ["남길것.zip"])
    }

    @Test("iCloud에만 있는 파일은 후보가 아니다")
    func skipsDatalessFiles() async throws {
        let home = try makeFakeHome()
        defer { try? fm.removeItem(at: home) }
        try put("Documents/클라우드.mov", megabytes: 5, in: home)
        try put("Documents/로컬.mov", megabytes: 5, in: home)

        let items = await LargeFileScanner(minimumSize: Int64(3 * Self.oneMB), home: home, roots: nil,
                                           isDataless: { $0.lastPathComponent == "클라우드.mov" }).scan()
        #expect(items.map(\.displayName) == ["로컬.mov"])
    }

    @Test("루트마다 진행률을 알리고 마지막은 1이다")
    func reportsProgressPerRoot() async throws {
        let home = try makeFakeHome()
        defer { try? fm.removeItem(at: home) }
        for folder in ["Desktop", "Documents", "Movies"] {
            try fm.createDirectory(at: home.appending(path: folder), withIntermediateDirectories: true)
        }
        let reports = Reports()

        _ = await scanner(home).scan(onProgress: { reports.append($0) })

        let values = reports.values
        #expect(values.count == 4)   // Downloads + 셋
        #expect(values == values.sorted())
        #expect(values.last == 1)
    }

    @Test("받은 시점과 수정 시점 문구가 나뉜다")
    func detailDistinguishesDownloaded() {
        let now = Date()
        let tenDays = now.addingTimeInterval(-10 * 86_400)
        #expect(LargeFileScanner.detail(modified: tenDays, downloaded: true, now: now) == "10일 전에 받았습니다")
        #expect(LargeFileScanner.detail(modified: tenDays, downloaded: false, now: now) == "10일 전에 수정했습니다")
        #expect(LargeFileScanner.detail(modified: now, downloaded: false, now: now) == "오늘 수정했습니다")
        #expect(LargeFileScanner.detail(modified: now.addingTimeInterval(-100 * 86_400),
                                        downloaded: false, now: now) == "3개월 전에 수정했습니다")
    }
}

/// 진행률 콜백이 `@Sendable`이라 값을 모을 상자가 필요하다.
private final class Reports: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [Double] = []
    func append(_ value: Double) { lock.lock(); stored.append(value); lock.unlock() }
    var values: [Double] { lock.lock(); defer { lock.unlock() }; return stored }
}
