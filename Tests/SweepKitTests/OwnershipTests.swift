import Testing
import Foundation
@testable import SweepKit

/// 관문이 남의 소유 경로를 거부하는지 확인한다.
/// `/private/var/folders/mg`(root:wheel)가 삭제 후보로 새어 나오던 버그의 2차 방어선이다.
@Suite("소유권 관문", .serialized)
struct OwnershipTests {

    private var fm: FileManager { .default }

    /// root 소유가 확실한 경로. 어느 macOS에나 있다.
    private let systemOwned = URL(filePath: "/private/var/folders")

    private func veto(_ url: URL) -> RemovalVeto? {
        do { try ProtectedPaths.validate(url); return nil }
        catch let v as RemovalVeto { return v }
        catch { Issue.record("예상 밖 오류: \(error)"); return nil }
    }

    // TC-1
    @Test("허용 루트 안이어도 root 소유면 거부된다")
    func rejectsSystemOwnedInsideAllowedRoot() throws {
        // 소유권 검사만 남기려고 루트 축소를 잠시 비활성화한다.
        // 이 훅이 없으면 outsideAllowedRoots가 먼저 걸려 6단계에 도달하지 못한다.
        ProtectedPaths.additionalRootsForTesting = [systemOwned]
        defer { ProtectedPaths.additionalRootsForTesting = [] }

        let bucket = try #require(
            fm.contentsOfDirectory(at: systemOwned, includingPropertiesForKeys: nil).first)
        try #require(
            (try fm.attributesOfItem(atPath: bucket.path)[.ownerAccountID] as? NSNumber)?
                .uint32Value != getuid(),
            "테스트 전제 위반: \(bucket.path)가 내 소유다")

        guard case .notOwnedByCurrentUser = veto(bucket) else {
            Issue.record("root 소유가 거부되지 않았다: \(bucket.path) → \(String(describing: veto(bucket)))")
            return
        }
    }

    // TC-2
    @Test("내가 만든 파일은 소유권 검사를 통과한다")
    func allowsFilesIOwn() throws {
        let dir = URL(filePath: "/private/tmp").appending(path: "sweep-own-\(UUID().uuidString)")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        let file = dir.appending(path: "mine.bin")
        try Data(repeating: 0x41, count: 32).write(to: file)

        try ProtectedPaths.validate(file)       // 던지지 않아야 한다
        #expect(ProtectedPaths.isRemovable(file))
    }

    // TC-3
    @Test("존재하지 않는 경로는 소유권 검사를 건너뛴다")
    func skipsOwnershipCheckForMissingPaths() {
        // 허용 루트 안의 없는 경로 → 통과해야 한다 (기존 동작 유지)
        let ghost = URL(filePath: "/private/tmp/sweep-ghost-\(UUID().uuidString)/none.bin")
        #expect(veto(ghost) == nil, "없는 경로가 거부됐다: \(String(describing: veto(ghost)))")

        // 허용 루트 밖의 없는 경로 → 소유권이 아니라 범위로 거부되어야 한다
        let outside = fm.homeDirectoryForCurrentUser
            .appending(path: "Documents/sweep-ghost-\(UUID().uuidString).txt")
        guard case .outsideAllowedRoots = veto(outside) else {
            Issue.record("outsideAllowedRoots가 아니라 \(String(describing: veto(outside)))")
            return
        }
    }

    // TC-4
    @Test("소유권 veto가 경로를 담은 문장을 돌려준다")
    func vetoMessageNamesThePath() {
        let url = URL(filePath: "/private/var/folders/mg")
        let message = RemovalVeto.notOwnedByCurrentUser(url).message

        #expect(message.contains("/private/var/folders/mg"))
        #expect(message.contains("소유"))
    }

    // TC-5 · TC-6
    @Test("Remover가 root 소유 파일을 실패로 기록하고 파일은 남는다")
    func removerBlocksSystemOwnedAndLeavesItIntact() throws {
        ProtectedPaths.additionalRootsForTesting = [systemOwned]
        defer { ProtectedPaths.additionalRootsForTesting = [] }

        let bucket = try #require(
            fm.contentsOfDirectory(at: systemOwned, includingPropertiesForKeys: nil).first)
        let item = CleanupItem(url: bucket, size: 1_000, category: .runawayTemp, safety: .safe)

        let outcome = Remover(movesToTrash: false).removeOne(item)

        #expect(!outcome.succeeded)
        #expect(outcome.failureReason?.contains("다른 사용자·시스템 소유") == true)
        // 관문이 막았으면 실제로 남아 있어야 한다
        #expect(fm.fileExists(atPath: bucket.path), "시스템 디렉토리가 사라졌다")
    }

    // TC-7
    @Test("기존 veto 5종이 소유권보다 먼저 판정된다")
    func earlierVetosTakePrecedence() {
        let home = fm.homeDirectoryForCurrentUser

        guard case .rootOrHome = veto(URL(filePath: "/")) else {
            Issue.record("루트: rootOrHome이 아니다"); return
        }
        guard case .rootOrHome = veto(home) else {
            Issue.record("홈: rootOrHome이 아니다"); return
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
    @Test("실제 var/folders 버킷은 어떤 경우에도 삭제 불가로 판정된다")
    func realBucketIsNeverRemovable() throws {
        for bucket in try fm.contentsOfDirectory(at: systemOwned, includingPropertiesForKeys: nil) {
            #expect(!ProtectedPaths.isRemovable(bucket), "버킷이 통과했다: \(bucket.path)")
        }
    }

    // 판정 순서 — FileFlagsTests에 있던 것을 여기로 옮겼다.
    // `additionalRootsForTesting`이 전역 가변 상태라 두 스위트가 병렬로 건드리면
    // 서로의 설정을 지운다. 훅을 쓰는 테스트는 이 직렬화된 스위트에 모은다.
    @Test("소유권이 플래그보다 먼저 판정된다")
    func ownershipIsCheckedBeforeFlags() throws {
        ProtectedPaths.additionalRootsForTesting = [systemOwned]
        defer { ProtectedPaths.additionalRootsForTesting = [] }

        // 버킷은 root 소유이면서 SF_NOUNLINK 플래그도 걸려 있다.
        // 둘 다 해당할 때 어느 쪽 메시지가 나가는지가 여기서 고정된다.
        let bucket = try #require(
            fm.contentsOfDirectory(at: systemOwned, includingPropertiesForKeys: nil).first)

        guard case .notOwnedByCurrentUser = veto(bucket) else {
            Issue.record("소유권보다 플래그가 먼저 판정됐다: \(String(describing: veto(bucket)))")
            return
        }
    }
}
