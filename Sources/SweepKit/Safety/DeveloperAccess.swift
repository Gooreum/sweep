import Foundation

/// 샌드박스에서 사용자가 열어 준 `~/Library/Developer`.
///
/// 샌드박스는 이 폴더를 스스로 열 수 없다. 사용자가 열기 대화상자에서 고르면
/// 그 실행 동안 열리고, 보안 범위 북마크를 저장해 두면 다음 실행에서도 연다.
/// 접근은 프로세스가 끝날 때까지 유지한다 — 스캔·삭제·디스크 맵이 아무 때나 쓴다.
///
/// 스캐너와 관문은 스레드를 가리지 않고 `url`을 읽으므로 잠금으로 지킨다.
public final class DeveloperAccess: @unchecked Sendable {
    public static let shared = DeveloperAccess()

    public enum Failure: Error, Equatable, Sendable {
        /// 다른 폴더를 골랐다.
        case wrongFolder(URL)
        /// 북마크를 만들지 못했다.
        case bookmark(String)

        public var message: String {
            switch self {
            case .wrongFolder(let picked):
                "Library 안의 Developer 폴더를 골라 주세요. (고른 곳: \(picked.path))"
            case .bookmark(let reason):
                "폴더 접근 권한을 저장하지 못했습니다: \(reason)"
            }
        }
    }

    /// 열어야 하는 폴더.
    public let folder: URL

    private let defaults: UserDefaults
    private static let key = "developerFolderBookmark"

    private let lock = NSLock()
    private var granted: URL?

    /// 폴더와 저장소를 주입할 수 있게 연다 — 테스트가 진짜 홈이나 `.standard`를 건드리지 않게.
    init(folder: URL = Sandbox.userHome.appending(path: "Library/Developer"),
         defaults: UserDefaults = .standard) {
        self.folder = folder
        self.defaults = defaults
    }

    /// 열려 있으면 그 경로(링크를 푼 정규 경로). 아니면 nil.
    public var url: URL? {
        lock.lock(); defer { lock.unlock() }
        return granted
    }

    public var isGranted: Bool { url != nil }

    /// 고른 곳이 열어야 할 폴더인가. 링크·`..`·끝의 `/`를 풀어 비교한다.
    /// 하위나 상위 폴더는 아니다 — 하위를 받으면 나머지가 막히고, 상위는 필요 이상으로 넓다.
    static func matches(_ picked: URL, folder: URL) -> Bool {
        normalized(picked) == normalized(folder)
    }

    private static func normalized(_ url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }

    /// 열기 대화상자에서 고른 폴더를 받는다. 맞으면 북마크를 저장하고 접근을 시작한다.
    public func grant(_ picked: URL) throws(Failure) {
        guard Self.matches(picked, folder: folder) else { throw .wrongFolder(picked) }

        let data: Data
        do {
            data = try picked.bookmarkData(options: .withSecurityScope,
                                           includingResourceValuesForKeys: nil,
                                           relativeTo: nil)
        } catch {
            throw .bookmark(error.localizedDescription)
        }
        defaults.set(data, forKey: Self.key)
        start(picked)
    }

    /// 앱 시작 때 한 번. 저장된 북마크를 풀어 접근을 다시 연다.
    ///
    /// 낡았으면(폴더가 옮겨졌다 돌아온 경우 등) 새로 저장한다. 못 풀거나 엉뚱한 곳을
    /// 가리키면 북마크를 지운다 — 남겨 두면 매 실행 같은 실패를 되풀이하고,
    /// 사용자는 허락 화면을 다시 볼 기회도 없이 빈 정크 탭만 본다.
    public func restore() {
        guard let data = defaults.data(forKey: Self.key) else { return }

        var stale = false
        guard let resolved = try? URL(resolvingBookmarkData: data,
                                      options: .withSecurityScope,
                                      relativeTo: nil,
                                      bookmarkDataIsStale: &stale),
              Self.matches(resolved, folder: folder)
        else {
            defaults.removeObject(forKey: Self.key)
            return
        }

        start(resolved)
        if stale, let fresh = try? resolved.bookmarkData(options: .withSecurityScope,
                                                         includingResourceValuesForKeys: nil,
                                                         relativeTo: nil) {
            defaults.set(fresh, forKey: Self.key)
        }
    }

    /// 접근을 시작하고 기억한다. 멈추지 않는다 — 프로세스 수명 동안 쓴다.
    private func start(_ url: URL) {
        _ = url.startAccessingSecurityScopedResource()
        let canonical = url.resolvingSymlinksInPath().standardizedFileURL
        lock.lock(); defer { lock.unlock() }
        granted = canonical
    }
}
