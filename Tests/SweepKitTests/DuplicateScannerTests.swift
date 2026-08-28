import Testing
import Foundation
@testable import SweepKit

@Suite("DuplicateScanner")
struct DuplicateScannerTests {

    private static let oneMB = 1024 * 1024

    private func makeFakeHome() throws -> URL {
        let home = URL(filePath: NSTemporaryDirectory())
            .appending(path: "sweep-dup-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: home.appending(path: "Downloads"), withIntermediateDirectories: true)
        return home
    }

    /// Downloads 아래에 파일을 만든다. `created`를 명시해 원본 판정 순서를 고정한다.
    @discardableResult
    private func place(_ name: String, bytes: Data, in home: URL,
                       created: Date? = nil, subdirectory: String? = nil) throws -> URL {
        var dir = home.appending(path: "Downloads")
        if let subdirectory {
            dir = dir.appending(path: subdirectory)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let url = dir.appending(path: name)
        try bytes.write(to: url)
        if let created {
            try FileManager.default.setAttributes([.creationDate: created], ofItemAtPath: url.path)
        }
        return url
    }

    private func payload(_ byte: UInt8, _ count: Int) -> Data {
        Data(repeating: byte, count: count)
    }

    // TC-1
    @Test("내용이 같은 파일 3개 중 원본 1개를 남기고 2개만 후보로 올린다")
    func keepsOldestAsOriginal() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        let data = payload(0x41, 2 * Self.oneMB)
        try place("original.zip", bytes: data, in: home, created: Date(timeIntervalSince1970: 1_000))
        try place("copy-1.zip", bytes: data, in: home, created: Date(timeIntervalSince1970: 2_000))
        try place("copy-2.zip", bytes: data, in: home, created: Date(timeIntervalSince1970: 3_000))

        let items = await DuplicateScanner(home: home).scan()
        let names = Set(items.map(\.displayName))

        #expect(items.count == 2)
        #expect(names == ["copy-1.zip", "copy-2.zip"])
        #expect(!names.contains("original.zip"), "원본이 삭제 후보로 올라갔다")
    }

    // TC-2
    @Test("크기는 같지만 내용이 다르면 후보가 아니다")
    func sameSizeDifferentContentIsNotDuplicate() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        try place("a.bin", bytes: payload(0x41, 2 * Self.oneMB), in: home)
        try place("b.bin", bytes: payload(0x42, 2 * Self.oneMB), in: home)

        let items = await DuplicateScanner(home: home).scan()
        #expect(items.isEmpty)
    }

    // TC-3
    @Test("앞 64KB가 같아도 뒷부분이 다르면 전체 해시에서 걸러진다")
    func identicalPrefixButDifferentTailIsNotDuplicate() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        var first = payload(0x41, 128 * 1024)
        var second = payload(0x41, 128 * 1024)
        first.append(payload(0x01, 2 * Self.oneMB))
        second.append(payload(0x02, 2 * Self.oneMB))

        try place("head-same-a.bin", bytes: first, in: home)
        try place("head-same-b.bin", bytes: second, in: home)

        let items = await DuplicateScanner(home: home).scan()
        #expect(items.isEmpty)
    }

    // TC-4
    @Test("minimumSize 미만인 동일 파일은 후보가 아니다")
    func skipsFilesBelowMinimumSize() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        let tiny = payload(0x41, 1024)
        try place("small-a.txt", bytes: tiny, in: home)
        try place("small-b.txt", bytes: tiny, in: home)

        let items = await DuplicateScanner(home: home).scan()
        #expect(items.isEmpty)
    }

    // TC-5
    @Test("detail에 원본 파일명이 담긴다")
    func detailNamesTheOriginal() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        let data = payload(0x41, 2 * Self.oneMB)
        try place("보고서.pdf", bytes: data, in: home, created: Date(timeIntervalSince1970: 1_000))
        try place("보고서 (1).pdf", bytes: data, in: home, created: Date(timeIntervalSince1970: 2_000))

        let items = await DuplicateScanner(home: home).scan()

        #expect(items.count == 1)
        #expect(items.first?.detail == "보고서.pdf와 내용이 같습니다")
    }

    // TC-6
    @Test("Downloads가 없는 홈에서도 던지지 않는다")
    func missingDownloadsIsEmpty() async throws {
        let home = URL(filePath: NSTemporaryDirectory())
            .appending(path: "sweep-dup-nohome-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }

        let items = await DuplicateScanner(home: home).scan()
        #expect(items.isEmpty)
    }

    // TC-7
    @Test("하위 디렉토리의 중복 파일도 찾아낸다")
    func findsDuplicatesInSubdirectories() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        let data = payload(0x41, 2 * Self.oneMB)
        try place("top.iso", bytes: data, in: home, created: Date(timeIntervalSince1970: 1_000))
        try place("nested.iso", bytes: data, in: home,
                  created: Date(timeIntervalSince1970: 2_000), subdirectory: "old/backup")

        let items = await DuplicateScanner(home: home).scan()

        #expect(items.count == 1)
        #expect(items.first?.displayName == "nested.iso")
    }

    // TC-8
    @Test("중복 항목은 duplicate·safe이며 기본 선택 대상이다")
    func categoryAndSafetyAreConsistent() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        let data = payload(0x41, 2 * Self.oneMB)
        try place("x.bin", bytes: data, in: home, created: Date(timeIntervalSince1970: 1_000))
        try place("y.bin", bytes: data, in: home, created: Date(timeIntervalSince1970: 2_000))

        let items = await DuplicateScanner(home: home).scan()

        #expect(items.count == 1)
        #expect(items.allSatisfy { $0.category == .duplicate })
        #expect(items.allSatisfy { $0.safety == .safe })
        #expect(items.allSatisfy { $0.isSelectedByDefault })
    }

    // TC-9
    @Test("limit을 주면 앞부분만 해시해 뒷부분 차이를 무시한다")
    func prefixHashIgnoresTail() throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        var first = payload(0x41, 128 * 1024)
        var second = payload(0x41, 128 * 1024)
        first.append(payload(0x01, 1024))
        second.append(payload(0x02, 1024))

        let a = try place("a.bin", bytes: first, in: home)
        let b = try place("b.bin", bytes: second, in: home)

        // 앞 64KB만 보면 같고
        #expect(DuplicateScanner.hash(of: a, limit: 64 * 1024)
                == DuplicateScanner.hash(of: b, limit: 64 * 1024))
        // 전체를 보면 다르다
        #expect(DuplicateScanner.hash(of: a, limit: nil)
                != DuplicateScanner.hash(of: b, limit: nil))
    }

    // TC-10
    @Test("읽을 수 없는 경로의 해시는 빈 문자열이다")
    func hashOfMissingFileIsEmpty() {
        let ghost = URL(filePath: "/private/tmp/sweep-no-such-\(UUID().uuidString)")
        #expect(DuplicateScanner.hash(of: ghost, limit: nil).isEmpty)
    }

    // TC-11
    @Test("서로 다른 중복 그룹마다 원본을 하나씩 보존한다")
    func handlesMultipleDuplicateGroups() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        let groupA = payload(0x41, 2 * Self.oneMB)
        let groupB = payload(0x42, 3 * Self.oneMB)

        try place("a1.bin", bytes: groupA, in: home, created: Date(timeIntervalSince1970: 1_000))
        try place("a2.bin", bytes: groupA, in: home, created: Date(timeIntervalSince1970: 2_000))
        try place("b1.bin", bytes: groupB, in: home, created: Date(timeIntervalSince1970: 1_000))
        try place("b2.bin", bytes: groupB, in: home, created: Date(timeIntervalSince1970: 2_000))
        try place("b3.bin", bytes: groupB, in: home, created: Date(timeIntervalSince1970: 3_000))

        let items = await DuplicateScanner(home: home).scan()
        let names = Set(items.map(\.displayName))

        #expect(items.count == 3)                       // A에서 1개, B에서 2개
        #expect(names == ["a2.bin", "b2.bin", "b3.bin"])
    }
}
