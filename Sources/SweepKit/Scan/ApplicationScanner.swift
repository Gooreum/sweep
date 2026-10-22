import CoreServices
import Foundation

/// 설치된 앱. 앱 폴더 **바로 아래**의 `.app`만 본다 — 관문(`ProtectedPaths.isApplicationBundle`)과
/// 같은 깊이다. 한 단 아래(`~/Applications/Chrome Apps.localized/*.app`)는 지울 수 없으니 올리지 않는다.
///
/// 자동으로 고르지 않는다(`.caution`). 앱은 다시 받을 수 있어도 설정·라이선스가 엮여 있어
/// 사용자가 하나씩 보고 고른다. 판단 근거는 **마지막으로 연 날짜**다.
public struct ApplicationScanner: CleanupScanner {
    public let category: ScanCategory = .application

    private let folders: [URL]
    private let lastUsed: @Sendable (URL) -> Date?
    private let running: @Sendable () -> [URL]

    /// 폴더·마지막 사용일·실행 중 앱을 주입할 수 있게 연다 — 테스트가 진짜 `/Applications`와
    /// Spotlight에 기대지 않게.
    init(folders: [URL] = ProtectedPaths.applicationFolders,
         lastUsed: @escaping @Sendable (URL) -> Date? = ApplicationScanner.spotlightLastUsed,
         running: @escaping @Sendable () -> [URL] = { RunningApplications.urls }) {
        self.folders = folders
        self.lastUsed = lastUsed
        self.running = running
    }

    public init() { self.init(folders: ProtectedPaths.applicationFolders) }

    public func scan() async -> [CleanupItem] {
        let fm = FileManager.default
        let runningPaths = Set(running().map { $0.standardizedFileURL.resolvingSymlinksInPath().path })
        let me = Bundle.main.bundleURL.standardizedFileURL.resolvingSymlinksInPath().path

        var items: [CleanupItem] = []
        for folder in folders {
            guard let children = try? fm.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: [.isDirectoryKey, .creationDateKey],
                options: [.skipsHiddenFiles]) else { continue }

            for app in children where app.pathExtension == "app" {
                let path = app.standardizedFileURL.resolvingSymlinksInPath().path
                guard path != me else { continue }
                let found = DirectorySize.summary(at: app)
                let opened = lastUsed(app)
                let added = (try? app.resourceValues(forKeys: [.creationDateKey]))?.creationDate
                let isRunning = runningPaths.contains(path)

                items.append(CleanupItem(
                    url: app, size: found.bytes, category: .application,
                    // 실행 중이면 잠근다. 휴지통으로 옮겨도 앱은 계속 돌다가 다음 실행에 깨진다.
                    safety: isRunning ? .danger : .caution,
                    detail: isRunning ? String(localized: "실행 중이에요. 종료하면 옮길 수 있어요")
                                      : Self.usageLine(opened),
                    dates: FileDates(created: added, lastUsed: opened)))
            }
        }
        return items
    }

    /// 사용 기준 한 줄. 날짜를 모르면 지어내지 않고 모른다고 말한다.
    static func usageLine(_ opened: Date?, now: Date = Date()) -> String {
        guard let opened else {
            return String(localized: "연 기록이 없어요. 한 번도 열지 않았거나 기록이 남지 않은 앱이에요")
        }
        let days = Calendar.current.dateComponents([.day], from: opened, to: now).day ?? 0
        if days < 30 { return String(localized: "최근에 열었어요") }
        return String(localized: "\(days)일 동안 열지 않았어요")
    }

    /// Finder 정보 창의 "마지막으로 열어 본 날짜"와 같은 값(Spotlight `kMDItemLastUsedDate`).
    ///
    /// 파일 수정일로 대신하지 않는다 — 앱 번들은 설치·업데이트 때만 바뀌어 "사용"을 말해 주지 않는다.
    public static let spotlightLastUsed: @Sendable (URL) -> Date? = { url in
        guard let item = MDItemCreateWithURL(kCFAllocatorDefault, url as CFURL) else { return nil }
        return MDItemCopyAttribute(item, kMDItemLastUsedDate) as? Date
    }
}
