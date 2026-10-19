import Testing
import Foundation
@testable import SweepKit

@Suite("UserFolders")
struct UserFoldersTests {

    private let fm = FileManager.default

    /// 가짜 홈. 진짜 홈을 열거하면 기계마다 결과가 달라진다.
    private func makeHome(_ folders: [String]) throws -> (home: URL, cleanup: () -> Void) {
        let home = URL(filePath: NSTemporaryDirectory())
            .appending(path: "sweep-userfolders-\(UUID().uuidString)")
            .resolvingSymlinksInPath()
        for folder in folders {
            try fm.createDirectory(at: home.appending(path: folder), withIntermediateDirectories: true)
        }
        return (home, { try? FileManager.default.removeItem(at: home) })
    }

    private func names(_ urls: [URL]) -> Set<String> { Set(urls.map(\.lastPathComponent)) }

    // MARK: - roots

    @Test("홈 바로 아래 보이는 폴더가 루트가 된다")
    func visibleHomeFoldersAreRoots() throws {
        let (home, cleanup) = try makeHome(["Desktop", "Documents", "Code", "Downloads"])
        defer { cleanup() }

        let roots = UserFolders.roots(home: home, custom: [], sandboxed: false, granted: [])
        #expect(names(roots) == ["Desktop", "Documents", "Code", "Downloads"])
    }

    @Test("Library·Applications·숨김 폴더·링크·번들은 루트가 아니다")
    func excludedFoldersAreNotRoots() throws {
        let (home, cleanup) = try makeHome(["Downloads", "Library", "Applications", ".hidden", "Foo.app/Contents"])
        defer { cleanup() }
        let outside = try makeHome(["Elsewhere"])
        defer { outside.cleanup() }
        try fm.createSymbolicLink(at: home.appending(path: "Linked"),
                                  withDestinationURL: outside.home.appending(path: "Elsewhere"))

        let roots = UserFolders.roots(home: home, custom: [], sandboxed: false, granted: [])
        #expect(names(roots) == ["Downloads"])
    }

    @Test("샌드박스에서 아무것도 허락하지 않으면 Downloads만 남는다")
    func sandboxWithoutGrantKeepsDownloadsOnly() throws {
        let (home, cleanup) = try makeHome(["Desktop", "Documents", "Downloads"])
        defer { cleanup() }

        let roots = UserFolders.roots(home: home, custom: [], sandboxed: true, granted: [])
        #expect(names(roots) == ["Downloads"])
    }

    @Test("샌드박스에서는 허락받은 곳 안의 루트만 남는다")
    func sandboxKeepsGrantedRoots() throws {
        let (home, cleanup) = try makeHome(["Desktop", "Documents", "Downloads"])
        defer { cleanup() }
        let external = try makeHome(["사진"])
        defer { external.cleanup() }
        let photos = external.home.appending(path: "사진")

        let roots = UserFolders.roots(home: home, custom: [photos], sandboxed: true,
                                      granted: [home.appending(path: "Documents"), photos])
        #expect(names(roots) == ["Downloads", "Documents", "사진"])
    }

    @Test("다른 루트 안에 있는 추가 폴더는 한 번만 훑는다")
    func nestedCustomFolderIsDropped() throws {
        let (home, cleanup) = try makeHome(["Documents/프로젝트", "Downloads"])
        defer { cleanup() }

        let roots = UserFolders.roots(home: home, custom: [home.appending(path: "Documents/프로젝트")],
                                      sandboxed: false, granted: [])
        #expect(names(roots) == ["Downloads", "Documents"])
    }

    // MARK: - validateCustom

    @Test("디스크·홈·홈의 부모·Library 안·시스템 폴더는 추가할 수 없다")
    func wideAndSystemFoldersAreRejected() throws {
        let (home, cleanup) = try makeHome(["Library/X"])
        defer { cleanup() }

        func reject(_ url: URL) -> UserFolders.Rejection? {
            UserFolders.validateCustom(url, home: home, existing: [])
        }
        #expect(reject(URL(filePath: "/")) == .tooWide(URL(filePath: "/")))
        #expect(reject(home) == .tooWide(home.standardizedFileURL))
        #expect(reject(home.deletingLastPathComponent())
                == .tooWide(home.deletingLastPathComponent().standardizedFileURL))
        guard case .insideLibrary = reject(home.appending(path: "Library/X")) else {
            Issue.record("Library 안이 insideLibrary가 아니다"); return
        }
        guard case .systemFolder = reject(URL(filePath: "/System/Library")) else {
            Issue.record("/System/Library가 systemFolder가 아니다"); return
        }
        guard case .systemFolder = reject(URL(filePath: "/Volumes")) else {
            Issue.record("/Volumes 자체가 systemFolder가 아니다"); return
        }
    }

    @Test("이미 보는 폴더 안은 alreadyCovered이고, 외장 디스크 폴더는 추가할 수 있다")
    func coveredAndExternalFolders() throws {
        let (home, cleanup) = try makeHome(["Documents/안쪽"])
        defer { cleanup() }
        let documents = home.appending(path: "Documents")

        guard case .alreadyCovered = UserFolders.validateCustom(
            documents.appending(path: "안쪽"), home: home, existing: [documents]) else {
            Issue.record("이미 보는 곳 안이 alreadyCovered가 아니다"); return
        }
        #expect(UserFolders.validateCustom(URL(filePath: "/Volumes/외장/사진"),
                                           home: home, existing: [documents]) == nil)
    }

    // MARK: - Registry

    private func makeDefaults() throws -> (UserDefaults, () -> Void) {
        let suite = "sweep-test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        return (defaults, { defaults.removePersistentDomain(forName: suite) })
    }

    @Test("추가한 폴더는 저장되어 다음 실행에도 남고, 빼면 사라진다")
    func registryPersists() throws {
        let (home, cleanup) = try makeHome(["Code/외부"])
        defer { cleanup() }
        let (defaults, reset) = try makeDefaults()
        defer { reset() }
        let folder = home.appending(path: "Code/외부")

        try UserFolders.Registry(defaults: defaults).add(folder, home: home, existing: [])

        let reopened = UserFolders.Registry(defaults: defaults)
        #expect(reopened.custom.map(\.lastPathComponent) == ["외부"])

        reopened.remove(folder)
        #expect(UserFolders.Registry(defaults: defaults).custom.isEmpty)
    }

    @Test("같은 폴더를 두 번 추가하면 두 번째는 거부된다")
    func registryRejectsDuplicate() throws {
        let (home, cleanup) = try makeHome(["Code/외부"])
        defer { cleanup() }
        let (defaults, reset) = try makeDefaults()
        defer { reset() }
        let registry = UserFolders.Registry(defaults: defaults)
        let folder = home.appending(path: "Code/외부")

        try registry.add(folder, home: home, existing: [])
        #expect(throws: UserFolders.Rejection.self) {
            try registry.add(folder, home: home, existing: [])
        }
        #expect(registry.custom.count == 1)
    }
}
