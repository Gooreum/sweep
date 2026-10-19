import Testing
import Foundation
@testable import SweepKit

@Suite("DeviceBackupScanner")
struct DeviceBackupScannerTests {

    private let fm = FileManager.default

    private func makeHome() throws -> (home: URL, backups: URL) {
        let home = URL(filePath: NSTemporaryDirectory()).appending(path: "sweep-backup-\(UUID().uuidString)")
        let backups = home.appending(path: "Library/Application Support/MobileSync/Backup")
        try fm.createDirectory(at: backups, withIntermediateDirectories: true)
        return (home, backups)
    }

    private func makeBackup(_ udid: String, in backups: URL, info: [String: Any]?) throws -> URL {
        let folder = backups.appending(path: udid)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data(repeating: 0x41, count: 8192).write(to: folder.appending(path: "Manifest.db"))
        if let info {
            let data = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            try data.write(to: folder.appending(path: "Info.plist"))
        }
        return folder
    }

    @Test("기기 백업마다 하나씩 caution으로 올리고 기기 이름과 시점을 말한다")
    func listsBackupsWithDeviceName() async throws {
        let (home, backups) = try makeHome()
        defer { try? fm.removeItem(at: home) }
        try makeBackup("00008030-AAAA", in: backups, info: [
            "Device Name": "민구의 iPhone",
            "Last Backup Date": Date().addingTimeInterval(-100 * 86_400),
        ])

        let items = await DeviceBackupScanner(home: home).scan()

        #expect(items.count == 1)
        #expect(items.first?.category == .deviceBackup)
        #expect(items.first?.safety == .caution)
        #expect(items.first?.detail == "민구의 iPhone · 3개월 전 백업")
    }

    @Test("Info.plist가 없으면 일반 설명을, 날짜가 없으면 기기 이름만 쓴다")
    func fallsBackWithoutInfo() throws {
        let (home, backups) = try makeHome()
        defer { try? fm.removeItem(at: home) }
        let bare = try makeBackup("A", in: backups, info: nil)
        let nameOnly = try makeBackup("B", in: backups, info: ["Device Name": "iPad"])

        #expect(DeviceBackupScanner.detail(of: bare) == "iOS 기기 백업")
        #expect(DeviceBackupScanner.detail(of: nameOnly) == "iPad")
    }

    @Test("오늘·며칠 전 백업을 구분한다")
    func describesRecentBackups() throws {
        let (home, backups) = try makeHome()
        defer { try? fm.removeItem(at: home) }
        let now = Date()
        let today = try makeBackup("T", in: backups, info: ["Device Name": "iPhone", "Last Backup Date": now])
        let week = try makeBackup("W", in: backups, info: [
            "Device Name": "iPhone", "Last Backup Date": now.addingTimeInterval(-7 * 86_400)])

        #expect(DeviceBackupScanner.detail(of: today, now: now) == "iPhone · 오늘 백업")
        #expect(DeviceBackupScanner.detail(of: week, now: now) == "iPhone · 7일 전 백업")
    }

    @Test("백업 폴더가 없거나 파일만 있으면 빈 배열이다")
    func missingOrStrayFiles() async throws {
        let (home, backups) = try makeHome()
        defer { try? fm.removeItem(at: home) }
        try Data(repeating: 0x41, count: 8192).write(to: backups.appending(path: ".DS_Store_like"))
        try Data(repeating: 0x41, count: 8192).write(to: backups.appending(path: "stray.plist"))
        #expect(await DeviceBackupScanner(home: home).scan().isEmpty)

        try fm.removeItem(at: backups)
        #expect(await DeviceBackupScanner(home: home).scan().isEmpty)
    }
}
