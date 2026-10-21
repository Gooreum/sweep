import Testing
import Foundation
@testable import SweepKit

@Suite("MailDownloadsScanner")
struct MailDownloadsScannerTests {

    private let fm = FileManager.default

    @Test("첨부 사본마다 하나씩 safe로 올리고 메일 데이터는 보지 않는다")
    func listsAttachmentCopies() async throws {
        let home = URL(filePath: NSTemporaryDirectory()).appending(path: "sweep-mail-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: home) }
        let library = home.appending(path: "Library/Containers/com.apple.mail/Data/Library")
        let downloads = library.appending(path: "Mail Downloads/6E1F-UUID")
        try fm.createDirectory(at: downloads, withIntermediateDirectories: true)
        try Data(repeating: 0x41, count: 8192).write(to: downloads.appending(path: "견적서.pdf"))
        let mail = library.appending(path: "Mail/V10")
        try fm.createDirectory(at: mail, withIntermediateDirectories: true)
        try Data(repeating: 0x41, count: 8192).write(to: mail.appending(path: "Envelope Index"))

        let items = await MailDownloadsScanner(home: home).scan()

        #expect(items.map(\.displayName) == ["6E1F-UUID"])
        #expect(items.first?.category == .mailAttachment)
        #expect(items.first?.safety == .safe)
        #expect(items.first?.detail.contains("첨부 사본") == true)
        #expect(items.first?.detail.contains("메일 원본은 다시 열 수") == true)
    }

    @Test("Mail을 쓰지 않으면 빈 배열이다")
    func missingMailContainer() async {
        let home = URL(filePath: NSTemporaryDirectory()).appending(path: "sweep-mail-\(UUID().uuidString)")
        #expect(await MailDownloadsScanner(home: home).scan().isEmpty)
    }
}
