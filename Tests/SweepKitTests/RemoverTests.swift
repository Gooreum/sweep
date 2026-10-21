import Testing
import Foundation
@testable import SweepKit

@Suite("Remover")
struct RemoverTests {

    private var home: URL { FileManager.default.homeDirectoryForCurrentUser }
    private var fm: FileManager { .default }

    /// `/private/tmp` 아래 — 허용 루트 하위이므로 관문을 통과한다.
    private func makeAllowedFile() throws -> URL {
        let dir = URL(filePath: "/private/tmp")
            .appending(path: "sweep-remove-\(UUID().uuidString)")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appending(path: "target.bin")
        try Data(repeating: 0x41, count: 4096).write(to: file)
        return file
    }

    /// `~/Documents` 아래 — 어느 허용 루트에도 속하지 않는다.
    private func makeForbiddenFile() throws -> URL {
        let dir = home.appending(path: "Documents")
            .appending(path: "sweep-forbidden-\(UUID().uuidString)")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appending(path: "소중한파일.txt")
        try "지워지면 안 된다".write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    private func item(_ url: URL, size: Int64 = 4096) -> CleanupItem {
        CleanupItem(url: url, size: size, category: .devCache, safety: .safe)
    }

    // TC-1
    @Test("허용 루트 안의 파일은 실제로 삭제된다")
    func removesAllowedFile() throws {
        let file = try makeAllowedFile()
        defer { try? fm.removeItem(at: file.deletingLastPathComponent()) }

        let outcome = Remover(movesToTrash: false).removeOne(item(file))

        #expect(outcome.succeeded)
        #expect(outcome.failureReason == nil)
        #expect(!fm.fileExists(atPath: file.path))
    }

    // TC-2 · TC-3
    @Test("허용 루트 밖 파일은 실패로 기록되고 디스크에 그대로 남는다")
    func blocksForbiddenFileAndLeavesItIntact() throws {
        let file = try makeForbiddenFile()
        defer { try? fm.removeItem(at: file.deletingLastPathComponent()) }

        let outcome = Remover(movesToTrash: false).removeOne(item(file))

        #expect(!outcome.succeeded)
        #expect(outcome.failureReason == RemovalVeto.outsideAllowedRoots(ProtectedPaths.canonical(file)).message)
        // 이 앱의 핵심 불변식 — 관문이 막았으면 파일은 살아 있어야 한다
        #expect(fm.fileExists(atPath: file.path), "관문이 막았는데 파일이 사라졌다")
    }

    // TC-4
    @Test("홈 디렉토리 자체는 관문에서 거부된다")
    func refusesToRemoveHome() {
        // **`Remover`에 홈을 넘기지 않는다.** `movesToTrash: false`라
        // 관문이 한 줄이라도 깨진 순간 홈 전체가 복구 불가능하게 지워진다.
        // 관문을 지키는 테스트는 관문이 깨져도 안전해야 한다.
        //
        // `Remover`가 이 관문을 실제로 지난다는 사실은 TC-2가
        // 버려도 되는 임시 파일로 이미 증명한다.
        do {
            try ProtectedPaths.validate(home)
            Issue.record("홈이 관문을 통과했다")
        } catch let veto as RemovalVeto {
            #expect(veto == .rootOrHome(ProtectedPaths.canonical(home)))
        } catch {
            Issue.record("예상 밖 오류: \(error)")
        }
        #expect(fm.fileExists(atPath: home.path))
    }

    // MARK: - 실패 종류 (pm #2)

    @Test("관문이 막은 실패는 protected 종류로 기록된다")
    func vetoIsProtectedKind() throws {
        let file = try makeForbiddenFile()
        defer { try? fm.removeItem(at: file.deletingLastPathComponent()) }

        let outcome = Remover(movesToTrash: false).removeOne(item(file))

        #expect(outcome.failure?.kind == .protected)
        #expect(outcome.failureReason == RemovalVeto.outsideAllowedRoots(ProtectedPaths.canonical(file)).message)
    }

    @Test("실행 중인 앱 거부는 applicationRunning 종류다")
    func runningAppKind() {
        let app = URL(filePath: "/Applications/sweep-ghost.app")
        #expect(Remover.kind(of: RemovalVeto.applicationRunning(app)) == .applicationRunning)
        #expect(Remover.kind(of: RemovalVeto.systemProtected(app)) == .protected)
    }

    @Test("권한 거부 오류는 permissionDenied, 그 밖은 other다")
    func fileSystemErrorKinds() {
        let cocoa = NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError)
        #expect(Remover.kind(of: cocoa) == .permissionDenied)

        // Cocoa 오류가 POSIX EACCES를 감싸 오는 경우
        let wrapped = NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError, userInfo: [
            NSUnderlyingErrorKey: NSError(domain: NSPOSIXErrorDomain, code: Int(EACCES)),
        ])
        #expect(Remover.kind(of: wrapped) == .permissionDenied)

        let missing = NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError)
        #expect(Remover.kind(of: missing) == .other)
    }

    // TC-5
    @Test("존재하지 않는 파일은 크래시 없이 실패로 기록된다")
    func missingFileIsRecordedAsFailure() {
        let ghost = URL(filePath: "/private/tmp/sweep-ghost-\(UUID().uuidString)/none.bin")
        let outcome = Remover(movesToTrash: false).removeOne(item(ghost))

        #expect(!outcome.succeeded)
        #expect(outcome.failureReason?.isEmpty == false)
    }

    // TC-6 · TC-10
    @Test("배치 삭제에서 성공과 차단이 함께 기록되고 회수량은 성공분만 센다")
    func batchSeparatesSuccessesAndBlocks() throws {
        let ok1 = try makeAllowedFile()
        let ok2 = try makeAllowedFile()
        let blocked = try makeForbiddenFile()
        defer {
            try? fm.removeItem(at: ok1.deletingLastPathComponent())
            try? fm.removeItem(at: ok2.deletingLastPathComponent())
            try? fm.removeItem(at: blocked.deletingLastPathComponent())
        }

        let report = Remover(movesToTrash: false).remove([
            item(ok1, size: 1_000),
            item(ok2, size: 2_000),
            item(blocked, size: 9_000_000),
        ])

        #expect(report.outcomes.count == 3)
        #expect(report.succeeded.count == 2)
        #expect(report.failed.count == 1)
        #expect(report.reclaimedBytes == 3_000)     // 차단된 9,000,000은 제외
        #expect(!report.succeeded.contains { $0.item.url == blocked })
        #expect(fm.fileExists(atPath: blocked.path))
    }

    // TC-7
    @Test("빈 배열을 넘기면 빈 report를 돌려준다")
    func emptyBatchYieldsEmptyReport() {
        let report = Remover().remove([])

        #expect(report.outcomes.isEmpty)
        #expect(report.reclaimedBytes == 0)
    }

    // TC-8
    @Test("휴지통 이동 모드에서 원래 경로에서 사라진다")
    func trashModeRemovesFromOriginalPath() throws {
        let file = try makeAllowedFile()
        defer { try? fm.removeItem(at: file.deletingLastPathComponent()) }

        let outcome = Remover(movesToTrash: true).removeOne(item(file))

        #expect(outcome.succeeded, "휴지통 이동 실패: \(outcome.failureReason ?? "")")
        #expect(!fm.fileExists(atPath: file.path))
    }

    // TC-9
    @Test("denyList 경로는 허용 루트 안이어도 관문에서 차단된다")
    func denyListedPathIsBlocked() {
        let profiles = home.appending(
            path: "Library/Developer/Xcode/UserData/Provisioning Profiles")

        // TC-4와 같은 이유. 여기도 `movesToTrash: false`였고, 프로비저닝
        // 프로파일은 재발급이 번거롭다. 관문에 직접 묻는다.
        do {
            try ProtectedPaths.validate(profiles)
            Issue.record("denyList 경로가 관문을 통과했다")
        } catch let veto as RemovalVeto {
            #expect(veto == .protectedPath(ProtectedPaths.canonical(profiles)))
        } catch {
            Issue.record("예상 밖 오류: \(error)")
        }
    }

    // MARK: - URL 단위 관문 (디스크 맵용)

    // TC-3
    @Test("허용 루트 안의 파일은 removeFile로 지워진다")
    func removeFileDeletesInsideAllowedRoot() throws {
        let fm = FileManager.default
        let target = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Caches/sweep-removefile-\(UUID().uuidString).bin")
        try Data("지워질 것".utf8).write(to: target)
        defer { try? fm.removeItem(at: target) }

        let failure = Remover().removeFile(at: target)

        #expect(failure == nil, "실패 사유: \(failure ?? "")")
        #expect(!fm.fileExists(atPath: target.path))
    }

    // TC-4
    @Test("허용 루트 밖 경로는 사유를 돌려주고 파일을 건드리지 않는다")
    func removeFileRejectsOutsideAllowedRoot() throws {
        let fm = FileManager.default
        let outside = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Documents/sweep-must-survive-\(UUID().uuidString).txt")
        try Data("건드리면 안 된다".utf8).write(to: outside)
        defer { try? fm.removeItem(at: outside) }

        let failure = Remover().removeFile(at: outside)

        #expect(failure != nil)
        // 실패했는데 파일이 사라지면 관문이 뚫린 것이다
        #expect(fm.fileExists(atPath: outside.path))
    }

    // TC-5
    @Test("removeOne과 removeFile이 같은 판정을 한다")
    func bothEntriesShareTheSameGate() throws {
        let fm = FileManager.default
        // 관문에 걸리는 경로 — 둘 다 거부해야 한다
        let outside = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Documents/sweep-gate-\(UUID().uuidString).txt")
        try Data("x".utf8).write(to: outside)
        defer { try? fm.removeItem(at: outside) }

        let remover = Remover()
        let viaFile = remover.removeFile(at: outside)
        let viaItem = remover.removeOne(
            CleanupItem(url: outside, size: 1, category: .devCache, safety: .safe))

        // 관문이 한 곳이므로 판정도 사유도 같아야 한다
        #expect(viaFile != nil)
        #expect(viaItem.failureReason == viaFile)
        #expect(fm.fileExists(atPath: outside.path))
    }

    // TC-6
    @Test("없는 경로여도 크래시하지 않고 사유를 돌려준다")
    func removeFileHandlesMissingPath() {
        let missing = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Caches/sweep-not-here-\(UUID().uuidString)")

        // 관문은 통과하지만 파일이 없다 — 던지지 않고 사유로 돌려줘야 한다
        let failure = Remover().removeFile(at: missing)
        #expect(failure != nil)
    }

    @Test("휴지통으로 옮기면 휴지통 안의 새 위치를 돌려준다")
    func trashingReturnsTrashedLocation() throws {
        let file = try makeAllowedFile()
        defer { try? fm.removeItem(at: file.deletingLastPathComponent()) }

        let outcome = Remover(movesToTrash: true).removeOne(item(file))
        // 실제 휴지통에 남지 않게 치운다.
        defer { if let trashed = outcome.trashedURL { try? fm.removeItem(at: trashed) } }

        #expect(outcome.succeeded)
        let trashed = try #require(outcome.trashedURL)
        #expect(fm.fileExists(atPath: trashed.path))
        #expect(!fm.fileExists(atPath: file.path))
    }

    @Test("영구 삭제와 실패에는 휴지통 위치가 없다")
    func noTrashedLocationWithoutTrash() throws {
        let file = try makeAllowedFile()
        defer { try? fm.removeItem(at: file.deletingLastPathComponent()) }
        #expect(Remover(movesToTrash: false).removeOne(item(file)).trashedURL == nil)

        let forbidden = try makeForbiddenFile()
        defer { try? fm.removeItem(at: forbidden.deletingLastPathComponent()) }
        let blocked = Remover(movesToTrash: true).removeOne(item(forbidden))
        #expect(!blocked.succeeded)
        #expect(blocked.trashedURL == nil)
    }

    // MARK: - 휴지통 비우기

    @Test("휴지통 안의 항목은 휴지통으로 옮기지 않고 바로 지운다")
    func emptiesTrashItemsPermanently() throws {
        // 가짜 휴지통은 허용 루트(`/private/tmp`) 안에 둔다. 진짜 휴지통은 건드리지 않는다.
        let trash = URL(filePath: "/private/tmp").appending(path: "sweep-trash-\(UUID().uuidString)")
        try fm.createDirectory(at: trash, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: trash) }
        let file = trash.appending(path: "버린것.zip")
        try Data(repeating: 0x41, count: 4096).write(to: file)

        let remover = Remover(movesToTrash: true, scope: .cleanup, trashFolders: [trash])
        let outcome = remover.removeOne(CleanupItem(url: file, size: 4096, category: .trash, safety: .caution))

        #expect(outcome.failure == nil)
        #expect(!fm.fileExists(atPath: file.path))
        // 되돌릴 자리가 없다
        #expect(outcome.trashedURL == nil)
    }

    @Test("두 번째 휴지통(iCloud Drive 역할) 안의 항목도 바로 지운다")
    func emptiesSecondTrashPermanently() throws {
        let home = URL(filePath: "/private/tmp").appending(path: "sweep-trash-\(UUID().uuidString)")
        let iCloud = URL(filePath: "/private/tmp").appending(path: "sweep-icloud-trash-\(UUID().uuidString)")
        try fm.createDirectory(at: iCloud, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: iCloud) }
        let file = iCloud.appending(path: "스크린샷.png")
        try Data(repeating: 0x41, count: 4096).write(to: file)

        let remover = Remover(movesToTrash: true, scope: .cleanup, trashFolders: [home, iCloud])
        let outcome = remover.removeOne(CleanupItem(url: file, size: 4096, category: .trash, safety: .caution))

        #expect(outcome.failure == nil)
        #expect(!fm.fileExists(atPath: file.path))
        #expect(outcome.trashedURL == nil)
    }

    @Test("휴지통 밖 항목은 여전히 휴지통으로 간다")
    func otherItemsStillGoToTrash() throws {
        let file = try makeAllowedFile()
        defer { try? fm.removeItem(at: file.deletingLastPathComponent()) }
        let elsewhere = URL(filePath: "/private/tmp").appending(path: "sweep-not-trash-\(UUID().uuidString)")

        let remover = Remover(movesToTrash: true, scope: .cleanup, trashFolders: [elsewhere])
        let outcome = remover.removeOne(item(file))

        #expect(outcome.failure == nil)
        #expect(outcome.trashedURL != nil)
        if let trashed = outcome.trashedURL { try? fm.removeItem(at: trashed) }
    }
}
