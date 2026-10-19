import Testing
import Foundation
@testable import SweepKit

@Suite("TrashScanner")
struct TrashScannerTests {

    private let fm = FileManager.default

    private func makeHome() throws -> URL {
        let home = URL(filePath: NSTemporaryDirectory()).appending(path: "sweep-trash-\(UUID().uuidString)")
        try fm.createDirectory(at: home.appending(path: ".Trash"), withIntermediateDirectories: true)
        return home
    }

    /// 빈 가짜 `/Volumes`를 준다 — 이 Mac에 꽂힌 진짜 디스크가 섞이면 안 된다.
    private func scanner(_ home: URL) -> TrashScanner {
        TrashScanner(home: home, volumes: home.appending(path: "Volumes"))
    }

    @Test("휴지통 바로 아래 항목마다 하나씩, caution으로 올린다")
    func listsTopLevelItemsAsCaution() async throws {
        let home = try makeHome()
        defer { try? fm.removeItem(at: home) }
        let trash = home.appending(path: ".Trash")
        try Data(repeating: 0x41, count: 8192).write(to: trash.appending(path: "옛날.dmg"))
        try fm.createDirectory(at: trash.appending(path: "프로젝트/src"), withIntermediateDirectories: true)
        try Data(repeating: 0x42, count: 8192).write(to: trash.appending(path: "프로젝트/src/a.swift"))

        let items = await scanner(home).scan()

        #expect(Set(items.map(\.displayName)) == ["옛날.dmg", "프로젝트"])
        #expect(items.allSatisfy { $0.category == .trash && $0.safety == .caution })
        #expect(items.allSatisfy { !$0.isSelectedByDefault })
        #expect(items.allSatisfy { $0.detail == "비우면 되돌릴 수 없어요" })
    }

    @Test("휴지통이 없거나 비었으면 빈 배열이다")
    func emptyOrMissingTrash() async throws {
        let home = try makeHome()
        defer { try? fm.removeItem(at: home) }
        #expect(await scanner(home).scan().isEmpty)

        try fm.removeItem(at: home.appending(path: ".Trash"))
        #expect(await scanner(home).scan().isEmpty)
    }

    @Test("빈 폴더는 크기 0이라 올리지 않는다")
    func skipsEmptyFolders() async throws {
        let home = try makeHome()
        defer { try? fm.removeItem(at: home) }
        try fm.createDirectory(at: home.appending(path: ".Trash/빈폴더"), withIntermediateDirectories: true)

        #expect(await scanner(home).scan().isEmpty)
    }

    // MARK: - 다른 휴지통

    @Test("iCloud Drive 휴지통 항목을 iCloud 설명과 함께 올린다")
    func listsICloudTrash() async throws {
        let home = try makeHome()
        defer { try? fm.removeItem(at: home) }
        let iCloud = home.appending(path: "Library/Mobile Documents/.Trash")
        try fm.createDirectory(at: iCloud, withIntermediateDirectories: true)
        try Data(repeating: 0x41, count: 8192).write(to: iCloud.appending(path: "스크린샷.png"))
        try Data(repeating: 0x42, count: 8192).write(to: home.appending(path: ".Trash/옛날.dmg"))

        let items = await scanner(home).scan()

        #expect(items.count == 2)
        let shot = try #require(items.first { $0.displayName == "스크린샷.png" })
        #expect(shot.category == .trash && shot.safety == .caution)
        #expect(shot.detail == "iCloud Drive 휴지통이에요. 비우면 다른 기기에서도 사라져요")
        #expect(TrashScanner.isInICloudTrash(shot.url, home: home))
    }

    @Test("외장 디스크의 내 휴지통만 디스크 이름과 함께 올린다")
    func listsVolumeTrash() async throws {
        let home = try makeHome()
        defer { try? fm.removeItem(at: home) }
        let volumes = home.appending(path: "Volumes")
        let mine = volumes.appending(path: "Ext/.Trashes/\(getuid())")
        let others = volumes.appending(path: "Ext/.Trashes/99999")
        try fm.createDirectory(at: mine, withIntermediateDirectories: true)
        try fm.createDirectory(at: others, withIntermediateDirectories: true)
        try Data(repeating: 0x41, count: 8192).write(to: mine.appending(path: "영상.mov"))
        try Data(repeating: 0x42, count: 8192).write(to: others.appending(path: "남의것.mov"))
        // 시동 디스크처럼 `/`를 가리키는 링크는 건너뛴다
        try fm.createSymbolicLink(at: volumes.appending(path: "Macintosh HD"),
                                  withDestinationURL: URL(filePath: "/"))

        let items = await scanner(home).scan()

        #expect(items.map(\.displayName) == ["영상.mov"])
        #expect(items.first?.detail == "Ext 휴지통이에요. 비우면 되돌릴 수 없어요")
    }

    @Test("isInICloudTrash는 iCloud 휴지통 안에서만 참이다")
    func iCloudTrashMembership() {
        let home = URL(filePath: "/Users/x")
        #expect(TrashScanner.isInICloudTrash(URL(filePath: "/Users/x/Library/Mobile Documents/.Trash/a.png"), home: home))
        #expect(!TrashScanner.isInICloudTrash(URL(filePath: "/Users/x/Library/Mobile Documents/.Trash"), home: home))
        #expect(!TrashScanner.isInICloudTrash(URL(filePath: "/Users/x/.Trash/a.png"), home: home))
    }

    // MARK: - iCloud에만 있는 항목

    @Test("iCloud에만 있는 항목은 크기 0으로, iCloud 공간만 비워진다고 올린다")
    func listsCloudOnlyItems() async throws {
        let home = try makeHome()
        defer { try? fm.removeItem(at: home) }
        let iCloud = home.appending(path: "Library/Mobile Documents/.Trash")
        try fm.createDirectory(at: iCloud, withIntermediateDirectories: true)
        // 자리표시자는 만들 수 없다. 빈 파일을 두고 dataless로 친다.
        try Data().write(to: iCloud.appending(path: "index.html"))
        try Data().write(to: iCloud.appending(path: "그냥빈파일.txt"))

        let items = await TrashScanner(home: home, volumes: home.appending(path: "Volumes"),
                                       isDataless: { $0.lastPathComponent == "index.html" }).scan()

        #expect(items.map(\.displayName) == ["index.html"])
        #expect(items.first?.size == 0)
        #expect(items.first?.detail == "iCloud에만 있어요. 지우면 iCloud 공간만 비워져요")
    }

    // MARK: - 관리자 소유

    @Test("남의 소유 항목만 모든 휴지통에서 골라 준다")
    func findsAdminOwnedLeftovers() throws {
        let home = try makeHome()
        defer { try? fm.removeItem(at: home) }
        let iCloud = home.appending(path: "Library/Mobile Documents/.Trash")
        let volume = home.appending(path: "Volumes/Ext/.Trashes/\(getuid())")
        for folder in [iCloud, volume] {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        for url in [home.appending(path: ".Trash/Sweep.app"), home.appending(path: ".Trash/내것.zip"),
                    iCloud.appending(path: "root.pkg"), volume.appending(path: "root.mov")] {
            try Data([1]).write(to: url)
        }
        let rootOwned: Set<String> = ["Sweep.app", "root.pkg", "root.mov"]

        let scanner = TrashScanner(home: home, volumes: home.appending(path: "Volumes"),
                                   isDataless: { _ in false },
                                   isOwnedByMe: { !rootOwned.contains($0.lastPathComponent) })

        #expect(Set(scanner.adminOwnedLeftovers().map(\.lastPathComponent)) == rootOwned)
    }

    @Test("휴지통이 비었거나 없으면 남은 것도 없다")
    func noLeftoversWhenEmpty() throws {
        let home = try makeHome()
        defer { try? fm.removeItem(at: home) }
        let scanner = TrashScanner(home: home, volumes: home.appending(path: "Volumes"),
                                   isDataless: { _ in false }, isOwnedByMe: { _ in false })
        #expect(scanner.adminOwnedLeftovers().isEmpty)

        try fm.removeItem(at: home.appending(path: ".Trash"))
        #expect(scanner.adminOwnedLeftovers().isEmpty)
    }
}
