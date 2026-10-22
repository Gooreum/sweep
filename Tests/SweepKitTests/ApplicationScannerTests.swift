import Testing
import Foundation
@testable import SweepKit

@Suite("ApplicationScanner")
struct ApplicationScannerTests {

    private let fm = FileManager.default

    /// A.app·B.app은 바로 아래, C.app은 한 단 아래, D는 앱이 아니다.
    private func makeFolder() throws -> URL {
        let root = URL(filePath: NSTemporaryDirectory()).appending(path: "sweep-apps-\(UUID().uuidString)")
        for app in ["A.app", "B.app", "Sub/C.app"] {
            let contents = root.appending(path: "\(app)/Contents")
            try fm.createDirectory(at: contents, withIntermediateDirectories: true)
            try Data(repeating: 0x41, count: 8192).write(to: contents.appending(path: "x"))
        }
        try fm.createDirectory(at: root.appending(path: "D"), withIntermediateDirectories: true)
        try Data(repeating: 0x42, count: 8192).write(to: root.appending(path: "D/y"))
        return root
    }

    // TC-1
    @Test("앱 폴더 바로 아래 .app만 응용 프로그램으로 올린다")
    func listsTopLevelApps() async throws {
        let root = try makeFolder()
        defer { try? fm.removeItem(at: root) }

        let items = await ApplicationScanner(folders: [root], lastUsed: { _ in nil }, running: { [] }).scan()

        #expect(Set(items.map(\.displayName)) == ["A.app", "B.app"])
        #expect(items.allSatisfy { $0.category == .application && $0.size > 0 })
    }

    // TC-2
    @Test("마지막으로 연 날짜를 그대로 담고, 모르면 비워 둔다")
    func carriesLastUsed() async throws {
        let root = try makeFolder()
        defer { try? fm.removeItem(at: root) }
        let opened = Date(timeIntervalSince1970: 1_700_000_000)

        let items = await ApplicationScanner(
            folders: [root], lastUsed: { $0.lastPathComponent == "A.app" ? opened : nil },
            running: { [] }).scan()

        #expect(items.first { $0.displayName == "A.app" }?.dates.lastUsed == opened)
        #expect(items.first { $0.displayName == "B.app" }?.dates.lastUsed == nil)
    }

    // TC-3
    @Test("실행 중인 앱은 잠그고, 나머지는 확인 필요로 둔다")
    func locksRunningApps() async throws {
        let root = try makeFolder()
        defer { try? fm.removeItem(at: root) }
        let runningA = root.appending(path: "A.app")

        let items = await ApplicationScanner(folders: [root], lastUsed: { _ in nil },
                                             running: { [runningA] }).scan()

        #expect(items.first { $0.displayName == "A.app" }?.safety == .danger)
        #expect(items.first { $0.displayName == "B.app" }?.safety == .caution)
        #expect(items.allSatisfy { !$0.isSelectedByDefault })
    }

    @Test("사용 문구는 30일을 기준으로 나뉘고, 기록이 없으면 지어내지 않는다")
    func usageLine() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        #expect(ApplicationScanner.usageLine(now.addingTimeInterval(-86_400 * 3), now: now) == "최근에 열었어요")
        #expect(ApplicationScanner.usageLine(now.addingTimeInterval(-86_400 * 90), now: now).contains("90"))
        #expect(ApplicationScanner.usageLine(nil, now: now).contains("기록"))
    }

    @Test("없는 폴더는 건너뛴다")
    func missingFolder() async {
        let ghost = URL(filePath: "/private/tmp/sweep-없음-\(UUID().uuidString)")
        #expect(await ApplicationScanner(folders: [ghost], lastUsed: { _ in nil }, running: { [] }).scan().isEmpty)
    }
}
