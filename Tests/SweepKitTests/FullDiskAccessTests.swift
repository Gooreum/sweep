import Foundation
import Testing
@testable import SweepKit

/// 전체 디스크 접근 판정.
///
/// 실제 전체 디스크 접근을 테스트에서 켜고 끌 수는 없다. **기전**(보호된 파일을
/// 열어 한 바이트 읽어 보기)을 임시 파일로 검증한다.
@Suite("전체 디스크 접근 판정", .serialized)
struct FullDiskAccessTests {

    private func temporaryFile(bytes: String, permissions: Int? = nil) throws -> (URL, () -> Void) {
        let base = URL(filePath: NSTemporaryDirectory())
            .appending(path: "sweep-fda-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let file = base.appending(path: "probe.db")
        try Data(bytes.utf8).write(to: file)
        if let permissions {
            try FileManager.default.setAttributes([.posixPermissions: permissions],
                                                  ofItemAtPath: file.path)
        }
        return (file, {
            try? FileManager.default.setAttributes([.posixPermissions: 0o644],
                                                   ofItemAtPath: file.path)
            try? FileManager.default.removeItem(at: base)
        })
    }

    // TC-1
    @Test("읽을 수 있는 파일이면 참이다")
    func readableFile() throws {
        let (file, cleanup) = try temporaryFile(bytes: "sqlite")
        defer { cleanup() }

        #expect(FullDiskAccess.canRead(file))
    }

    // TC-2
    @Test("없는 경로는 거짓이다")
    func missingFile() {
        #expect(!FullDiskAccess.canRead(URL(filePath: "/sweep-없는파일-9E3A1C.db")))
    }

    // TC-3
    @Test("권한이 막힌 파일은 거짓이다")
    func blockedFile() throws {
        let (file, cleanup) = try temporaryFile(bytes: "sqlite", permissions: 0o000)
        defer { cleanup() }

        // TCC로 막힌 것과 같은 자리에서 갈린다 — 열리지 않는다.
        #expect(!FullDiskAccess.canRead(file))
    }

    // TC-4
    @Test("빈 파일도 열렸으면 참이다")
    func emptyFile() throws {
        let (file, cleanup) = try temporaryFile(bytes: "")
        defer { cleanup() }

        // 읽을 내용이 없는 것과 못 읽는 것은 다르다. `read`가 nil을 주지 않으면 통과다.
        #expect(FullDiskAccess.canRead(file))
    }

    // TC-5
    @Test("재는 대상이 TCC 데이터베이스다")
    func probePointsAtTCC() {
        let components = FullDiskAccess.probe.pathComponents

        // 전체 디스크 접근이 있어야만 열리는 파일이어야 판정이 성립한다.
        #expect(components.suffix(2) == ["com.apple.TCC", "TCC.db"])
        #expect(FullDiskAccess.probe.path.hasPrefix(Sandbox.userHome.path))
    }
}
