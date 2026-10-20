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
        #expect(items.first?.detail == "같은 내용의 원본이 남아요: 보고서.pdf")
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
    @Test("읽을 수 없는 경로의 해시는 nil이다")
    func hashOfMissingFileIsNil() {
        let ghost = URL(filePath: "/private/tmp/sweep-no-such-\(UUID().uuidString)")
        // 빈 문자열이면 읽기 불가 파일들이 전부 같은 키로 묶인다 — 그게 버그였다.
        #expect(DuplicateScanner.hash(of: ghost, limit: nil) == nil)
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

    // MARK: - 읽기 실패 격리

    /// 파일을 읽을 수 없게 막는다. 권한을 되돌리는 클로저를 함께 준다 —
    /// 되돌리지 않으면 임시 폴더 삭제가 실패해 쓰레기가 남는다.
    private func lock(_ urls: [URL]) throws -> () -> Void {
        for url in urls {
            try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: url.path)
        }
        return {
            for url in urls {
                try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)
            }
        }
    }

    // TC-12
    @Test("열리지만 읽는 도중 오류가 나는 경로(디렉토리)도 nil이다")
    func hashOfUnreadableHandleIsNil() throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        // 디렉토리는 open()은 되지만 read()가 EISDIR로 실패한다.
        // 예전 코드는 여기서 루프가 조용히 끝나 "빈 내용의 해시"를 돌려줬다.
        #expect(DuplicateScanner.hash(of: home, limit: nil) == nil)
    }

    // TC-13
    @Test("크기가 같은 읽기 불가 파일 둘은 중복으로 묶이지 않는다")
    func unreadableSameSizeFilesAreNotDuplicates() async throws {
        let home = try makeFakeHome()
        let a = try place("a.bin", bytes: payload(0x41, 2 * Self.oneMB), in: home)
        let b = try place("b.bin", bytes: payload(0x42, 2 * Self.oneMB), in: home)
        let unlock = try lock([a, b])
        defer {
            unlock()
            try? FileManager.default.removeItem(at: home)
        }

        let items = await DuplicateScanner(home: home).scan()

        // 내용이 다른 두 파일인데, 둘 다 못 읽는다는 이유로 "같다"고 하면
        // 한쪽이 `.safe` 중복으로 기본 선택되어 휴지통으로 간다.
        #expect(items.isEmpty, "읽을 수 없는 파일 둘이 중복으로 잡혔다")
    }

    // TC-14
    @Test("읽기 불가 파일이 섞여 있어도 읽히는 중복은 그대로 찾는다")
    func unreadableFilesDoNotHideRealDuplicates() async throws {
        let home = try makeFakeHome()
        let same = payload(0x41, 2 * Self.oneMB)
        try place("a.bin", bytes: same, in: home, created: Date(timeIntervalSince1970: 1_000))
        try place("b.bin", bytes: same, in: home, created: Date(timeIntervalSince1970: 2_000))
        let c = try place("c.bin", bytes: payload(0x43, 2 * Self.oneMB), in: home)
        let d = try place("d.bin", bytes: payload(0x44, 2 * Self.oneMB), in: home)
        let unlock = try lock([c, d])
        defer {
            unlock()
            try? FileManager.default.removeItem(at: home)
        }

        let items = await DuplicateScanner(home: home).scan()

        // 같은 크기 넷 중 읽히는 a·b만 묶이고, 나중에 받은 b만 후보다
        #expect(items.count == 1)
        #expect(items.first?.displayName == "b.bin")
    }

    // MARK: - 사용자 폴더 전체

    /// 홈 기준 상대 경로에 파일을 만든다.
    @discardableResult
    private func put(_ relative: String, bytes: Data, in home: URL, created: Date) throws -> URL {
        let url = home.appending(path: relative)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try bytes.write(to: url)
        try FileManager.default.setAttributes([.creationDate: created], ofItemAtPath: url.path)
        return url
    }

    @Test("Downloads와 Documents 사이의 중복을 찾는다")
    func findsDuplicatesAcrossRoots() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let data = payload(0x51, 2 * Self.oneMB)
        try put("Documents/계약서.pdf", bytes: data, in: home, created: Date(timeIntervalSince1970: 1_000))
        try put("Downloads/계약서 (1).pdf", bytes: data, in: home, created: Date(timeIntervalSince1970: 2_000))

        let items = await DuplicateScanner(home: home).scan()

        #expect(items.map(\.displayName) == ["계약서 (1).pdf"])
        // 원본이 다른 폴더에 있으면 어디 있는지 경로로 말한다
        #expect(items.first?.detail == "같은 내용의 원본이 남아요: ~/Documents/계약서.pdf")
    }

    @Test("Downloads 안의 사본은 safe, 밖의 사본은 caution이다")
    func safetyDependsOnLocation() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let data = payload(0x52, 2 * Self.oneMB)
        try put("Code/원본.png", bytes: data, in: home, created: Date(timeIntervalSince1970: 1_000))
        try put("Downloads/받은.png", bytes: data, in: home, created: Date(timeIntervalSince1970: 2_000))
        try put("Desktop/복사.png", bytes: data, in: home, created: Date(timeIntervalSince1970: 3_000))

        let items = await DuplicateScanner(home: home).scan()
        let safety = Dictionary(uniqueKeysWithValues: items.map { ($0.displayName, $0.safety) })

        #expect(safety == ["받은.png": .safe, "복사.png": .caution])
        #expect(items.first { $0.displayName == "복사.png" }?.isSelectedByDefault == false)
    }

    @Test("iCloud에만 있는 파일은 해시하지 않아 중복으로 묶이지 않는다")
    func datalessFilesAreNotHashed() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let data = payload(0x53, 2 * Self.oneMB)
        try put("Documents/클라우드.key", bytes: data, in: home, created: Date(timeIntervalSince1970: 1_000))
        try put("Downloads/클라우드 (1).key", bytes: data, in: home, created: Date(timeIntervalSince1970: 2_000))

        let items = await DuplicateScanner(minimumSize: Int64(Self.oneMB), home: home, roots: nil,
                                           isDataless: { $0.path.contains("/Documents/") }).scan()
        #expect(items.isEmpty)
    }

    @Test("의존성 폴더 안의 같은 파일은 중복으로 올리지 않는다")
    func skipsDependencyFolders() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let data = payload(0x54, 2 * Self.oneMB)
        try put("Code/a/node_modules/x/lib.wasm", bytes: data, in: home, created: Date(timeIntervalSince1970: 1_000))
        try put("Code/b/node_modules/x/lib.wasm", bytes: data, in: home, created: Date(timeIntervalSince1970: 2_000))

        let items = await DuplicateScanner(home: home).scan()
        #expect(items.isEmpty)
    }
}
