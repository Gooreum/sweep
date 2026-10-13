import Testing
import Foundation
@testable import SweepKit

/// 실제 휴지통을 쓰지 않는다. 허용 루트(`/private/tmp`) 아래에 "휴지통 위치"를 따로 두고
/// 거기서 원래 자리로 옮기는지 본다 — 테스트가 사용자의 휴지통을 건드리면 안 된다.
@Suite("Restorer")
struct RestorerTests {

    private var fm: FileManager { .default }

    /// 원래 자리 폴더와 가짜 휴지통 폴더. 파일은 이미 휴지통 쪽에 있다.
    private func trashedFile(_ content: String = "되돌릴 내용") throws
        -> (original: URL, trashed: URL, cleanup: () -> Void) {
        let base = URL(filePath: "/private/tmp").appending(path: "sweep-restore-\(UUID().uuidString)")
        let home = base.appending(path: "home")
        let trash = base.appending(path: "trash")
        try fm.createDirectory(at: home, withIntermediateDirectories: true)
        try fm.createDirectory(at: trash, withIntermediateDirectories: true)
        let trashed = trash.appending(path: "cache.bin")
        try content.write(to: trashed, atomically: true, encoding: .utf8)
        return (home.appending(path: "cache.bin"), trashed, { try? self.fm.removeItem(at: base) })
    }

    private func outcome(_ original: URL, _ trashed: URL?) -> RemovalOutcome {
        RemovalOutcome(item: CleanupItem(url: original, size: 10, category: .devCache, safety: .safe),
                       failure: nil, trashedURL: trashed)
    }

    @Test("휴지통 위치에서 원래 자리로 옮긴다")
    func restoresToOriginalPlace() throws {
        let (original, trashed, cleanup) = try trashedFile()
        defer { cleanup() }

        let result = Restorer().restoreOne(outcome(original, trashed))

        #expect(result.succeeded)
        #expect(try String(contentsOf: original, encoding: .utf8) == "되돌릴 내용")
        #expect(!fm.fileExists(atPath: trashed.path))
    }

    @Test("원래 자리가 차 있으면 덮어쓰지 않는다")
    func refusesOccupiedDestination() throws {
        let (original, trashed, cleanup) = try trashedFile()
        defer { cleanup() }
        try "새로 생긴 파일".write(to: original, atomically: true, encoding: .utf8)

        let result = Restorer().restoreOne(outcome(original, trashed))

        #expect(result.failure?.kind == .destinationOccupied)
        #expect(try String(contentsOf: original, encoding: .utf8) == "새로 생긴 파일")
        #expect(fm.fileExists(atPath: trashed.path))
        // 실패 시트가 휴지통 안의 항목을 가리킬 수 있게 위치를 남긴다.
        #expect(result.trashedURL == trashed)
    }

    @Test("원래 폴더가 사라졌으면 다시 만들지 않는다")
    func refusesMissingParent() throws {
        let (original, trashed, cleanup) = try trashedFile()
        defer { cleanup() }
        try fm.removeItem(at: original.deletingLastPathComponent())

        let result = Restorer().restoreOne(outcome(original, trashed))

        #expect(result.failure?.kind == .destinationOccupied)
        #expect(result.failureReason == "원래 폴더가 사라졌습니다")
        #expect(!fm.fileExists(atPath: original.deletingLastPathComponent().path))
    }

    @Test("휴지통에서 사라졌으면 되돌릴 수 없다")
    func reportsMissingFromTrash() throws {
        let (original, trashed, cleanup) = try trashedFile()
        defer { cleanup() }
        try fm.removeItem(at: trashed)

        #expect(Restorer().restoreOne(outcome(original, trashed)).failure?.kind == .missingFromTrash)
        #expect(Restorer().restoreOne(outcome(original, nil)).failure?.kind == .missingFromTrash)
    }

    @Test("허용 범위 밖으로는 되돌리지 않는다")
    func gateBlocksOutsideAllowedRoots() throws {
        let (_, trashed, cleanup) = try trashedFile()
        defer { cleanup() }
        let outside = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Documents").appending(path: "sweep-restore-\(UUID().uuidString)")
        try fm.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: outside) }
        let target = outside.appending(path: "cache.bin")

        let result = Restorer().restoreOne(outcome(target, trashed))

        #expect(result.failure?.kind == .protected)
        #expect(!fm.fileExists(atPath: target.path))
        #expect(fm.fileExists(atPath: trashed.path))
    }
}
