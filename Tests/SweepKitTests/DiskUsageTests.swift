import Testing
import Foundation
import CoreGraphics
@testable import SweepKit

@Suite("DiskUsageTree")
struct DiskUsageTreeTests {

    private var fm: FileManager { .default }
    private static let oneMB = 1024 * 1024

    private func makeSandbox() throws -> URL {
        let dir = URL(filePath: NSTemporaryDirectory())
            .appending(path: "sweep-tree-\(UUID().uuidString)")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func write(_ megabytes: Int, to url: URL) throws {
        try fm.createDirectory(at: url.deletingLastPathComponent(),
                               withIntermediateDirectories: true)
        try Data(repeating: 0x41, count: megabytes * Self.oneMB).write(to: url)
    }

    // TC-1
    @Test("루트 크기가 하위 전체 합계와 일치한다")
    func rootSizeMatchesTotal() throws {
        let root = try makeSandbox()
        defer { try? fm.removeItem(at: root) }
        try write(3, to: root.appending(path: "a/big.bin"))
        try write(2, to: root.appending(path: "b/mid.bin"))

        let tree = DiskUsageTree.build(at: root, minimumSize: Int64(Self.oneMB))

        #expect(tree.size >= Int64(5 * Self.oneMB))
        #expect(tree.size < Int64(6 * Self.oneMB))
        #expect(tree.children.map(\.name).sorted() == ["a", "b"])
        // 자식 합계가 루트를 넘지 않는다
        #expect(tree.children.reduce(0) { $0 + $1.size } <= tree.size)
    }

    // TC-2
    @Test("maxDepth로 깊이가 제한된다")
    func maxDepthLimitsRecursion() throws {
        let root = try makeSandbox()
        defer { try? fm.removeItem(at: root) }
        try write(3, to: root.appending(path: "a/b/deep.bin"))

        let tree = DiskUsageTree.build(at: root, maxDepth: 1, minimumSize: Int64(Self.oneMB))

        #expect(tree.children.count == 1)
        #expect(tree.children.first?.name == "a")
        #expect(tree.children.first?.children.isEmpty == true, "maxDepth를 넘어 내려갔다")
    }

    // TC-3
    @Test("작은 자식은 목록에서 빠지지만 부모 크기에는 남는다")
    func smallChildrenArePrunedButCounted() throws {
        let root = try makeSandbox()
        defer { try? fm.removeItem(at: root) }
        try write(5, to: root.appending(path: "big/large.bin"))
        try write(1, to: root.appending(path: "tiny/small.bin"))

        let tree = DiskUsageTree.build(at: root, minimumSize: Int64(3 * Self.oneMB))

        #expect(tree.children.map(\.name) == ["big"])
        // 잘려나간 tiny도 합계에는 포함되어야 면적 비교가 성립한다
        #expect(tree.size >= Int64(6 * Self.oneMB))
    }

    // TC-4
    @Test("존재하지 않는 경로는 크기 0 노드가 된다")
    func missingPathYieldsEmptyNode() {
        let ghost = URL(filePath: "/private/tmp/sweep-tree-ghost-\(UUID().uuidString)")
        let tree = DiskUsageTree.build(at: ghost)

        #expect(tree.size == 0)
        #expect(tree.children.isEmpty)
    }

    // TC-5
    @Test("노드가 이름과 사람이 읽는 크기를 제공한다")
    func nodeExposesDisplayInfo() {
        let node = DiskUsageNode(url: URL(filePath: "/private/tmp/things"),
                                 size: 5_000_000_000)
        #expect(node.name == "things")
        #expect(node.formattedSize.contains("GB"))
        #expect(!node.formattedSize.contains("5000000000"))
    }

    // MARK: - 단일 순회 재작성 (Phase 1)

    // TC-4
    @Test("깊이 제한을 넘는 파일도 부모 크기에 반영된다")
    func deepFilesStillCountTowardParentSize() throws {
        let root = try makeSandbox()
        defer { try? fm.removeItem(at: root) }
        try write(4, to: root.appending(path: "a/b/c/deep.bin"))

        let tree = DiskUsageTree.build(at: root, maxDepth: 1,
                                       minimumSize: Int64(Self.oneMB))

        // children은 한 겹만 있지만 크기는 3단계 아래 파일까지 합산돼야 한다
        #expect(tree.children.count == 1)
        #expect(tree.children.first?.children.isEmpty == true)
        #expect(tree.size >= Int64(4 * Self.oneMB))
    }

    // TC-5
    @Test("항목을 정확히 한 번씩만 본다")
    func everyEntryIsVisitedOnce() throws {
        let root = try makeSandbox()
        defer { try? fm.removeItem(at: root) }
        // 디렉토리 3개 + 파일 3개 = 6개 (루트 자신 포함하면 7개)
        try write(2, to: root.appending(path: "a/x.bin"))
        try write(2, to: root.appending(path: "b/y.bin"))
        try write(2, to: root.appending(path: "c/z.bin"))

        let counter = VisitCounter()
        _ = DiskUsageTree.build(at: root, maxDepth: 4,
                                minimumSize: Int64(Self.oneMB),
                                onEntryScanned: { counter.increment() })

        // 루트 1 + 디렉토리 3 + 파일 3
        #expect(counter.value == 7, "방문 횟수가 항목 수와 다르다: \(counter.value)")
    }

    // TC-6
    @Test("심볼릭 링크 대상 용량이 합계에 섞이지 않는다")
    func symlinkTargetsAreNotCounted() throws {
        let root = try makeSandbox()
        let outside = try makeSandbox()
        defer {
            try? fm.removeItem(at: root)
            try? fm.removeItem(at: outside)
        }
        try write(2, to: root.appending(path: "real.bin"))
        let fat = outside.appending(path: "fat.bin")
        try write(8, to: fat)
        try fm.createSymbolicLink(at: root.appending(path: "link.bin"), withDestinationURL: fat)

        let tree = DiskUsageTree.build(at: root, minimumSize: 1)

        #expect(tree.size >= Int64(2 * Self.oneMB))
        #expect(tree.size < Int64(3 * Self.oneMB), "링크를 따라가 8MB가 섞였다")
    }

    // MARK: - 읽을 수 있었는가 (범위 확대)

    /// 권한을 되돌려 놓지 않으면 임시 디렉토리가 지워지지 않는다.
    private func unlock(_ url: URL) {
        try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }

    // TC-2
    @Test("못 읽는 디렉토리는 0바이트가 아니라 읽을 수 없음으로 표시된다")
    func unreadableDirectoryIsMarked() throws {
        let root = try makeSandbox()
        let locked = root.appending(path: "잠긴폴더")
        defer { unlock(locked); try? fm.removeItem(at: root) }

        try write(2, to: locked.appending(path: "안보임.bin"))
        try fm.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)

        let tree = DiskUsageTree.build(at: root, minimumSize: 1)
        let node = try #require(tree.children.first { $0.name == "잠긴폴더" },
                                "잠긴 폴더가 트리에 없다")

        // 0 KB라고 말하면 거짓말이다 — 안에 2MB가 있다
        #expect(node.isReadable == false)
        #expect(node.size == 0)
    }

    // TC-3
    @Test("빈 디렉토리는 읽을 수 있는 0바이트다")
    func emptyDirectoryStaysReadable() throws {
        let root = try makeSandbox()
        defer { try? fm.removeItem(at: root) }
        let empty = root.appending(path: "빈폴더")
        try fm.createDirectory(at: empty, withIntermediateDirectories: true)

        let tree = DiskUsageTree.build(at: empty, minimumSize: 1)

        // 빈 것과 못 읽는 것은 둘 다 0바이트다. 크기만으로는 구분되지 않는다.
        #expect(tree.isReadable == true)
        #expect(tree.size == 0)
    }

    // TC-4
    @Test("읽을 수 있는 디렉토리는 크기가 그대로 잡힌다")
    func readableDirectoryKeepsSize() throws {
        let root = try makeSandbox()
        defer { try? fm.removeItem(at: root) }
        try write(2, to: root.appending(path: "a.bin"))

        let tree = DiskUsageTree.build(at: root, minimumSize: 1)

        #expect(tree.isReadable == true)
        #expect(tree.size >= Int64(2 * Self.oneMB))
    }

    // TC-5
    @Test("못 읽는 자식이 있어도 부모는 읽을 수 있다")
    func parentStaysReadableWithLockedChild() throws {
        let root = try makeSandbox()
        let locked = root.appending(path: "잠긴폴더")
        defer { unlock(locked); try? fm.removeItem(at: root) }

        try write(2, to: root.appending(path: "보이는.bin"))
        try write(2, to: locked.appending(path: "안보임.bin"))
        try fm.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)

        let tree = DiskUsageTree.build(at: root, minimumSize: 1)

        // 못 읽는 것은 그 폴더 하나지 부모 전체가 아니다
        #expect(tree.isReadable == true)
        #expect(tree.size >= Int64(2 * Self.oneMB))
        #expect(tree.children.first { $0.name == "잠긴폴더" }?.isReadable == false)
        #expect(tree.children.first { $0.name == "보이는.bin" }?.isReadable == true)
    }
}

/// 방문 횟수를 세는 잠금 카운터. 재귀가 여러 스레드를 쓰지는 않지만
/// 콜백이 `@Sendable`이라 참조 타입이 필요하다.
private final class VisitCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func increment() {
        lock.lock(); defer { lock.unlock() }
        count += 1
    }

    var value: Int {
        lock.lock(); defer { lock.unlock() }
        return count
    }
}

@Suite("막대 목록")
struct BarListTests {

    private func node(_ name: String, _ size: Int64) -> DiskUsageNode {
        DiskUsageNode(url: URL(filePath: "/private/tmp/\(name)"), size: size)
    }

    // TC-3
    @Test("막대 비율이 가장 큰 항목 기준으로 계산된다")
    func ratioIsRelativeToLargest() {
        let largest: Int64 = 1_000

        #expect(node("a", 1_000).barRatio(largest: largest) == 1.0)
        #expect(node("b", 500).barRatio(largest: largest) == 0.5)
        #expect(node("c", 1).barRatio(largest: largest) == 0.001)
    }

    // TC-4
    @Test("최대값이 0이면 0으로 나누지 않는다")
    func zeroLargestYieldsZero() {
        #expect(node("a", 0).barRatio(largest: 0) == 0)
        #expect(node("b", 100).barRatio(largest: 0) == 0)
    }

    @Test("비율이 0~1을 벗어나지 않는다")
    func ratioIsClamped() {
        // 최대값보다 큰 값이 들어와도(정렬이 어긋나도) 1을 넘지 않는다
        #expect(node("over", 5_000).barRatio(largest: 1_000) == 1.0)
    }

    // TC-5
    @Test("children이 크기 내림차순이라 첫 원소를 막대 기준으로 쓸 수 있다")
    func childrenAreSortedDescending() throws {
        let fm = FileManager.default
        let root = URL(filePath: NSTemporaryDirectory())
            .appending(path: "sweep-bar-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: root) }

        for (name, mb) in [("small", 2), ("big", 6), ("mid", 4)] {
            let url = root.appending(path: "\(name)/f.bin")
            try fm.createDirectory(at: url.deletingLastPathComponent(),
                                   withIntermediateDirectories: true)
            try Data(repeating: 0x41, count: mb * 1024 * 1024).write(to: url)
        }

        let tree = DiskUsageTree.build(at: root, maxDepth: 2, minimumSize: 1024 * 1024)

        #expect(tree.children.map(\.name) == ["big", "mid", "small"])
        #expect(tree.children.first?.size == tree.children.map(\.size).max())
    }
}

/// 전체 디스크 접근이 없을 때 앱 데이터 구역을 **열지 않는다.**
///
/// 여는 순간 그 앱마다 "다른 앱의 데이터" 프롬프트가 뜬다 — 열기 전에 막아야 한다.
@Suite("앱 데이터 구역 회피")
struct DiskUsageAppDataTests {

    private let fm = FileManager.default

    /// 진짜 홈을 건드리지 않는 가짜 홈. 보호 구역과 그 밖을 함께 만든다.
    private func makeHome() throws -> (home: URL, cleanup: () -> Void) {
        let home = URL(filePath: NSTemporaryDirectory())
            .appending(path: "sweep-appdata-\(UUID().uuidString)")
        for relative in ["Library/Containers/com.example.app",
                         "Library/Application Support/Example",
                         "Library/Caches/Example"] {
            try fm.createDirectory(at: home.appending(path: relative),
                                   withIntermediateDirectories: true)
        }
        // 크기를 만들어 둔다 — 0바이트면 "못 읽음"과 구분이 안 된다.
        for relative in ["Library/Containers/com.example.app/big.bin",
                         "Library/Application Support/Example/big.bin",
                         "Library/Caches/Example/big.bin"] {
            try Data(repeating: 0, count: 2_000_000).write(to: home.appending(path: relative))
        }
        return (home, { try? self.fm.removeItem(at: home) })
    }

    private func find(_ name: String, in node: DiskUsageNode) -> DiskUsageNode? {
        if node.name == name { return node }
        for child in node.children {
            if let found = find(name, in: child) { return found }
        }
        return nil
    }

    // TC-1
    @Test("접근이 없으면 앱 폴더를 못 읽는 것으로 표시한다")
    func blocksAppDataWhenDenied() throws {
        let (home, cleanup) = try makeHome()
        defer { cleanup() }

        let tree = DiskUsageTree.build(at: home.appending(path: "Library"),
                                       minimumSize: 0,
                                       canReadAppData: false, appDataHome: home)

        let app = try #require(find("com.example.app", in: tree))
        #expect(!app.isReadable)
        #expect(app.size == 0)
    }

    // TC-2
    @Test("접근이 있으면 평소대로 내려간다")
    func readsAppDataWhenGranted() throws {
        let (home, cleanup) = try makeHome()
        defer { cleanup() }

        let tree = DiskUsageTree.build(at: home.appending(path: "Library"),
                                       minimumSize: 0,
                                       canReadAppData: true, appDataHome: home)

        let app = try #require(find("com.example.app", in: tree))
        #expect(app.isReadable)
        #expect(app.size >= 2_000_000)
    }

    // TC-3
    @Test("구역 자신은 읽을 수 있다")
    func rootItselfStaysReadable() throws {
        let (home, cleanup) = try makeHome()
        defer { cleanup() }

        let tree = DiskUsageTree.build(at: home.appending(path: "Library"),
                                       minimumSize: 0,
                                       canReadAppData: false, appDataHome: home)

        // 목록에는 보여야 한다 — 그 자체를 여는 것은 묻지 않는다.
        let containers = try #require(find("Containers", in: tree))
        #expect(containers.isReadable)
    }

    // TC-4
    @Test("캐시는 접근 여부와 무관하게 잡힌다")
    func cachesUnaffected() throws {
        let (home, cleanup) = try makeHome()
        defer { cleanup() }

        for granted in [true, false] {
            let tree = DiskUsageTree.build(at: home.appending(path: "Library"),
                                           minimumSize: 0,
                                           canReadAppData: granted, appDataHome: home)
            let cachesRoot = try #require(find("Caches", in: tree))
            let caches = try #require(find("Example", in: cachesRoot))
            #expect(caches.size >= 2_000_000, "캐시가 가려졌다 (granted: \(granted))")
        }
    }
}

/// 세기와 집계가 **같은 곳을 본다.**
///
/// `build`가 안 내려가는데 `countEntries`만 세면 분모가 커져 퍼센트가 100에 닿지 못한다.
/// 링크 232개 때문에 99%에서 멈췄던 것과 같은 함정이다.
@Suite("세기와 집계가 같은 범위")
struct CountMatchesBuildTests {

    private let fm = FileManager.default

    private func makeHome() throws -> (URL, () -> Void) {
        let home = URL(filePath: NSTemporaryDirectory())
            .appending(path: "sweep-count-\(UUID().uuidString)")
        for relative in ["Library/Containers/com.example.app/deep/deeper",
                         "Library/Caches/Example"] {
            try fm.createDirectory(at: home.appending(path: relative),
                                   withIntermediateDirectories: true)
        }
        return (home, { try? self.fm.removeItem(at: home) })
    }

    // TC-1
    @Test("접근이 없으면 세기도 앱 데이터 안으로 안 들어간다")
    func countSkipsAppDataWhenDenied() throws {
        let (home, cleanup) = try makeHome()
        defer { cleanup() }
        let library = home.appending(path: "Library")

        let denied = DiskUsageTree.countEntries(at: library,
                                                canReadAppData: false, appDataHome: home)
        let granted = DiskUsageTree.countEntries(at: library,
                                                 canReadAppData: true, appDataHome: home)

        // 막았으면 `com.example.app` 아래 두 층을 세지 않는다.
        #expect(denied < granted)
    }

    // TC-2
    @Test("구역 자신은 세기에 들어간다")
    func countIncludesRootItself() throws {
        let (home, cleanup) = try makeHome()
        defer { cleanup() }

        let denied = DiskUsageTree.countEntries(at: home.appending(path: "Library"),
                                                canReadAppData: false, appDataHome: home)

        // `Containers`와 그 안의 `com.example.app`까지는 목록에 보인다.
        #expect(denied >= 4)
    }
}
