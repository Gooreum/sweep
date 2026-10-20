import Testing
import Foundation
@testable import SweepKit

/// 스마트 스캔에 폴더를 더하고 빼는 흐름과 "보는 곳" 목록.
@Suite("ScanFolder")
struct ScanFolderTests {

    private func makeDefaults() throws -> (UserDefaults, () -> Void) {
        let suite = "sweep-test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        return (defaults, { defaults.removePersistentDomain(forName: suite) })
    }

    // MARK: - CleanupScope

    @Test("홈 사용자 폴더는 한 줄로 묶이고, 추가한 폴더는 따로 빼기 표시가 붙는다")
    func homeFoldersAreGroupedAndCustomIsMarked() {
        let home = Sandbox.userHome
        let desktop = home.appending(path: "Desktop")
        let documents = home.appending(path: "Documents")
        let external = URL(filePath: "/Volumes/외장/사진")

        let scopes = CleanupScope.scopes(roots: [home.appending(path: "Downloads"), desktop, documents, external],
                                         userRoots: [home.appending(path: "Downloads"), desktop, documents, external],
                                         custom: [external])

        #expect(scopes.map(\.label) == ["~/Downloads", "~ 내 폴더", "/Volumes/외장/사진"])
        #expect(scopes[1].detail == "Desktop, Documents에서 큰 파일과 중복 파일을 찾아요")
        #expect(scopes.map(\.isCustom) == [false, false, true])
    }

    @Test("홈 폴더가 많으면 둘만 이름을 쓰고 나머지는 개수로 말한다")
    func manyHomeFoldersAreCounted() {
        #expect(CleanupScope.homeFoldersDetail(["A", "B", "C"]) == "A, B, C에서 큰 파일과 중복 파일을 찾아요")
        #expect(CleanupScope.homeFoldersDetail(["A", "B", "C", "D", "E"]) == "A, B 외 3곳에서 큰 파일과 중복 파일을 찾아요")
    }

    @Test("사용자 폴더가 없으면 묶음 줄도 없다")
    func noGroupWithoutUserFolders() {
        let downloads = Sandbox.userHome.appending(path: "Downloads")
        let scopes = CleanupScope.scopes(roots: [downloads], userRoots: [downloads], custom: [])
        #expect(scopes.map(\.label) == ["~/Downloads"])
    }

    // MARK: - AppModel

    @Test("폴더를 더하면 저장되고 개수가 늘며, 빼면 돌아온다")
    @MainActor
    func addAndRemoveOutsideSandbox() throws {
        let (defaults, reset) = try makeDefaults()
        defer { reset() }
        let registry = UserFolders.Registry(defaults: defaults)
        let app = AppModel(userFolders: registry, needsFolderAccess: false)
        let external = URL(filePath: "/Volumes/sweep-test-외장/사진")

        try app.addScanFolder(external)
        #expect(app.scanFolderCount == 1)
        #expect(registry.custom.map(\.path) == [external.path])

        app.removeScanFolder(external)
        #expect(app.scanFolderCount == 0)
        #expect(registry.custom.isEmpty)
    }

    @Test("이미 보는 폴더를 더하면 이유를 던지고 목록은 그대로다")
    @MainActor
    func addingCoveredFolderThrows() throws {
        let (defaults, reset) = try makeDefaults()
        defer { reset() }
        let registry = UserFolders.Registry(defaults: defaults)
        let app = AppModel(userFolders: registry, needsFolderAccess: false)

        #expect(throws: UserFolders.Rejection.self) {
            try app.addScanFolder(Sandbox.userHome.appending(path: "Downloads/안쪽"))
        }
        #expect(app.scanFolderCount == 0)
    }

    @Test("샌드박스에서 북마크를 저장하지 못하면 목록에서도 빠진다")
    @MainActor
    func sandboxRollsBackWhenBookmarkFails() throws {
        let (defaults, reset) = try makeDefaults()
        defer { reset() }
        let (accessDefaults, resetAccess) = try makeDefaults()
        defer { resetAccess() }
        let registry = UserFolders.Registry(defaults: defaults)
        let access = FolderAccess.Registry(defaults: accessDefaults)
        let app = AppModel(folderAccess: access, userFolders: registry, needsFolderAccess: true)

        // 없는 폴더는 북마크를 만들 수 없다
        let missing = URL(filePath: "/Volumes/sweep-없는-디스크-\(UUID().uuidString)")
        #expect(throws: UserFolders.Rejection.self) { try app.addScanFolder(missing) }
        #expect(registry.custom.isEmpty)
        #expect(app.scanFolderCount == 0)
    }

    @Test("샌드박스에서 더한 폴더는 열리고, 빼면 닫힌다")
    @MainActor
    func sandboxGrantsAndRevokes() throws {
        let (defaults, reset) = try makeDefaults()
        defer { reset() }
        let (accessDefaults, resetAccess) = try makeDefaults()
        defer { resetAccess() }
        let registry = UserFolders.Registry(defaults: defaults)
        let access = FolderAccess.Registry(defaults: accessDefaults)
        let app = AppModel(folderAccess: access, userFolders: registry, needsFolderAccess: true)
        // 홈을 허락하지 않은 샌드박스에서는 Documents가 보는 곳이 아니라 더할 수 있다
        let documents = Sandbox.userHome.appending(path: "Documents")

        try app.addScanFolder(documents)
        #expect(access.isGranted(UserFolders.grantable(for: documents)))
        #expect(!app.needsFolderAccess)

        app.removeScanFolder(documents)
        #expect(!access.isGranted(UserFolders.grantable(for: documents)))
        #expect(app.needsFolderAccess)
    }
}
