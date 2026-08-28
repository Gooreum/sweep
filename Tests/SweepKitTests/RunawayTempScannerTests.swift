import Testing
import Foundation
@testable import SweepKit

@Suite("RunawayTempScanner")
struct RunawayTempScannerTests {

    private static let oneMB = 1024 * 1024

    /// 샌드박스는 NSTemporaryDirectory() 아래에 만든다.
    /// 이 경로는 /private/var/folders 로 풀려 허용 루트 하위이므로
    /// 스캐너의 `isRemovable` 필터를 자연스럽게 통과한다.
    private func makeSandbox() throws -> URL {
        let dir = URL(filePath: NSTemporaryDirectory())
            .appending(path: "sweep-runaway-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func write(_ bytes: Int, to url: URL) throws {
        try Data(repeating: 0x41, count: bytes).write(to: url)
    }

    // MARK: - detail(growth:over:) 환산

    // TC-1
    @Test("3초간 5,000,000바이트 증가는 분당 100MB로 환산된다")
    func convertsGrowthToPerMinute() {
        // ByteCountFormatter의 .file은 10진(1MB = 1,000,000바이트)을 쓴다.
        // 5,000,000바이트/3초 × 60 = 100,000,000바이트/분 = 100 MB/분
        let text = RunawayTempScanner.detail(growth: 5_000_000, over: .seconds(3))

        #expect(text.contains("증가 중"))
        #expect(text.contains("100"))
        #expect(text.contains("MB"))
    }

    // TC-2
    @Test("증가량이 0이면 증가 없음으로 표시된다")
    func zeroGrowthIsIdle() {
        let text = RunawayTempScanner.detail(growth: 0, over: .seconds(3))
        #expect(text == "증가 없음 — 남겨진 임시 파일")
    }

    // TC-3
    @Test("크기가 줄어든 경우도 증가 없음으로 취급된다")
    func negativeGrowthIsIdle() {
        let text = RunawayTempScanner.detail(growth: -Int64(Self.oneMB), over: .seconds(3))
        #expect(text == "증가 없음 — 남겨진 임시 파일")
    }

    // TC-4
    @Test("간격이 0초여도 0으로 나누지 않는다")
    func zeroIntervalDoesNotDivideByZero() {
        let text = RunawayTempScanner.detail(growth: Int64(Self.oneMB), over: .seconds(0))
        #expect(text == "증가 중")
    }

    // MARK: - scan()

    // TC-5
    @Test("샘플링 도중 커지는 디렉토리는 caution으로 분류된다")
    func growingDirectoryIsCaution() async throws {
        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let target = root.appending(path: "growing")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try write(2 * Self.oneMB, to: target.appending(path: "base.bin"))

        let scanner = RunawayTempScanner(
            samplingInterval: .milliseconds(400),
            minimumSize: Int64(Self.oneMB),
            roots: [root])

        // 1차 샘플 직후 파일이 늘어나도록 병렬로 밀어넣는다
        async let scanned = scanner.scan()
        try await Task.sleep(for: .milliseconds(150))
        try write(3 * Self.oneMB, to: target.appending(path: "grown.bin"))

        let items = await scanned
        #expect(items.count == 1)
        #expect(items.first?.safety == .caution)
        #expect(items.first?.detail.contains("증가 중") == true)
    }

    // TC-6
    @Test("크기가 변하지 않는 디렉토리는 safe로 분류된다")
    func stableDirectoryIsSafe() async throws {
        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let target = root.appending(path: "stale")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try write(2 * Self.oneMB, to: target.appending(path: "old.bin"))

        let items = await RunawayTempScanner(
            samplingInterval: .milliseconds(200),
            minimumSize: Int64(Self.oneMB),
            roots: [root]).scan()

        #expect(items.count == 1)
        #expect(items.first?.safety == .safe)
        #expect(items.first?.detail.contains("증가 없음") == true)
    }

    // TC-7
    @Test("minimumSize 미만 항목은 1차 샘플에서 제외된다")
    func skipsItemsBelowMinimumSize() async throws {
        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let target = root.appending(path: "tiny")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try write(1024, to: target.appending(path: "small.bin"))

        let items = await RunawayTempScanner(
            samplingInterval: .milliseconds(200),
            minimumSize: Int64(100 * Self.oneMB),
            roots: [root]).scan()

        #expect(items.isEmpty)
    }

    // TC-8
    @Test("1차 샘플 이후 사라진 항목은 결과에서 빠진다")
    func dropsItemsThatVanish() async throws {
        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let target = root.appending(path: "vanishing")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try write(2 * Self.oneMB, to: target.appending(path: "doomed.bin"))

        let scanner = RunawayTempScanner(
            samplingInterval: .milliseconds(400),
            minimumSize: Int64(Self.oneMB),
            roots: [root])

        async let scanned = scanner.scan()
        try await Task.sleep(for: .milliseconds(150))
        try FileManager.default.removeItem(at: target)

        let items = await scanned
        #expect(items.isEmpty)
    }

    // TC-9 · TC-10
    @Test("기본 루트 스캔 결과가 관문을 통과하고 카테고리가 일관된다")
    func realRootsPassGateAndCategory() async {
        // 실제 /private/tmp·var/folders를 훑되 간격을 짧게 둬 테스트가 오래 걸리지 않게 한다
        let items = await RunawayTempScanner(samplingInterval: .milliseconds(200)).scan()

        #expect(items.allSatisfy { $0.category == .runawayTemp })
        for item in items {
            #expect(ProtectedPaths.isRemovable(item.url), "관문 미통과: \(item.url.path)")
        }
    }
}
