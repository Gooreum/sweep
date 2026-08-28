import Testing
import Foundation
@testable import SweepKit

/// SIP·불변 플래그가 걸린 항목이 삭제 후보로 올라오던 버그의 회귀 방지.
///
/// 소유자가 나이고 부모 디렉토리가 쓰기 가능해도 `SF_NOUNLINK`가 걸려 있으면
/// 커널이 unlink를 거부한다. 관문이 이 층을 봐야 한다.
@Suite("파일 플래그 관문")
struct FileFlagsTests {

    private var fm: FileManager { .default }

    private var temporaryRoots: [URL] { ProtectedPaths.userTemporaryRoots }

    private func veto(_ url: URL) -> RemovalVeto? {
        do { try ProtectedPaths.validate(url); return nil }
        catch let v as RemovalVeto { return v }
        catch { Issue.record("예상 밖 오류: \(error)"); return nil }
    }

    /// 허용 루트 안(`/private/tmp`)에 파일 하나를 만든다.
    private func makeFile() throws -> URL {
        let dir = URL(filePath: "/private/tmp").appending(path: "sweep-flags-\(UUID().uuidString)")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appending(path: "target.bin")
        try Data(repeating: 0x41, count: 128).write(to: file)
        return file
    }

    private func chflags(_ argument: String, _ url: URL) throws {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/chflags")
        process.arguments = [argument, url.path]
        try process.run()
        process.waitUntilExit()
        try #require(process.terminationStatus == 0, "chflags \(argument) 실패")
    }

    /// 임시 컨테이너에서 blocking 플래그가 걸린 실제 항목 하나.
    private func findFlaggedItem() -> URL? {
        for root in temporaryRoots {
            let children = (try? fm.contentsOfDirectory(
                at: root, includingPropertiesForKeys: nil, options: [])) ?? []
            for child in children {
                if let f = ProtectedPaths.fileFlags(of: child),
                   f & ProtectedPaths.undeletableFlags != 0 {
                    return child
                }
            }
        }
        return nil
    }

    // TC-1 — 이번 버그의 직접 재현
    @Test("SF_NOUNLINK이 걸린 실제 항목은 systemProtected로 거부된다")
    func rejectsRealFlaggedItem() throws {
        let flagged = try #require(findFlaggedItem(),
                                   "이 머신의 임시 컨테이너에 플래그 항목이 없어 검증할 수 없다")

        guard case .systemProtected = veto(flagged) else {
            Issue.record("거부되지 않았다: \(flagged.path) → \(String(describing: veto(flagged)))")
            return
        }
        #expect(!ProtectedPaths.isRemovable(flagged))
    }

    // TC-2
    @Test("평범한 임시 파일은 통과한다")
    func allowsOrdinaryFile() throws {
        let file = try makeFile()
        defer { try? fm.removeItem(at: file.deletingLastPathComponent()) }

        #expect(ProtectedPaths.fileFlags(of: file) == 0)
        try ProtectedPaths.validate(file)       // 던지지 않아야 한다
    }

    // TC-3 — 검사가 실제로 플래그를 보고 있다는 증명
    @Test("uchg를 걸면 거부되고 풀면 다시 통과한다")
    func togglingImmutableFlagFlipsTheVerdict() throws {
        let file = try makeFile()
        defer {
            try? chflags("nouchg", file)
            try? fm.removeItem(at: file.deletingLastPathComponent())
        }

        // 걸기 전에는 통과
        #expect(ProtectedPaths.isRemovable(file))

        try chflags("uchg", file)
        guard case .systemProtected = veto(file) else {
            Issue.record("uchg를 걸었는데 통과했다: \(String(describing: veto(file)))")
            return
        }

        try chflags("nouchg", file)
        #expect(ProtectedPaths.isRemovable(file), "플래그를 풀었는데 여전히 거부된다")
    }

    // TC-4
    @Test("존재하지 않는 경로는 플래그 검사를 건너뛴다")
    func skipsFlagCheckForMissingPaths() {
        let ghost = URL(filePath: "/private/tmp/sweep-flags-ghost-\(UUID().uuidString)/none.bin")

        #expect(ProtectedPaths.fileFlags(of: ghost) == nil)
        #expect(veto(ghost) == nil, "없는 경로가 거부됐다: \(String(describing: veto(ghost)))")
    }

    // TC-5
    @Test("undeletableFlags가 5종 플래그를 모두 포함한다")
    func maskCoversAllBlockingFlags() {
        let mask = ProtectedPaths.undeletableFlags

        #expect(mask & UInt32(UF_IMMUTABLE) != 0)
        #expect(mask & 0x0000_0010 != 0)                    // UF_NOUNLINK
        #expect(mask & UInt32(SF_IMMUTABLE) != 0)
        #expect(mask & UInt32(SF_NOUNLINK) != 0)
        #expect(mask & UInt32(SF_RESTRICTED) != 0)
    }

    // TC-6
    @Test("임시 컨테이너의 플래그 항목은 하나도 삭제 가능으로 판정되지 않는다")
    func noFlaggedItemIsRemovable() {
        var checked = 0
        for root in temporaryRoots {
            let children = (try? fm.contentsOfDirectory(
                at: root, includingPropertiesForKeys: nil, options: [])) ?? []
            for child in children {
                guard let f = ProtectedPaths.fileFlags(of: child),
                      f & ProtectedPaths.undeletableFlags != 0 else { continue }
                checked += 1
                #expect(!ProtectedPaths.isRemovable(child), "플래그 항목이 통과했다: \(child.path)")
            }
        }
        #expect(checked > 0, "플래그 항목을 하나도 찾지 못해 검증이 비었다")
    }

    // TC-7
    @Test("기존 veto 5종이 플래그보다 먼저 판정된다")
    func earlierVetosTakePrecedence() {
        let home = fm.homeDirectoryForCurrentUser

        guard case .rootOrHome = veto(URL(filePath: "/")) else {
            Issue.record("루트: rootOrHome이 아니다"); return
        }
        guard case .allowedRootItself = veto(home.appending(path: "Downloads")) else {
            Issue.record("Downloads: allowedRootItself가 아니다"); return
        }
        guard case .protectedPath = veto(home.appending(
            path: "Library/Developer/Xcode/UserData/Provisioning Profiles")) else {
            Issue.record("프로파일: protectedPath가 아니다"); return
        }
        guard case .outsideAllowedRoots = veto(home.appending(path: "Documents/중요파일.txt")) else {
            Issue.record("Documents: outsideAllowedRoots가 아니다"); return
        }
    }

    // TC-8
    @Test("Remover가 플래그 걸린 파일을 실패로 기록하고 파일은 남는다")
    func removerBlocksFlaggedFile() throws {
        let file = try makeFile()
        defer {
            try? chflags("nouchg", file)
            try? fm.removeItem(at: file.deletingLastPathComponent())
        }
        try chflags("uchg", file)

        let item = CleanupItem(url: file, size: 128, category: .runawayTemp, safety: .safe)
        let outcome = Remover(movesToTrash: false).removeOne(item)

        #expect(!outcome.succeeded)
        #expect(outcome.failureReason?.contains("시스템이 보호 중") == true)
        #expect(fm.fileExists(atPath: file.path), "관문이 막았는데 파일이 사라졌다")
    }

    // TC-9
    @Test("fileFlags가 실제 플래그 값을 돌려준다")
    func fileFlagsReturnsActualValue() throws {
        let file = try makeFile()
        defer {
            try? chflags("nouchg", file)
            try? fm.removeItem(at: file.deletingLastPathComponent())
        }

        #expect(ProtectedPaths.fileFlags(of: file) == 0)

        try chflags("uchg", file)
        let flags = try #require(ProtectedPaths.fileFlags(of: file))
        #expect(flags & UInt32(UF_IMMUTABLE) != 0)
    }

    // MARK: - lstat 통합 (소유권 + 플래그를 한 번에)

    // TC-1
    @Test("fileInfo가 uid와 flags를 함께 돌려준다")
    func fileInfoReturnsBoth() throws {
        let file = try makeFile()
        defer { try? fm.removeItem(at: file.deletingLastPathComponent()) }

        let info = try #require(ProtectedPaths.fileInfo(of: file))

        #expect(info.uid == getuid())
        #expect(info.flags == 0)
    }

    // TC-2
    @Test("존재하지 않는 경로의 fileInfo는 nil이다")
    func fileInfoOfMissingPathIsNil() {
        let ghost = URL(filePath: "/private/tmp/sweep-info-ghost-\(UUID().uuidString)")
        #expect(ProtectedPaths.fileInfo(of: ghost) == nil)
    }

    // TC-3
    @Test("uchg를 걸면 fileInfo의 flags에 반영된다")
    func fileInfoReflectsFlags() throws {
        let file = try makeFile()
        defer {
            try? chflags("nouchg", file)
            try? fm.removeItem(at: file.deletingLastPathComponent())
        }
        try chflags("uchg", file)

        let info = try #require(ProtectedPaths.fileInfo(of: file))

        #expect(info.flags & UInt32(UF_IMMUTABLE) != 0)
        #expect(info.uid == getuid(), "플래그를 걸어도 소유자는 그대로다")
    }

    // TC-6
    @Test("소유권이 플래그보다 먼저 판정된다")
    func ownershipIsCheckedBeforeFlags() throws {
        // /private/var/folders 하위 버킷은 root 소유이면서 플래그도 걸려 있다
        ProtectedPaths.additionalRootsForTesting = [URL(filePath: "/private/var/folders")]
        defer { ProtectedPaths.additionalRootsForTesting = [] }

        let bucket = try #require(fm.contentsOfDirectory(
            at: URL(filePath: "/private/var/folders"),
            includingPropertiesForKeys: nil).first)

        guard case .notOwnedByCurrentUser = veto(bucket) else {
            Issue.record("소유권보다 플래그가 먼저 판정됐다: \(String(describing: veto(bucket)))")
            return
        }
    }
}
