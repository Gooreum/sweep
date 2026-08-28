import Testing
import Foundation
@testable import SweepKit

@Suite("XcodeScanner")
struct XcodeScannerTests {

    /// 가짜 홈 트리. Xcode 설치 여부와 무관하게 결과가 결정되도록 한다.
    private func makeFakeHome() throws -> URL {
        let home = URL(filePath: NSTemporaryDirectory())
            .appending(path: "sweep-xcode-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        return home
    }

    private func write(_ bytes: Int, at url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 0x41, count: bytes).write(to: url)
    }

    private static let oneMB = 1024 * 1024

    // TC-1
    @Test("실제 홈 스캔이 던지지 않고 xcode 카테고리 항목만 반환한다")
    func scansRealHomeWithoutThrowing() async {
        let items = await XcodeScanner().scan()
        #expect(items.allSatisfy { $0.category == .xcode })
    }

    // TC-2
    @Test("크기가 0인 항목은 결과에 포함되지 않는다")
    func excludesZeroSizedTargets() async {
        let items = await XcodeScanner().scan()
        #expect(items.allSatisfy { $0.size > 0 })
    }

    // TC-3
    @Test("반환된 모든 항목이 삭제 관문을 통과한다")
    func allItemsPassSafetyGate() async {
        let items = await XcodeScanner().scan()
        for item in items {
            #expect(ProtectedPaths.isRemovable(item.url), "관문 미통과: \(item.url.path)")
        }
    }

    // TC-4
    @Test("Xcode가 없는 빈 홈에서는 빈 배열을 반환한다")
    func emptyHomeYieldsNothing() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        let items = await XcodeScanner(home: home).scan()
        #expect(items.isEmpty)
    }

    // TC-5
    @Test("Archives는 danger이고 기본 선택되지 않는다")
    func archivesAreDangerAndUnchecked() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        try write(Self.oneMB, at: home.appending(
            path: "Library/Developer/Xcode/Archives/2026-08-28/App.xcarchive/payload.bin"))

        let items = await XcodeScanner(home: home).scan()
        let archives = items.filter { $0.url.path.contains("/Archives/") }

        #expect(archives.count == 1)
        #expect(archives.first?.safety == .danger)
        #expect(archives.first?.isSelectedByDefault == false)
    }

    // TC-6
    @Test("DerivedData는 safe이며 재생성 안내 문구를 갖는다")
    func derivedDataIsSafeWithDetail() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        try write(Self.oneMB, at: home.appending(
            path: "Library/Developer/Xcode/DerivedData/App-abc/Build/out.o"))

        let items = await XcodeScanner(home: home).scan()
        #expect(items.count == 1)
        #expect(items.first?.safety == .safe)
        #expect(items.first?.detail == "빌드하면 다시 생성됩니다")
        #expect(items.first?.isSelectedByDefault == true)
    }

    // TC-7
    @Test("모든 항목이 사용자용 설명을 갖는다")
    func everyItemHasDetail() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        try write(Self.oneMB, at: home.appending(
            path: "Library/Developer/Xcode/DerivedData/App-abc/out.o"))
        try write(Self.oneMB, at: home.appending(
            path: "Library/Developer/CoreSimulator/Caches/dyld/cache.bin"))
        try write(Self.oneMB, at: home.appending(
            path: "Library/Developer/DVTDownloads/component.dmg"))

        let items = await XcodeScanner(home: home).scan()
        #expect(items.count == 3)
        #expect(items.allSatisfy { !$0.detail.isEmpty })
    }

    // TC-8
    @Test("DerivedData 하위 프로젝트가 각각 별도 항목으로 펼쳐진다")
    func expandsDerivedDataPerProject() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        let derived = home.appending(path: "Library/Developer/Xcode/DerivedData")
        try write(Self.oneMB, at: derived.appending(path: "Alpha-aaa/Build/a.o"))
        try write(2 * Self.oneMB, at: derived.appending(path: "Beta-bbb/Build/b.o"))

        let items = await XcodeScanner(home: home).scan()
        let byName = Dictionary(uniqueKeysWithValues: items.map { ($0.displayName, $0) })

        #expect(items.count == 2)                       // 디렉토리 자체가 아니라 프로젝트별로
        #expect(byName["Alpha-aaa"]?.size ?? 0 >= Int64(Self.oneMB))
        #expect(byName["Beta-bbb"]?.size ?? 0 >= Int64(2 * Self.oneMB))
        #expect(byName["Beta-bbb"]!.size > byName["Alpha-aaa"]!.size)
    }
}
