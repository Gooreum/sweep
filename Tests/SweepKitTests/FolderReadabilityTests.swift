import Testing
import Foundation
@testable import SweepKit

@Suite("FolderReadability")
struct FolderReadabilityTests {

    private let fm = FileManager.default

    private func makeBase() throws -> (base: URL, cleanup: () -> Void) {
        let base = URL(filePath: NSTemporaryDirectory())
            .appending(path: "sweep-readable-\(UUID().uuidString)")
        try fm.createDirectory(at: base, withIntermediateDirectories: true)
        return (base, {
            // 막아 둔 폴더는 되돌려야 지워진다.
            if let items = try? FileManager.default.contentsOfDirectory(atPath: base.path) {
                for name in items {
                    try? FileManager.default.setAttributes([.posixPermissions: 0o755],
                                                           ofItemAtPath: base.appending(path: name).path)
                }
            }
            try? FileManager.default.removeItem(at: base)
        })
    }

    // TC-1
    @Test("읽을 수 있는 폴더는 readable이다")
    func readableFolder() throws {
        let (base, cleanup) = try makeBase()
        defer { cleanup() }
        let folder = base.appending(path: "open")
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)

        #expect(FolderReadability.check(folder) == .readable)
        #expect(!FolderReadability.check(folder).needsAttention)
    }

    // TC-2
    @Test("권한이 막힌 폴더는 denied다")
    func blockedFolderIsDenied() throws {
        let (base, cleanup) = try makeBase()
        defer { cleanup() }
        let folder = base.appending(path: "blocked")
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        // TCC는 테스트에서 재현할 수 없지만, `contentsOfDirectory`가 던지는 것은 같다.
        try fm.setAttributes([.posixPermissions: 0o000], ofItemAtPath: folder.path)

        #expect(FolderReadability.check(folder) == .denied)
        // 이 상태만 사용자에게 알린다 — 빈 폴더와 구분되는 지점이다.
        #expect(FolderReadability.check(folder).needsAttention)
    }

    // TC-3
    @Test("없는 경로는 missing이고 알릴 일이 아니다")
    func missingFolder() throws {
        let (base, cleanup) = try makeBase()
        defer { cleanup() }

        let absent = base.appending(path: "없는폴더")
        #expect(FolderReadability.check(absent) == .missing)
        // 그 도구를 안 쓰는 것뿐이므로 경고하지 않는다.
        #expect(!FolderReadability.check(absent).needsAttention)
    }

    // TC-4
    @Test("파일을 가리키면 폴더가 아니므로 missing이다")
    func fileIsNotAFolder() throws {
        let (base, cleanup) = try makeBase()
        defer { cleanup() }
        let file = base.appending(path: "파일.txt")
        try Data("hello".utf8).write(to: file)

        #expect(FolderReadability.check(file) == .missing)
    }

    // TC-5
    @Test("빈 폴더와 막힌 폴더를 구분한다")
    func emptyIsNotDenied() throws {
        let (base, cleanup) = try makeBase()
        defer { cleanup() }
        let empty = base.appending(path: "empty")
        let blocked = base.appending(path: "blocked")
        try fm.createDirectory(at: empty, withIntermediateDirectories: true)
        try fm.createDirectory(at: blocked, withIntermediateDirectories: true)
        try fm.setAttributes([.posixPermissions: 0o000], ofItemAtPath: blocked.path)

        // 고치기 전에는 둘 다 빈 배열이라 화면에서 구분되지 않았다.
        #expect(FolderReadability.check(empty) == .readable)
        #expect(FolderReadability.check(blocked) == .denied)
    }

    // TC-6
    @Test("보는 곳 전체의 상태를 한 번에 만든다")
    func buildsReadabilityMap() throws {
        let (base, cleanup) = try makeBase()
        defer { cleanup() }
        let open = base.appending(path: "open")
        let blocked = base.appending(path: "blocked")
        try fm.createDirectory(at: open, withIntermediateDirectories: true)
        try fm.createDirectory(at: blocked, withIntermediateDirectories: true)
        try fm.setAttributes([.posixPermissions: 0o000], ofItemAtPath: blocked.path)

        let scopes = [
            CleanupScope(url: open, label: "~/open", detail: "열림"),
            CleanupScope(url: blocked, label: "~/blocked", detail: "막힘"),
        ]
        let map = CleanupScope.readabilityMap(of: scopes)

        #expect(map[open.path] == .readable)
        #expect(map[blocked.path] == .denied)
    }

    // TC-7
    @Test("실제 보는 곳 목록이 전부 판정된다")
    func realScopesAreAllJudged() {
        let map = CleanupScope.readabilityMap(of: CleanupScope.all)
        #expect(map.count == CleanupScope.all.count)
        // 막힌 곳이 있으면 화면이 알려야 한다 — 없다고 단정하지는 않는다.
        #expect(map.values.allSatisfy { [.readable, .denied, .missing].contains($0) })
    }
}
