import Testing
import Foundation
@testable import SweepKit

@Suite("FolderAccess")
struct FolderAccessTests {

    private let fm = FileManager.default

    /// 진짜 홈과 `.standard`를 건드리지 않는 허락 저장소를 만든다.
    ///
    /// 북마크는 흉내 내지 않고 실제 `bookmarkData(.withSecurityScope)`를 부른다 —
    /// 테스트 프로세스는 샌드박스 밖이라 그냥 성공한다.
    private func makeRegistry() throws
        -> (registry: FolderAccess.Registry, base: URL, defaults: UserDefaults,
            cleanup: () -> Void) {
        let base = URL(filePath: NSTemporaryDirectory())
            .appending(path: "sweep-folder-\(UUID().uuidString)")
        try fm.createDirectory(at: base, withIntermediateDirectories: true)
        let suite = "sweep-test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        return (FolderAccess.Registry(defaults: defaults), base, defaults, {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: base)
        })
    }

    private func makeGrantable(_ relative: String, in base: URL) throws -> FolderAccess.Grantable {
        let folder = base.appending(path: relative)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        return .init(folder: folder, label: "~/\(relative)", purpose: "테스트용")
    }

    // TC-1
    @Test("허락한 폴더가 열린 목록에 들어간다")
    func grantOpensFolder() throws {
        let (registry, base, defaults, cleanup) = try makeRegistry()
        defer { cleanup() }
        let library = try makeGrantable("Library", in: base)

        try registry.grant(library.folder, as: library)

        #expect(registry.urls.count == 1)
        #expect(registry.urls.first?.path == library.folder.resolvingSymlinksInPath().path)
        #expect(registry.isGranted(library))
        #expect(registry.hasAny)
        #expect(defaults.data(forKey: library.key) != nil)
    }

    // TC-2
    @Test("형제 폴더를 고르면 거부하고 아무것도 저장하지 않는다")
    func rejectsSiblingFolder() throws {
        let (registry, base, defaults, cleanup) = try makeRegistry()
        defer { cleanup() }
        let library = try makeGrantable("Library", in: base)
        let wrong = try makeGrantable("Documents", in: base).folder

        #expect(throws: FolderAccess.Failure.wrongFolder(expected: library.label, picked: wrong)) {
            try registry.grant(wrong, as: library)
        }
        #expect(registry.urls.isEmpty)
        #expect(defaults.data(forKey: library.key) == nil)
    }

    // TC-3
    @Test("하위 폴더를 고르면 거부한다")
    func rejectsChildFolder() throws {
        let (registry, base, defaults, cleanup) = try makeRegistry()
        defer { cleanup() }
        let library = try makeGrantable("Library", in: base)
        // 하위를 받으면 나머지가 막힌다 — 정확히 같은 폴더만 수락한다.
        let child = try makeGrantable("Library/Caches", in: base).folder

        #expect(throws: FolderAccess.Failure.self) {
            try registry.grant(child, as: library)
        }
        #expect(registry.urls.isEmpty)
        #expect(defaults.data(forKey: library.key) == nil)
    }

    // TC-4
    @Test("여러 폴더를 각각 허락할 수 있다")
    func grantsMultipleFolders() throws {
        let (registry, base, _, cleanup) = try makeRegistry()
        defer { cleanup() }
        let library = try makeGrantable("Library", in: base)
        let npm = try makeGrantable(".npm", in: base)

        try registry.grant(library.folder, as: library)
        try registry.grant(npm.folder, as: npm)

        #expect(registry.urls.count == 2)
        #expect(registry.isGranted(library))
        #expect(registry.isGranted(npm))
    }

    // TC-5
    @Test("같은 폴더를 두 번 허락해도 목록이 불어나지 않는다")
    func grantIsIdempotent() throws {
        let (registry, base, _, cleanup) = try makeRegistry()
        defer { cleanup() }
        let library = try makeGrantable("Library", in: base)

        try registry.grant(library.folder, as: library)
        try registry.grant(library.folder, as: library)

        #expect(registry.urls.count == 1)
    }

    // TC-6
    @Test("상위 폴더를 허락하면 그 안의 폴더도 열린 것으로 본다")
    func parentGrantCoversChild() throws {
        let (registry, base, _, cleanup) = try makeRegistry()
        defer { cleanup() }
        let library = try makeGrantable("Library", in: base)
        let developer = try makeGrantable("Library/Developer", in: base)

        try registry.grant(library.folder, as: library)

        // ~/Library 하나로 그 아래가 전부 열린다 — 허락을 한 번만 받는 근거다.
        #expect(registry.isGranted(developer))
    }

    // TC-7
    @Test("다시 열어도 저장된 허락이 복원된다")
    func restoreReopensFolders() throws {
        let (registry, base, defaults, cleanup) = try makeRegistry()
        defer { cleanup() }
        let library = try makeGrantable("Library", in: base)
        try registry.grant(library.folder, as: library)

        // 다음 실행을 흉내 낸다 — 같은 저장소를 보는 새 인스턴스.
        let next = FolderAccess.Registry(defaults: defaults)
        #expect(next.urls.isEmpty)

        next.restore(library)
        #expect(next.urls.count == 1)
        #expect(next.isGranted(library))
    }

    // TC-9
    @Test("이전 버전의 북마크가 새 키로 옮겨져 그대로 열린다")
    func migratesLegacyBookmark() throws {
        let (registry, base, defaults, cleanup) = try makeRegistry()
        defer { cleanup() }

        // 빌드 3까지 쓰던 키 하나. 가리키는 곳은 늘 ~/Library/Developer였다.
        // 진짜 홈에 폴더를 만들지 않도록 임시 트리로 대신한다.
        let developer = try makeGrantable("Library/Developer", in: base)
        let data = try developer.folder.bookmarkData(options: .withSecurityScope,
                                                     includingResourceValuesForKeys: nil,
                                                     relativeTo: nil)
        defaults.set(data, forKey: "developerFolderBookmark")
        _ = registry   // 저장만 해 두고 새 인스턴스로 다음 실행을 흉내 낸다

        let next = FolderAccess.Registry(defaults: defaults, legacy: developer)
        next.restoreAll()

        // 이미 허락한 사용자가 허락 화면을 다시 보면 안 된다.
        #expect(next.hasAny)
        #expect(next.isGranted(developer))
        #expect(defaults.data(forKey: "developerFolderBookmark") == nil, "옛 키가 남았다")
        #expect(defaults.data(forKey: developer.key) != nil, "새 키로 옮겨지지 않았다")
    }

    // TC-10
    @Test("이전 북마크가 없으면 마이그레이션이 아무 일도 하지 않는다")
    func migrationIsNoopWithoutLegacyKey() throws {
        let (_, base, defaults, cleanup) = try makeRegistry()
        defer { cleanup() }
        let developer = try makeGrantable("Library/Developer", in: base)

        let registry = FolderAccess.Registry(defaults: defaults, legacy: developer)
        registry.restoreAll()

        #expect(!registry.hasAny)
        #expect(defaults.data(forKey: developer.key) == nil)
    }

    // TC-8
    @Test("깨진 북마크는 복원에 실패하고 지워진다")
    func restoreDropsBrokenBookmark() throws {
        let (_, base, defaults, cleanup) = try makeRegistry()
        defer { cleanup() }
        let library = try makeGrantable("Library", in: base)
        defaults.set(Data([0x00, 0x01, 0x02]), forKey: library.key)

        let registry = FolderAccess.Registry(defaults: defaults)
        registry.restore(library)

        // 남겨 두면 매 실행 같은 실패를 되풀이하고 허락 화면도 다시 못 본다.
        #expect(registry.urls.isEmpty)
        #expect(defaults.data(forKey: library.key) == nil)
    }
}
