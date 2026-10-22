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
    private let isWritable: @Sendable (URL) -> Bool

    /// 폴더·마지막 사용일·실행 중 앱을 주입할 수 있게 연다 — 테스트가 진짜 `/Applications`와
    /// Spotlight에 기대지 않게.
    init(folders: [URL] = ProtectedPaths.applicationFolders,
         lastUsed: @escaping @Sendable (URL) -> Date? = ApplicationScanner.spotlightLastUsed,
         running: @escaping @Sendable () -> [URL] = { RunningApplications.urls },
         isWritable: @escaping @Sendable (URL) -> Bool = { ProtectedPaths.canWrite($0) }) {
        self.folders = folders
        self.lastUsed = lastUsed
        self.running = running
        self.isWritable = isWritable
    }

    public init() { self.init(folders: ProtectedPaths.applicationFolders) }

    public func scan() async -> [CleanupItem] { await scan(onProgress: { _ in }) }

    /// 앱 하나를 잴 때마다 진행을 알린다. Xcode처럼 큰 앱이 있으면 수십 초가 걸려
    /// 알리지 않으면 막대가 0%에 멈춰 보인다.
    public func scan(onProgress: @escaping @Sendable (Double) -> Void) async -> [CleanupItem] {
        let fm = FileManager.default
        let runningPaths = Set(running().map { $0.standardizedFileURL.resolvingSymlinksInPath().path })
        let me = Bundle.main.bundleURL.standardizedFileURL.resolvingSymlinksInPath().path

        // 먼저 목록을 모아야 분모가 생긴다.
        let apps = folders.flatMap { folder in
            ((try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil,
                                          options: [.skipsHiddenFiles])) ?? [])
                .filter { $0.pathExtension == "app" }
        }.filter { $0.standardizedFileURL.resolvingSymlinksInPath().path != me }

        var items: [CleanupItem] = []
        for (index, app) in apps.enumerated() {
            let path = app.standardizedFileURL.resolvingSymlinksInPath().path
            let found = DirectorySize.summary(at: app)
            let opened = lastUsed(app)
            // 번들의 만든 날짜는 앱을 빌드한 날이라(Electron 앱은 1980년) 설치일로 쓸 수 없다.
            // Finder의 "추가된 날짜"를 먼저 쓴다.
            let added = Self.spotlightDateAdded(app)
                ?? (try? app.resourceValues(forKeys: [.creationDateKey]))?.creationDate
            let isRunning = runningPaths.contains(path)
            // App Store·설치 프로그램 앱은 root 소유라 Mac 암호 없이는 옮겨지지 않는다(관문과 같은 판정).
            let needsPassword = !isWritable(app)

            let detail: String = if isRunning {
                String(localized: "실행 중이에요. 종료하면 옮길 수 있어요")
            } else if needsPassword {
                String(localized: "App Store나 설치 프로그램으로 깐 앱이라 Mac 암호가 필요해요. Finder에서 옮겨 주세요")
            } else {
                Self.usageLine(opened)
            }
            items.append(CleanupItem(
                url: app, size: found.bytes, category: .application,
                // 옮길 수 없는 앱은 잠근다. 고를 수 있게 두면 정리할 때마다 실패만 쌓인다.
                safety: isRunning || needsPassword ? .danger : .caution,
                detail: detail,
                dates: FileDates(created: added, lastUsed: opened)))
            onProgress(Double(index + 1) / Double(apps.count))
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

    /// Finder의 "추가된 날짜"(Spotlight `kMDItemDateAdded`). 이 Mac에 설치한 날에 가깝다.
    static func spotlightDateAdded(_ url: URL) -> Date? {
        guard let item = MDItemCreateWithURL(kCFAllocatorDefault, url as CFURL) else { return nil }
        return MDItemCopyAttribute(item, kMDItemDateAdded) as? Date
    }

    /// Finder 정보 창의 "마지막으로 열어 본 날짜"와 같은 값(Spotlight `kMDItemLastUsedDate`).
    ///
    /// 파일 수정일로 대신하지 않는다 — 앱 번들은 설치·업데이트 때만 바뀌어 "사용"을 말해 주지 않는다.
    public static let spotlightLastUsed: @Sendable (URL) -> Date? = { url in
        guard let item = MDItemCreateWithURL(kCFAllocatorDefault, url as CFURL) else { return nil }
        return MDItemCopyAttribute(item, kMDItemLastUsedDate) as? Date
    }
}
