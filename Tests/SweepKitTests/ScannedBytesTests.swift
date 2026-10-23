import Testing
import Foundation
@testable import SweepKit

/// 진행률의 분자. 폴더마다 알린 바이트를 다 더하면 루트 크기와 같아야 퍼센트가 정확하다.
@Suite("ScannedBytes")
struct ScannedBytesTests {

    private var fm: FileManager { .default }
    private static let oneMB = 1024 * 1024

    private func makeSandbox() throws -> URL {
        let dir = URL(filePath: NSTemporaryDirectory())
            .appending(path: "sweep-bytes-\(UUID().uuidString)")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func write(_ bytes: Int, to url: URL) throws {
        try fm.createDirectory(at: url.deletingLastPathComponent(),
                               withIntermediateDirectories: true)
        try Data(repeating: 0x41, count: bytes).write(to: url)
    }

    @Test("알린 바이트를 다 더하면 루트 크기다")
    func reportedBytesSumToRoot() throws {
        let root = try makeSandbox()
        defer { try? fm.removeItem(at: root) }
        try write(Self.oneMB, to: root.appending(path: "a/b/deep.bin"))
        try write(Self.oneMB, to: root.appending(path: "c.bin"))
        for i in 0..<6 { try write(1024, to: root.appending(path: "d\(i)/f.bin")) }

        let sum = Bytes()
        let tree = DiskUsageTree.build(at: root, maxDepth: 1, minimumSize: 1,
                                       onBytesScanned: { sum.add($0) })

        #expect(sum.value == tree.size)
        #expect(tree.size >= Int64(2 * Self.oneMB))
    }

    @Test("링크 대상은 알리지도 크기에 넣지도 않는다")
    func symlinksAreNotReported() throws {
        let root = try makeSandbox()
        let outside = try makeSandbox()
        defer {
            try? fm.removeItem(at: root)
            try? fm.removeItem(at: outside)
        }
        try write(4 * Self.oneMB, to: outside.appending(path: "fat.bin"))
        try fm.createSymbolicLink(at: root.appending(path: "file-link"),
                                  withDestinationURL: outside.appending(path: "fat.bin"))
        try fm.createSymbolicLink(at: root.appending(path: "dir-link"), withDestinationURL: outside)

        let sum = Bytes()
        let tree = DiskUsageTree.build(at: root, maxDepth: 4, minimumSize: 1,
                                       onBytesScanned: { sum.add($0) })

        #expect(tree.size == 0, "링크 대상 용량이 합계에 들어갔다: \(tree.size)")
        #expect(sum.value == 0)
    }

    @Test("읽을 수 없는 폴더는 모른다고 남기고 나머지는 정확히 센다")
    func unreadableFolderIsKept() throws {
        let root = try makeSandbox()
        let locked = root.appending(path: "locked")
        defer {
            // 권한을 되돌려야 지울 수 있다
            try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path)
            try? fm.removeItem(at: root)
        }
        try write(Self.oneMB, to: root.appending(path: "open.bin"))
        try write(Self.oneMB, to: locked.appending(path: "inside.bin"))
        try fm.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)

        let sum = Bytes()
        let tree = DiskUsageTree.build(at: root, maxDepth: 4, minimumSize: Int64(Self.oneMB),
                                       onBytesScanned: { sum.add($0) })

        #expect(tree.children.first { $0.name == "locked" }?.isReadable == false)
        #expect(sum.value == tree.size)
    }

    @Test("취소하면 다 읽지 않고 멈춘다")
    func stopsWhenCancelled() throws {
        let root = try makeSandbox()
        defer { try? fm.removeItem(at: root) }
        for i in 0..<5 { try write(Self.oneMB, to: root.appending(path: "d\(i)/f.bin")) }

        let full = DiskUsageTree.build(at: root, minimumSize: 1)
        let stopped = DiskUsageTree.build(at: root, minimumSize: 1, isCancelled: { true })

        #expect(stopped.size < full.size)
    }

    @Test("여러 스레드로 나눠 재도 한 스레드로 잰 것과 트리가 같다")
    func parallelMatchesSequential() throws {
        let root = try makeSandbox()
        defer { try? fm.removeItem(at: root) }
        for i in 0..<8 {
            for j in 0..<4 {
                try write((i + 1) * (j + 1) * 100_000, to: root.appending(path: "d\(i)/e\(j)/f.bin"))
            }
        }

        let tree = DiskUsageTree.build(at: root, maxDepth: 3, minimumSize: 1)
        let flat = (0..<8).map { i in
            DiskUsageTree.build(at: root.appending(path: "d\(i)", directoryHint: .isDirectory),
                                maxDepth: 2, minimumSize: 1)
        }

        #expect(tree.size == flat.reduce(0) { $0 + $1.size })
        #expect(tree.children.map(\.size) == flat.map(\.size).sorted(by: >))
    }
}

/// 여러 스레드에서 오는 바이트를 모은다.
private final class Bytes: @unchecked Sendable {
    private let lock = NSLock()
    private var total: Int64 = 0
    func add(_ amount: Int64) { lock.lock(); total += amount; lock.unlock() }
    var value: Int64 { lock.lock(); defer { lock.unlock() }; return total }
}
