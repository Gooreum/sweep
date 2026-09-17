import Testing
import Foundation
@testable import SweepKit

/// `DirectorySize.summary(at:)` — 크기를 세던 순회에서 날짜까지 같이 얻는다.
///
/// 이 스위트의 핵심은 TC-4다. **디렉토리 mtime을 세면 안 된다.**
/// 예전에 그것 때문에 331일 묵은 캐시가 "오늘 쓴 것"으로 보여 검출이 통째로 실패했다.
@Suite("DirectorySize 요약")
struct DirectorySummaryTests {

    private func makeSandbox() throws -> URL {
        let dir = URL(filePath: NSTemporaryDirectory())
            .appending(path: "sweep-summary-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func write(_ bytes: Int, to url: URL, daysAgo: Int? = nil) throws {
        try Data(repeating: 0x41, count: bytes).write(to: url)
        if let daysAgo {
            let date = Date().addingTimeInterval(-Double(daysAgo) * 86_400)
            try FileManager.default.setAttributes([.modificationDate: date],
                                                  ofItemAtPath: url.path)
        }
    }

    // TC-2
    @Test("크기는 bytes(at:)와 같은 값을 준다")
    func sizeMatchesLegacyCall() throws {
        let dir = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: dir) }
        for name in ["a.bin", "b.bin", "c.bin"] {
            try write(4096, to: dir.appending(path: name))
        }

        let summary = DirectorySize.summary(at: dir)

        #expect(summary.bytes > 0)
        // TC-9도 같이 선다 — 래퍼가 본체와 갈라지면 여기서 잡힌다.
        #expect(summary.bytes == DirectorySize.bytes(at: dir))
    }

    // TC-3
    @Test("마지막 사용은 하위 파일 중 가장 최근 값이다")
    func newestModificationWins() throws {
        let dir = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: dir) }
        try write(64, to: dir.appending(path: "old.bin"), daysAgo: 10)
        try write(64, to: dir.appending(path: "newest.bin"), daysAgo: 3)
        try write(64, to: dir.appending(path: "oldest.bin"), daysAgo: 30)

        let used = try #require(DirectorySize.summary(at: dir).dates.lastUsed)

        let days = Date().timeIntervalSince(used) / 86_400
        #expect(days > 2.5 && days < 3.5, "3일 전 파일이 아니라 \(days)일 전 값이 나왔다")
    }

    // TC-4
    @Test("디렉토리 mtime이 오늘이어도 파일이 낡았으면 낡은 것이다")
    func directoryModificationIsIgnored() throws {
        let dir = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: dir) }
        let inner = dir.appending(path: "sub")
        try FileManager.default.createDirectory(at: inner, withIntermediateDirectories: true)
        try write(64, to: inner.appending(path: "stale.bin"), daysAgo: 100)
        // 하위가 추가·삭제되기만 해도 이렇게 된다. 여기에 속으면 검출이 통째로 죽는다.
        try FileManager.default.setAttributes([.modificationDate: Date()],
                                              ofItemAtPath: inner.path)

        let used = try #require(DirectorySize.summary(at: dir).dates.lastUsed)

        let days = Date().timeIntervalSince(used) / 86_400
        #expect(days > 99, "디렉토리 mtime에 속아 \(days)일 전으로 봤다")
    }

    // TC-5
    @Test("빈 폴더는 마지막 사용이 없고 만든 날은 있다")
    func emptyDirectory() throws {
        let dir = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: dir) }

        let summary = DirectorySize.summary(at: dir)

        #expect(summary.bytes == 0)
        // 셀 파일이 없으면 "마지막 사용"을 지어내지 않는다.
        #expect(summary.dates.lastUsed == nil)
        #expect(summary.dates.created != nil)
    }

    // TC-6
    @Test("일반 파일 하나는 자기 크기와 자기 mtime을 준다")
    func singleFile() throws {
        let dir = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appending(path: "solo.bin")
        try write(4096, to: file, daysAgo: 7)

        let summary = DirectorySize.summary(at: file)

        #expect(summary.bytes >= 4096)
        let used = try #require(summary.dates.lastUsed)
        let days = Date().timeIntervalSince(used) / 86_400
        #expect(days > 6.5 && days < 7.5)
    }

    // TC-7
    @Test("없는 경로는 빈 요약이다")
    func missingPath() {
        let ghost = URL(filePath: "/private/tmp/sweep-missing-\(UUID().uuidString)")

        #expect(DirectorySize.summary(at: ghost) == .empty)
    }

    // TC-8
    @Test("심볼릭 링크는 따라가지 않는다")
    func symbolicLink() throws {
        let dir = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: dir) }
        let target = dir.appending(path: "target")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try write(8192, to: target.appending(path: "big.bin"))
        let link = dir.appending(path: "link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        let summary = DirectorySize.summary(at: link)

        // 따라가면 대상 용량이 중복 집계되고 허용 루트 밖 용량이 섞인다.
        #expect(summary == .empty)
    }
}
