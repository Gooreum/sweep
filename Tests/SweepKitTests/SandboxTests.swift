import Testing
import Foundation
@testable import SweepKit

/// App Store 빌드(App Sandbox)에서 달라지는 것들.
///
/// 테스트 프로세스는 샌드박스 밖이라 `Sandbox.isActive`가 늘 false다.
/// 샌드박스 쪽 분기는 `sandboxed:` 주입으로 확인한다.
@Suite("Sandbox")
struct SandboxTests {

    private var fm: FileManager { .default }

    /// 샌드박스 컨테이너를 흉내 낸다 — 홈 안의 `Downloads`가 진짜 폴더를 가리키는 링크다.
    private func makeLinkedHome() throws -> (home: URL, target: URL) {
        let base = URL(filePath: NSTemporaryDirectory())
            .appending(path: "sweep-sandbox-\(UUID().uuidString)")
        let home = base.appending(path: "Data")
        let target = base.appending(path: "RealDownloads")
        try fm.createDirectory(at: home, withIntermediateDirectories: true)
        try fm.createDirectory(at: target, withIntermediateDirectories: true)
        try fm.createSymbolicLink(at: home.appending(path: "Downloads"),
                                  withDestinationURL: target)
        return (home, target)
    }

    // MARK: - 판정과 범위

    @Test("테스트 프로세스는 샌드박스 밖이다")
    func testProcessIsNotSandboxed() {
        #expect(Sandbox.isActive == false)
    }

    @Test("샌드박스 밖에서 진짜 홈은 홈 디렉토리와 같다")
    func userHomeMatchesHomeOutsideSandbox() {
        #expect(Sandbox.userHome.standardizedFileURL.path
                == fm.homeDirectoryForCurrentUser.standardizedFileURL.path)
    }

    @Test("샌드박스면 허용 루트는 ~/Downloads 하나다")
    func sandboxedRootsAreDownloadsOnly() {
        let downloads = fm.homeDirectoryForCurrentUser.appending(path: "Downloads")
        #expect(ProtectedPaths.roots(sandboxed: true).map(\.path) == [downloads.path])
    }

    @Test("샌드박스 밖의 허용 루트는 그대로다")
    func unsandboxedRootsAreUnchanged() {
        #expect(ProtectedPaths.roots(sandboxed: false) == ProtectedPaths.allowedRoots)
        #expect(ProtectedPaths.allowedRoots.count > 1)
    }

    @Test("샌드박스의 'Sweep이 보는 곳'은 ~/Downloads 한 줄이다")
    func sandboxedScopeIsSingleLine() {
        let scopes = CleanupScope.scopes(roots: ProtectedPaths.roots(sandboxed: true))
        #expect(scopes.map(\.label) == ["~/Downloads"])
        #expect(scopes.first?.detail.isEmpty == false)
    }

    @Test("샌드박스에서는 정크 파일 기능이 빠진다")
    func sandboxedFeaturesDropJunk() {
        let available = Feature.available(sandboxed: true)
        #expect(!available.contains(.junk))
        #expect(available == [.smartScan, .largeFile, .duplicate, .diskMap])
        #expect(Feature.available(sandboxed: false) == Feature.allCases)
    }

    @Test("샌드박스의 스마트 스캔은 큰 파일·중복 파일만 훑는다")
    func sandboxedSmartScanScanners() {
        let categories = Feature.smartScan.scanners(sandboxed: true).map(\.category)
        #expect(categories == [.largeFile, .duplicate])
        #expect(Feature.smartScan.scanners(sandboxed: false).count == 6)
    }

    @Test("샌드박스의 디스크 맵 시작 지점은 ~/Downloads 하나다")
    func sandboxedDiskMapRoots() {
        let home = URL(filePath: "/Users/someone/Library/Containers/app/Data")
        let roots = DiskMapRoot.roots(home: home, sandboxed: true, exists: { _ in true })
        #expect(roots.map(\.label) == ["~/Downloads"])
    }

    // MARK: - 개발 폴더 허락

    /// 진짜 홈과 `.standard`를 건드리지 않는 허락 저장소.
    private func makeAccess() throws -> (access: DeveloperAccess, folder: URL,
                                         defaults: UserDefaults, cleanup: () -> Void) {
        let base = URL(filePath: NSTemporaryDirectory())
            .appending(path: "sweep-dev-\(UUID().uuidString)")
        let folder = base.appending(path: "Library/Developer")
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let suite = "sweep-test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let access = DeveloperAccess(folder: folder, defaults: defaults)
        return (access, folder, defaults, {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: base)
        })
    }

    @Test("같은 폴더는 끝의 / 나 .. 가 섞여도 맞다고 본다")
    func matchesSameFolder() throws {
        let (_, folder, _, cleanup) = try makeAccess()
        defer { cleanup() }

        #expect(DeveloperAccess.matches(folder, folder: folder))
        #expect(DeveloperAccess.matches(URL(filePath: folder.path + "/"), folder: folder))
        let dotted = folder.appending(path: "Xcode").appending(path: "..")
        #expect(DeveloperAccess.matches(dotted, folder: folder))
    }

    @Test("형제·하위·상위 폴더는 아니라고 본다")
    func rejectsOtherFolders() throws {
        let (_, folder, _, cleanup) = try makeAccess()
        defer { cleanup() }

        let parent = folder.deletingLastPathComponent()
        #expect(!DeveloperAccess.matches(parent.appending(path: "Caches"), folder: folder))
        #expect(!DeveloperAccess.matches(folder.appending(path: "Xcode"), folder: folder))
        #expect(!DeveloperAccess.matches(parent, folder: folder))
    }

    @Test("다른 폴더를 고르면 거절하고 아무것도 저장하지 않는다")
    func grantRejectsWrongFolder() throws {
        let (access, folder, defaults, cleanup) = try makeAccess()
        defer { cleanup() }
        let wrong = folder.deletingLastPathComponent()

        #expect(throws: DeveloperAccess.Failure.wrongFolder(wrong)) { try access.grant(wrong) }
        #expect(access.url == nil)
        #expect(defaults.dictionaryRepresentation()["developerFolderBookmark"] == nil)
    }

    @Test("맞는 폴더를 고르면 열리고 북마크가 저장된다")
    func grantOpensFolder() throws {
        let (access, folder, defaults, cleanup) = try makeAccess()
        defer { cleanup() }

        try access.grant(folder)

        #expect(access.url?.path == folder.resolvingSymlinksInPath().path)
        #expect(defaults.data(forKey: "developerFolderBookmark") != nil)
    }

    @Test("다음 실행에서 저장한 북마크로 다시 연다")
    func restoreReopensFolder() throws {
        let (access, folder, defaults, cleanup) = try makeAccess()
        defer { cleanup() }
        try access.grant(folder)

        let nextLaunch = DeveloperAccess(folder: folder, defaults: defaults)
        #expect(nextLaunch.url == nil)
        nextLaunch.restore()

        #expect(nextLaunch.url?.path == folder.resolvingSymlinksInPath().path)
    }

    @Test("망가진 북마크는 지우고 닫힌 채로 둔다")
    func restoreDropsBrokenBookmark() throws {
        let (access, _, defaults, cleanup) = try makeAccess()
        defer { cleanup() }
        defaults.set(Data([0x00, 0x01, 0x02]), forKey: "developerFolderBookmark")

        access.restore()

        #expect(access.url == nil)
        #expect(defaults.data(forKey: "developerFolderBookmark") == nil)
    }

    // MARK: - Downloads 링크

    @Test("Downloads가 링크면 가리키는 폴더를 준다")
    func resolvesLinkedDownloads() throws {
        let (home, target) = try makeLinkedHome()
        defer { try? fm.removeItem(at: home.deletingLastPathComponent()) }

        #expect(DownloadsFolder.url(in: home).standardizedFileURL
                == target.resolvingSymlinksInPath().standardizedFileURL)
    }

    @Test("Downloads가 일반 폴더면 경로를 그대로 둔다")
    func keepsPlainDownloads() throws {
        let home = URL(filePath: NSTemporaryDirectory())
            .appending(path: "sweep-sandbox-\(UUID().uuidString)")
        try fm.createDirectory(at: home.appending(path: "Downloads"),
                               withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: home) }

        // 링크를 풀면 `/var/folders` → `/private/var/folders`로 바뀐다. 그러면 안 된다.
        #expect(DownloadsFolder.url(in: home).path == home.appending(path: "Downloads").path)
    }

    @Test("링크 Downloads 안의 큰 파일을 찾는다")
    func largeFileScannerFollowsLinkedDownloads() async throws {
        let (home, target) = try makeLinkedHome()
        defer { try? fm.removeItem(at: home.deletingLastPathComponent()) }
        try Data(repeating: 0x41, count: 2 * 1024 * 1024)
            .write(to: target.appending(path: "installer.dmg"))

        let items = await LargeFileScanner(minimumSize: 1024 * 1024, home: home).scan()

        #expect(items.map(\.displayName) == ["installer.dmg"])
    }

    @Test("링크 Downloads 안의 중복 파일을 찾는다")
    func duplicateScannerFollowsLinkedDownloads() async throws {
        let (home, target) = try makeLinkedHome()
        defer { try? fm.removeItem(at: home.deletingLastPathComponent()) }
        let bytes = Data(repeating: 0x42, count: 2 * 1024 * 1024)
        try bytes.write(to: target.appending(path: "report.pdf"))
        try bytes.write(to: target.appending(path: "report (1).pdf"))

        let items = await DuplicateScanner(minimumSize: 1024 * 1024, home: home).scan()

        #expect(items.count == 1)
    }
}
