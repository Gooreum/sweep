import Testing
import Foundation
@testable import SweepKit

/// 진행률의 분모를 만드는 세기 패스. `build`의 방문 수와 맞아야 퍼센트가 정확하다.
@Suite("CountEntries")
struct CountEntriesTests {

    private var fm: FileManager { .default }
    private static let oneMB = 1024 * 1024

    private func makeSandbox() throws -> URL {
        let dir = URL(filePath: NSTemporaryDirectory())
            .appending(path: "sweep-count-\(UUID().uuidString)")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func write(_ bytes: Int, to url: URL) throws {
        try fm.createDirectory(at: url.deletingLastPathComponent(),
                               withIntermediateDirectories: true)
        try Data(repeating: 0x41, count: bytes).write(to: url)
    }

    // TC-1
    @Test("알려진 구조의 항목 수를 정확히 센다")
    func countsKnownTree() throws {
        let root = try makeSandbox()
        defer { try? fm.removeItem(at: root) }
        // 디렉토리 a, b, c + 파일 3개 = 6
        try write(1024, to: root.appending(path: "a/x.bin"))
        try write(1024, to: root.appending(path: "b/y.bin"))
        try write(1024, to: root.appending(path: "c/z.bin"))

        #expect(DiskUsageTree.countEntries(at: root) == 6)
    }

    // TC-2
    @Test("세기 결과가 build의 방문 수와 맞아떨어진다")
    func matchesBuildVisitCount() throws {
        let root = try makeSandbox()
        defer { try? fm.removeItem(at: root) }
        try write(Self.oneMB, to: root.appending(path: "a/b/deep.bin"))
        try write(Self.oneMB, to: root.appending(path: "c.bin"))

        let counted = DiskUsageTree.countEntries(at: root)
        let visits = Visits()
        _ = DiskUsageTree.build(at: root, maxDepth: 4, minimumSize: 1) { visits.increment() }

        // build는 루트 자신도 방문하므로 정확히 1 크다
        #expect(visits.value == counted + 1,
                "분모가 어긋난다: 세기 \(counted) vs 방문 \(visits.value)")
    }

    // TC-3
    @Test("숨김 파일도 함께 센다")
    func countsHiddenEntries() throws {
        let root = try makeSandbox()
        defer { try? fm.removeItem(at: root) }
        try write(1024, to: root.appending(path: "visible.bin"))
        try write(1024, to: root.appending(path: ".hidden.bin"))

        // build도 숨김을 포함하므로 세기도 포함해야 분모가 맞는다
        #expect(DiskUsageTree.countEntries(at: root) == 2)
    }

    // TC-4
    @Test("심볼릭 링크는 하나로 세되 그 아래로 내려가지 않는다")
    func doesNotDescendIntoSymlinks() throws {
        let root = try makeSandbox()
        let outside = try makeSandbox()
        defer {
            try? fm.removeItem(at: root)
            try? fm.removeItem(at: outside)
        }
        // 링크 대상에 3개를 넣어 둔다
        for name in ["p.bin", "q.bin", "r.bin"] {
            try write(1024, to: outside.appending(path: name))
        }
        try write(1024, to: root.appending(path: "own.bin"))
        try fm.createSymbolicLink(at: root.appending(path: "link"),
                                  withDestinationURL: outside)

        // own.bin + link = 2. 링크 대상의 3개는 세지 않는다.
        #expect(DiskUsageTree.countEntries(at: root) == 2)
    }

    // TC-5
    @Test("존재하지 않는 경로는 0이다")
    func missingPathCountsZero() {
        let ghost = URL(filePath: "/private/tmp/sweep-count-ghost-\(UUID().uuidString)")
        #expect(DiskUsageTree.countEntries(at: ghost) == 0)
    }

    // TC-6
    @Test("빈 디렉토리는 0이다")
    func emptyDirectoryCountsZero() throws {
        let root = try makeSandbox()
        defer { try? fm.removeItem(at: root) }

        #expect(DiskUsageTree.countEntries(at: root) == 0)
    }

    // TC-7
    @Test("취소 신호를 받으면 중간에 멈춘다")
    func stopsWhenCancelled() throws {
        let root = try makeSandbox()
        defer { try? fm.removeItem(at: root) }
        for i in 0..<5 {
            try write(1024, to: root.appending(path: "d\(i)/f\(i).bin"))
        }
        let full = DiskUsageTree.countEntries(at: root)
        #expect(full == 10)

        // 첫 디렉토리를 열기 전에 바로 취소
        let stopped = DiskUsageTree.countEntries(at: root, isCancelled: { true })
        #expect(stopped < full)
    }
}

/// 방문 횟수를 세는 잠금 카운터.
private final class Visits: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func increment() { lock.lock(); count += 1; lock.unlock() }
    var value: Int { lock.lock(); defer { lock.unlock() }; return count }
}
