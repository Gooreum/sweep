import Testing
import Foundation
@testable import SweepKit

@Suite("BulkDirectory")
struct BulkDirectoryTests {

    private let fm = FileManager.default

    private func makeSandbox() throws -> URL {
        let dir = URL(filePath: NSTemporaryDirectory())
            .appending(path: "sweep-bulk-\(UUID().uuidString)")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("파일·폴더·링크·숨김 파일을 종류와 함께 돌려준다")
    func listsKinds() throws {
        let dir = try makeSandbox()
        defer { try? fm.removeItem(at: dir) }
        try Data(repeating: 0x41, count: 100_000).write(to: dir.appending(path: "a.bin"))
        try Data().write(to: dir.appending(path: ".hidden"))
        try fm.createDirectory(at: dir.appending(path: "sub"), withIntermediateDirectories: false)
        try fm.createSymbolicLink(at: dir.appending(path: "link"),
                                  withDestinationURL: dir.appending(path: "a.bin"))

        let entries = try #require(BulkDirectory.entries(atPath: dir.path))
        let byName = Dictionary(uniqueKeysWithValues: entries.map { ($0.name, $0) })

        #expect(Set(byName.keys) == ["a.bin", ".hidden", "sub", "link"])
        #expect(byName["a.bin"]?.kind == .file)
        #expect(byName["sub"]?.kind == .directory)
        #expect(byName["link"]?.kind == .symlink)
        #expect(byName["link"]?.allocated == 0)
    }

    @Test("파일 크기는 FileManager의 할당 크기와 같고 수정 시각도 같다")
    func matchesResourceValues() throws {
        let dir = try makeSandbox()
        defer { try? fm.removeItem(at: dir) }
        let file = dir.appending(path: "a.bin")
        try Data(repeating: 0x41, count: 300_001).write(to: file)

        let entry = try #require(BulkDirectory.entries(atPath: dir.path)?.first)
        let values = try file.resourceValues(forKeys: [.totalFileAllocatedSizeKey,
                                                        .contentModificationDateKey])
        #expect(entry.allocated == Int64(values.totalFileAllocatedSize ?? -1))
        let expected = try #require(values.contentModificationDate)
        #expect(abs(try #require(entry.modified).timeIntervalSince(expected)) < 0.001)
    }

    @Test("빈 폴더는 빈 배열, 못 여는 곳은 nil이다")
    func emptyVersusUnreadable() throws {
        let dir = try makeSandbox()
        defer { try? fm.removeItem(at: dir) }

        #expect(BulkDirectory.entries(atPath: dir.path) == [])
        #expect(BulkDirectory.entries(atPath: dir.path + "/없음") == nil)

        let file = dir.appending(path: "f")
        try Data().write(to: file)
        #expect(BulkDirectory.entries(atPath: file.path) == nil)
    }

    @Test("버퍼 한 번에 다 안 들어가는 많은 항목도 빠짐없이 읽는다")
    func readsManyEntries() throws {
        let dir = try makeSandbox()
        defer { try? fm.removeItem(at: dir) }
        for i in 0..<3_000 {
            try Data().write(to: dir.appending(path: "파일-\(i)-\(String(repeating: "x", count: 40))"))
        }

        #expect(BulkDirectory.entries(atPath: dir.path)?.count == 3_000)
    }

    @Test("루트 아래는 슬래시를 겹치지 않고 잇는다")
    func join() {
        #expect(BulkDirectory.join("/", "Users") == "/Users")
        #expect(BulkDirectory.join("/Users", "me") == "/Users/me")
    }
}
