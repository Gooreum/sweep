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

    @Test("휴지통 바로 아래 항목마다 하나씩, caution으로 올린다")
    func listsTopLevelItemsAsCaution() async throws {
        let home = try makeHome()
        defer { try? fm.removeItem(at: home) }
        let trash = home.appending(path: ".Trash")
        try Data(repeating: 0x41, count: 8192).write(to: trash.appending(path: "옛날.dmg"))
        try fm.createDirectory(at: trash.appending(path: "프로젝트/src"), withIntermediateDirectories: true)
        try Data(repeating: 0x42, count: 8192).write(to: trash.appending(path: "프로젝트/src/a.swift"))

        let items = await TrashScanner(home: home).scan()

        #expect(Set(items.map(\.displayName)) == ["옛날.dmg", "프로젝트"])
        #expect(items.allSatisfy { $0.category == .trash && $0.safety == .caution })
        #expect(items.allSatisfy { !$0.isSelectedByDefault })
        #expect(items.allSatisfy { $0.detail == "비우면 되돌릴 수 없습니다" })
    }

    @Test("휴지통이 없거나 비었으면 빈 배열이다")
    func emptyOrMissingTrash() async throws {
        let home = try makeHome()
        defer { try? fm.removeItem(at: home) }
        #expect(await TrashScanner(home: home).scan().isEmpty)

        try fm.removeItem(at: home.appending(path: ".Trash"))
        #expect(await TrashScanner(home: home).scan().isEmpty)
    }

    @Test("빈 폴더는 크기 0이라 올리지 않는다")
    func skipsEmptyFolders() async throws {
        let home = try makeHome()
        defer { try? fm.removeItem(at: home) }
        try fm.createDirectory(at: home.appending(path: ".Trash/빈폴더"), withIntermediateDirectories: true)

        #expect(await TrashScanner(home: home).scan().isEmpty)
    }
}
