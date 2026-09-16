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

    @Test("개발 폴더를 허락하면 그 루트만 켜진다")
    func sandboxedRootsIncludeGrantedDeveloper() {
        let home = Sandbox.userHome
        let downloads = fm.homeDirectoryForCurrentUser.appending(path: "Downloads")
        let developer = home.appending(path: "Library/Developer")
        #expect(ProtectedPaths.roots(sandboxed: true, granted: [developer]).map(\.path)
                == [downloads.path, developer.path])
    }

    @Test("~/Library를 허락하면 그 안의 정리 루트가 전부 켜진다")
    func grantingLibraryOpensItsRoots() {
        let home = Sandbox.userHome
        let paths = ProtectedPaths.roots(sandboxed: true,
                                         granted: [home.appending(path: "Library")]).map(\.path)

        for relative in ["Library/Developer", "Library/Caches", "Library/Logs"] {
            #expect(paths.contains(home.appending(path: relative).path), "\(relative)가 안 켜졌다")
        }
        // 고를 수 없는 경로라 샌드박스에서는 살릴 방법이 없다.
        #expect(!paths.contains("/private/tmp"))
    }

    @Test("허락이 넓어져도 루트 목록에 없는 곳은 열리지 않는다")
    func grantingLibraryDoesNotOpenUnlistedFolders() {
        let home = Sandbox.userHome
        let paths = ProtectedPaths.roots(sandboxed: true,
                                         granted: [home.appending(path: "Library")]).map(\.path)

        // ~/Library를 통째로 열어 줘도 지울 수 있는 것은 늘어나지 않는다 —
        // 허락은 "읽을 수 있는가"만, 루트 목록은 "지워도 되는가"만 정한다.
        for relative in ["Library/Safari", "Library/Mail", "Library/Messages",
                         "Library/Application Support"] {
            #expect(!paths.contains(home.appending(path: relative).path),
                    "\(relative)가 루트로 열렸다")
        }
    }

    @Test("앱 캐시는 Application Support가 허락 범위에 들어와야 열린다")
    func appCacheNeedsApplicationSupportGranted() {
        let home = Sandbox.userHome

        // 샌드박스 밖에서는 늘 볼 수 있다.
        #expect(ProtectedPaths.appSupportReadable(sandboxed: false, granted: []))

        // 샌드박스에서는 허락이 있어야 한다.
        #expect(!ProtectedPaths.appSupportReadable(sandboxed: true, granted: []))
        #expect(ProtectedPaths.appSupportReadable(
            sandboxed: true, granted: [home.appending(path: "Library")]))
        #expect(ProtectedPaths.appSupportReadable(
            sandboxed: true, granted: [home.appending(path: "Library/Application Support")]))

        // 엉뚱한 폴더를 열어 줘도 앱 캐시가 열리지는 않는다.
        #expect(!ProtectedPaths.appSupportReadable(
            sandboxed: true, granted: [home.appending(path: ".npm")]))
        #expect(!ProtectedPaths.appSupportReadable(
            sandboxed: true, granted: [home.appending(path: "Library/Developer")]))
    }

    @Test("홈 직속 도구 폴더도 허락하면 켜진다")
    func grantingHomeToolFolderOpensIt() {
        let home = Sandbox.userHome
        let npm = home.appending(path: ".npm")
        let paths = ProtectedPaths.roots(sandboxed: true, granted: [npm]).map(\.path)
        #expect(paths.contains(npm.path))
        #expect(!paths.contains(home.appending(path: "Library/Caches").path))
    }

    @Test("샌드박스 밖에서는 지금 허용 루트가 시작 때 루트와 같다")
    func currentRootsOutsideSandbox() {
        #expect(ProtectedPaths.currentRoots == ProtectedPaths.allowedRoots)
    }

    @Test("보호 목록은 진짜 홈의 Xcode UserData를 가리킨다")
    func denyListPointsAtUserHome() {
        let profiles = Sandbox.userHome
            .appending(path: "Library/Developer/Xcode/UserData/Provisioning Profiles")
        #expect(ProtectedPaths.denyList.map(\.path).contains(profiles.path))
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

    @Test("허락 전 샌드박스: 스마트 스캔은 큰 파일·중복만, 정크는 스캐너가 없다")
    func sandboxedScannersWithoutGrant() {
        let smart = Feature.smartScan.scanners(sandboxed: true, granted: []).map(\.category)
        #expect(smart == [.largeFile, .duplicate])
        #expect(Feature.junk.scanners(sandboxed: true, granted: []).isEmpty)
    }

    @Test("개발 폴더만 허락하면 Xcode만 붙는다")
    func sandboxedScannersWithDeveloperOnly() {
        let developer = Sandbox.userHome.appending(path: "Library/Developer")
        let smart = Feature.smartScan.scanners(sandboxed: true, granted: [developer])
            .map(\.category)
        #expect(smart == [.xcode, .largeFile, .duplicate])
        #expect(Feature.junk.scanners(sandboxed: true, granted: [developer]).map(\.category)
                == [.xcode])
    }

    @Test("~/Library를 허락하면 캐시 계열 스캐너가 전부 붙는다")
    func sandboxedScannersWithLibrary() {
        let library = Sandbox.userHome.appending(path: "Library")
        let junk = Feature.junk.scanners(sandboxed: true, granted: [library]).map(\.category)

        // 폭주 임시 파일은 고를 수 없는 경로라 샌드박스에서는 빠진다.
        #expect(junk == [.xcode, .devCache, .appCache, .staleCache])
    }

    @Test("홈 직속 도구 폴더만 허락하면 개발 캐시만 붙는다")
    func sandboxedScannersWithHomeToolOnly() {
        let npm = Sandbox.userHome.appending(path: ".npm")
        #expect(Feature.junk.scanners(sandboxed: true, granted: [npm]).map(\.category)
                == [.devCache])
    }

    @Test("샌드박스 밖 스캐너는 허락과 무관하게 그대로다")
    func unsandboxedScannersUnchanged() {
        #expect(Feature.smartScan.scanners(sandboxed: false, granted: []).count == 7)
        #expect(Feature.junk.scanners(sandboxed: false, granted: []).count == 5)
    }

    @Test("샌드박스의 디스크 맵 시작 지점은 허락 전 Downloads, 허락 후 개발 폴더까지")
    func sandboxedDiskMapRoots() {
        let home = URL(filePath: "/Users/someone")
        let before = DiskMapRoot.roots(home: home, sandboxed: true, exists: { _ in true })
        #expect(before.map(\.label) == ["~/Downloads"])

        let developer = Sandbox.userHome.appending(path: "Library/Developer")
        let after = DiskMapRoot.roots(home: Sandbox.userHome, sandboxed: true,
                                      granted: [developer], exists: { _ in true })
        #expect(after.map(\.label) == ["~/Downloads", "~/Library/Developer"])
    }

    // MARK: - 폴더 허락

    /// 진짜 홈과 `.standard`를 건드리지 않는 허락 저장소.
    ///
    /// 허락 자체의 동작은 `FolderAccessTests`가 본다. 여기서는 **앱 모델과의 연동**만
    /// 확인한다 — 허락이 화면 상태(`needsFolderAccess`)와 ⌘R로 이어지는지.
    private func makeAccess() throws
        -> (registry: FolderAccess.Registry, grantable: FolderAccess.Grantable,
            defaults: UserDefaults, cleanup: () -> Void) {
        let base = URL(filePath: NSTemporaryDirectory())
            .appending(path: "sweep-dev-\(UUID().uuidString)")
        let folder = base.appending(path: "Library/Developer")
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let suite = "sweep-test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let grantable = FolderAccess.Grantable(folder: folder, label: "~/Library/Developer",
                                               purpose: "테스트용")
        return (FolderAccess.Registry(defaults: defaults, legacy: grantable), grantable,
                defaults, {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: base)
        })
    }

    @Test("같은 폴더는 끝의 / 나 .. 가 섞여도 맞다고 본다")
    func matchesSameFolder() throws {
        let (_, grantable, _, cleanup) = try makeAccess()
        defer { cleanup() }
        let folder = grantable.folder

        #expect(FolderAccess.matches(folder, folder: folder))
        #expect(FolderAccess.matches(URL(filePath: folder.path + "/"), folder: folder))
        let dotted = folder.appending(path: "Xcode").appending(path: "..")
        #expect(FolderAccess.matches(dotted, folder: folder))
    }

    @Test("형제·하위·상위 폴더는 아니라고 본다")
    func rejectsOtherFolders() throws {
        let (_, grantable, _, cleanup) = try makeAccess()
        defer { cleanup() }
        let folder = grantable.folder
        let parent = folder.deletingLastPathComponent()

        #expect(!FolderAccess.matches(parent.appending(path: "Caches"), folder: folder))
        #expect(!FolderAccess.matches(folder.appending(path: "Xcode"), folder: folder))
        #expect(!FolderAccess.matches(parent, folder: folder))
    }

    @Test("앱 모델: 틀린 폴더면 허락 화면에 머물고, 맞으면 벗어난다")
    @MainActor
    func appModelGrantFlow() throws {
        let (registry, grantable, _, cleanup) = try makeAccess()
        defer { cleanup() }
        let app = AppModel(folderAccess: registry, needsFolderAccess: true)

        #expect(throws: FolderAccess.Failure.self) {
            try app.grantFolderAccess(grantable.folder.deletingLastPathComponent(),
                                      as: grantable)
        }
        #expect(app.needsFolderAccess)

        try app.grantFolderAccess(grantable.folder, as: grantable)
        #expect(!app.needsFolderAccess)
        #expect(registry.isGranted(grantable))
        #expect(app.isGranted(grantable))
    }

    @Test("허락 전 정크 탭에서는 검색할 모델이 없고, 허락하면 생긴다 (⌘R)")
    @MainActor
    func currentModelFollowsGrant() throws {
        let (registry, grantable, _, cleanup) = try makeAccess()
        defer { cleanup() }
        let app = AppModel(makeModel: { _ in ScanModel(scan: { AsyncStream { $0.finish() } }) },
                           folderAccess: registry, needsFolderAccess: true)
        app.selected = .junk

        #expect(app.currentModel == nil)
        #expect(!app.canScan)

        try app.grantFolderAccess(grantable.folder, as: grantable)
        #expect(app.currentModel != nil)
        #expect(app.canScan)
    }

    @Test("앱 모델 기본값: 샌드박스 밖에서는 허락이 필요 없다")
    @MainActor
    func appModelOutsideSandboxNeedsNothing() throws {
        let (registry, _, _, cleanup) = try makeAccess()
        defer { cleanup() }
        #expect(!AppModel(folderAccess: registry).needsFolderAccess)
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
