import Testing
import Foundation
@testable import SweepKit

@Suite("DirectorySize")
struct DirectorySizeTests {

    /// 테스트마다 격리된 임시 트리. defer로 지우도록 URL만 돌려준다.
    private func makeSandbox() throws -> URL {
        let dir = URL(filePath: NSTemporaryDirectory())
            .appending(path: "sweep-size-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func write(_ bytes: Int, to url: URL) throws {
        try Data(repeating: 0x41, count: bytes).write(to: url)
    }

    private static let oneMB = 1024 * 1024

    // TC-1
    @Test("1MB 파일 3개의 합계가 3MB 안팎으로 집계된다")
    func sumsFilesInDirectory() throws {
        let dir = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: dir) }

        for name in ["a.bin", "b.bin", "c.bin"] {
            try write(Self.oneMB, to: dir.appending(path: name))
        }

        let total = DirectorySize.bytes(at: dir)
        // 할당 크기는 블록 단위로 올림되므로 정확히 3MB가 아닐 수 있다.
        #expect(total >= Int64(3 * Self.oneMB))
        #expect(total < Int64(4 * Self.oneMB))
    }

    // TC-2
    @Test("단일 파일 경로를 넘기면 그 파일 크기가 반환된다")
    func measuresSingleFile() throws {
        let dir = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appending(path: "solo.bin")
        try write(Self.oneMB, to: file)

        let size = DirectorySize.bytes(at: file)
        #expect(size >= Int64(Self.oneMB))
        #expect(size < Int64(2 * Self.oneMB))
    }

    // TC-3
    @Test("빈 디렉토리는 0을 반환한다")
    func emptyDirectoryIsZero() throws {
        let dir = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: dir) }

        #expect(DirectorySize.bytes(at: dir) == 0)
    }

    // TC-4
    @Test("존재하지 않는 경로는 던지지 않고 0을 반환한다")
    func missingPathIsZero() {
        let ghost = URL(filePath: "/private/tmp/sweep-does-not-exist-\(UUID().uuidString)")
        #expect(DirectorySize.bytes(at: ghost) == 0)
    }

    // TC-5
    @Test("심볼릭 링크는 따라가지 않아 대상 용량이 합계에 섞이지 않는다")
    func doesNotFollowSymlinks() throws {
        let fm = FileManager.default
        let dir = try makeSandbox()
        let outside = try makeSandbox()
        defer {
            try? fm.removeItem(at: dir)
            try? fm.removeItem(at: outside)
        }

        try write(Self.oneMB, to: dir.appending(path: "real.bin"))
        let baseline = DirectorySize.bytes(at: dir)

        // 바깥의 큰 파일을 가리키는 링크를 안에 심는다
        let fat = outside.appending(path: "fat.bin")
        try write(5 * Self.oneMB, to: fat)
        try fm.createSymbolicLink(at: dir.appending(path: "link.bin"), withDestinationURL: fat)

        // 링크를 따라갔다면 5MB가 더해졌을 것이다
        #expect(DirectorySize.bytes(at: dir) == baseline)
    }

    // TC-6
    @Test("중첩된 하위 디렉토리까지 재귀적으로 합산된다")
    func sumsNestedDirectories() throws {
        let fm = FileManager.default
        let dir = try makeSandbox()
        defer { try? fm.removeItem(at: dir) }

        let deep = dir.appending(path: "one/two/three")
        try fm.createDirectory(at: deep, withIntermediateDirectories: true)

        try write(Self.oneMB, to: dir.appending(path: "top.bin"))
        try write(Self.oneMB, to: dir.appending(path: "one/mid.bin"))
        try write(Self.oneMB, to: deep.appending(path: "bottom.bin"))

        let total = DirectorySize.bytes(at: dir)
        #expect(total >= Int64(3 * Self.oneMB))
        #expect(total < Int64(4 * Self.oneMB))
    }

    // 회귀 방지: 링크가 큰 파일보다 먼저 열거되면 그 뒤가 통째로 잘렸었다
    @Test("심볼릭 링크가 먼저 나와도 뒤따르는 파일이 집계된다")
    func symlinkDoesNotTruncateEnumeration() throws {
        let fm = FileManager.default
        let dir = try makeSandbox()
        let outside = try makeSandbox()
        defer {
            try? fm.removeItem(at: dir)
            try? fm.removeItem(at: outside)
        }

        // 이름순으로 링크가 먼저 열거되도록 a/b로 짓는다
        try write(Self.oneMB, to: outside.appending(path: "target.bin"))
        try fm.createSymbolicLink(at: dir.appending(path: "a-link"),
                                  withDestinationURL: outside.appending(path: "target.bin"))

        let deep = dir.appending(path: "b-tree/nested")
        try fm.createDirectory(at: deep, withIntermediateDirectories: true)
        try write(3 * Self.oneMB, to: deep.appending(path: "big.bin"))

        // 링크 뒤의 3MB가 살아 있어야 한다
        let total = DirectorySize.bytes(at: dir)
        #expect(total >= Int64(3 * Self.oneMB), "링크 이후 항목이 잘렸다: \(total)바이트")
        #expect(total < Int64(4 * Self.oneMB), "링크 대상까지 따라갔다")
    }
}


/// `CleanupScanner` 프로토콜 자체의 계약을 확인하는 더미 구현.
private struct StubScanner: CleanupScanner {
    let category: ScanCategory = .devCache
    let produces: [CleanupItem]

    func scan() async -> [CleanupItem] { produces }
}

@Suite("CleanupScanner 프로토콜")
struct ScannerProtocolTests {

    // TC-7
    @Test("CleanupScanner 채택 타입이 category와 scan 결과를 돌려준다")
    func stubScannerSatisfiesProtocol() async {
        let item = CleanupItem(url: URL(filePath: "/private/tmp/x"), size: 10,
                               category: .devCache, safety: .safe)
        let scanner: any CleanupScanner = StubScanner(produces: [item])

        #expect(scanner.category == .devCache)
        let found = await scanner.scan()
        #expect(found == [item])
    }

    // TC-8
    @Test("children(of:)가 하위 항목을 돌려주고 숨김 파일은 제외한다")
    func childrenListsVisibleEntries() throws {
        let fm = FileManager.default
        let dir = URL(filePath: NSTemporaryDirectory())
            .appending(path: "sweep-children-\(UUID().uuidString)")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        try Data().write(to: dir.appending(path: "visible-a"))
        try Data().write(to: dir.appending(path: "visible-b"))
        try Data().write(to: dir.appending(path: ".hidden"))

        let names = Set(StubScanner(produces: []).children(of: dir).map(\.lastPathComponent))
        #expect(names == ["visible-a", "visible-b"])
    }

    // TC-9
    @Test("children(of:)는 없는 경로에 대해 빈 배열을 돌려준다")
    func childrenOfMissingPathIsEmpty() {
        let ghost = URL(filePath: "/private/tmp/sweep-missing-\(UUID().uuidString)")
        #expect(StubScanner(produces: []).children(of: ghost).isEmpty)
    }
}
