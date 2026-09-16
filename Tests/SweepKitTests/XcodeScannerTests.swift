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

    // TC-9
    @Test("시뮬레이터 기기가 기기별 항목으로 펼쳐진다")
    func expandsSimulatorDevicesPerDevice() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        let devices = home.appending(path: "Library/Developer/CoreSimulator/Devices")
        try write(Self.oneMB, at: devices.appending(path: "AAAA-1111/data/app.bin"))
        try write(2 * Self.oneMB, at: devices.appending(path: "BBBB-2222/data/app.bin"))

        let items = await XcodeScanner(home: home).scan()
        let byName = Dictionary(uniqueKeysWithValues: items.map { ($0.displayName, $0) })

        #expect(items.count == 2)
        #expect(byName["AAAA-1111"]?.size ?? 0 >= Int64(Self.oneMB))
        #expect(byName["BBBB-2222"]?.size ?? 0 >= Int64(2 * Self.oneMB))
    }

    // TC-10
    @Test("시뮬레이터 기기는 caution이라 기본 선택되지 않는다")
    func simulatorDevicesAreCautionAndUnchecked() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        try write(Self.oneMB, at: home.appending(
            path: "Library/Developer/CoreSimulator/Devices/AAAA-1111/data/app.bin"))

        let items = await XcodeScanner(home: home).scan()
        #expect(items.count == 1)
        #expect(items.first?.safety == .caution)
        #expect(items.first?.isSelectedByDefault == false)
        #expect(items.first?.detail == "시뮬레이터에 설치한 앱과 설정이 사라집니다")
    }

    // TC-11
    @Test("기기 폴더가 비어 있으면 후보로 올리지 않는다")
    func emptyDevicesYieldNothing() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        try FileManager.default.createDirectory(
            at: home.appending(path: "Library/Developer/CoreSimulator/Devices"),
            withIntermediateDirectories: true)

        let items = await XcodeScanner(home: home).scan()
        #expect(items.isEmpty)
    }

    // TC-13
    @Test("기기 목록 인덱스(device_set.plist)는 후보로 올리지 않는다")
    func excludesDeviceSetPlist() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        let devices = home.appending(path: "Library/Developer/CoreSimulator/Devices")
        try write(Self.oneMB, at: devices.appending(path: "AAAA-1111/data/app.bin"))
        // 기기 폴더와 나란히 놓이는 파일. 지우면 CoreSimulator가 기기 목록을 잃는다.
        try write(12 * 1024, at: devices.appending(path: "device_set.plist"))

        let items = await XcodeScanner(home: home).scan()

        #expect(items.count == 1)
        #expect(items.first?.displayName == "AAAA-1111")
        #expect(!items.contains { $0.url.lastPathComponent == "device_set.plist" })
    }

    // TC-14
    @Test("펼치지 않는 타깃은 디렉토리 필터의 영향을 받지 않는다")
    func nonExpandingTargetsUnaffectedByDirectoryFilter() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        try write(Self.oneMB, at: home.appending(
            path: "Library/Developer/DVTDownloads/component.dmg"))

        let items = await XcodeScanner(home: home).scan()
        #expect(items.count == 1)
        #expect(items.first?.displayName == "DVTDownloads")
    }

    // TC-12
    @Test("기기를 추가해도 기존 타깃의 안전 등급이 그대로다")
    func existingTargetsKeepSafetyAfterDevicesAdded() async throws {
        let home = try makeFakeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        try write(Self.oneMB, at: home.appending(
            path: "Library/Developer/Xcode/DerivedData/App-abc/out.o"))
        try write(Self.oneMB, at: home.appending(
            path: "Library/Developer/Xcode/Archives/2026-09-16/App.xcarchive/payload.bin"))
        try write(Self.oneMB, at: home.appending(
            path: "Library/Developer/CoreSimulator/Devices/AAAA-1111/data/app.bin"))

        let items = await XcodeScanner(home: home).scan()
        let safetyByName = Dictionary(uniqueKeysWithValues: items.map { ($0.displayName, $0.safety) })

        #expect(items.count == 3)
        #expect(safetyByName["App-abc"] == .safe)
        #expect(safetyByName["2026-09-16"] == .danger)
        #expect(safetyByName["AAAA-1111"] == .caution)
    }
}
