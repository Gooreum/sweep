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
