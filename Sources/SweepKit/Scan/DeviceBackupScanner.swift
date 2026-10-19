import Foundation

/// Finder로 만든 iPhone·iPad 백업을 찾는다. 기기마다 수십 GB인 경우가 흔하다.
///
/// caution이다. 기기를 바꾸거나 잃었을 때 되살릴 곳이 이것뿐일 수 있다 —
/// 어느 기기의 언제 백업인지 보여 주고 사용자가 고르게 한다.
///
/// 전체 디스크 접근이 없으면 읽지 못한다(TCC). 그때는 빈 배열이다.
public struct DeviceBackupScanner: CleanupScanner {
    public let category: ScanCategory = .deviceBackup

    private let home: URL

    public init(home: URL = Sandbox.userHome) {
        self.home = home
    }

    /// 백업 하나가 파일 수만 개라 크기를 재는 데 시간이 든다.
    public var progressWeight: Double { 2 }

    public func scan() async -> [CleanupItem] {
        let backups = home.appending(path: "Library/Application Support/MobileSync/Backup")
        return children(of: backups).compactMap { url in
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else {
                return nil
            }
            let found = DirectorySize.summary(at: url)
            guard found.bytes > 0 else { return nil }
            return CleanupItem(url: url, size: found.bytes, category: .deviceBackup,
                               safety: .caution, detail: Self.detail(of: url),
                               dates: found.dates)
        }
    }

    /// "민구의 iPhone · 3개월 전 백업". 폴더 이름은 UDID라 그것만으로는 어느 기기인지 모른다.
    static func detail(of backup: URL, now: Date = Date()) -> String {
        guard let data = try? Data(contentsOf: backup.appending(path: "Info.plist")),
              let info = try? PropertyListSerialization.propertyList(from: data, format: nil)
                as? [String: Any],
              let name = info["Device Name"] as? String
        else { return String(localized: "iOS 기기 백업") }

        guard let date = info["Last Backup Date"] as? Date else { return name }
        let days = Int(now.timeIntervalSince(date) / 86_400)
        let age = switch days {
        case ..<1: String(localized: "오늘 백업")
        case ..<30: String(localized: "\(days)일 전 백업")
        default: String(localized: "\(days / 30)개월 전 백업")
        }
        return "\(name) · \(age)"
    }
}
