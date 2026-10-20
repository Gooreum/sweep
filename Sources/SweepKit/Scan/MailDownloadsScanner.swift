import Foundation

/// Mail이 첨부 파일을 열 때 내려받아 두는 사본을 찾는다.
///
/// 원본은 메일 안에 그대로 있고, 첨부를 다시 열면 다시 생긴다. 그래서 safe다.
/// 메일 데이터(`Data/Library/Mail`)는 같은 컨테이너에 있지만 루트가 아니라 건드리지 않는다.
///
/// 전체 디스크 접근이 없으면 읽지 못한다(TCC). 그때는 빈 배열이다.
public struct MailDownloadsScanner: CleanupScanner {
    public let category: ScanCategory = .mailAttachment

    private let home: URL

    public init(home: URL = Sandbox.userHome) {
        self.home = home
    }

    public var progressWeight: Double { 0.2 }

    public func scan() async -> [CleanupItem] {
        let downloads = home.appending(path: "Library/Containers/com.apple.mail/Data/Library/Mail Downloads")
        return children(of: downloads).compactMap { url in
            let found = DirectorySize.summary(at: url)
            guard found.bytes > 0 else { return nil }
            return CleanupItem(url: url, size: found.bytes, category: .mailAttachment,
                               safety: .safe,
                               detail: String(localized: "메일 원본은 남아요. 첨부 파일을 다시 열면 새 사본이 생겨요"),
                               dates: found.dates)
        }
    }
}
