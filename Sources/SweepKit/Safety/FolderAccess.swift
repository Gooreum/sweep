import Foundation

/// 샌드박스에서 사용자가 열어 준 폴더들.
///
/// 샌드박스는 홈 아래를 스스로 열 수 없다. 사용자가 열기 대화상자에서 고르면 그 실행 동안
/// 열리고, 보안 범위 북마크를 저장해 두면 다음 실행에서도 연다.
/// 접근은 프로세스가 끝날 때까지 유지한다 — 스캔·삭제·디스크 맵이 아무 때나 쓴다.
///
/// **이 타입은 "읽을 수 있는가"만 안다.** "지워도 되는가"는 `ProtectedPaths`가 따로 판단한다.
/// `~/Library`를 열어 줘도 `~/Library/Safari`는 허용 루트가 아니라서 여전히 거부된다.
/// 두 축을 분리해야 허락이 넓어져도 지울 수 있는 것이 넓어지지 않는다.
///
/// 스캐너와 관문은 스레드를 가리지 않고 읽으므로 잠금으로 지킨다.
public enum FolderAccess {

    public enum Failure: Error, Equatable, Sendable {
        /// 다른 폴더를 골랐다.
        case wrongFolder(expected: String, picked: URL)
        /// 북마크를 만들지 못했다.
        case bookmark(String)

        public var message: String {
            switch self {
            case .wrongFolder(let expected, let picked):
                "\(expected) 폴더를 골라 주세요. (고른 곳: \(picked.path))"
            case .bookmark(let reason):
                "폴더 접근 권한을 저장하지 못했습니다: \(reason)"
            }
        }
    }

    /// 허락을 받을 수 있는 폴더 하나와, 그것을 열면 무엇을 볼 수 있는지.
    public struct Grantable: Sendable, Hashable, Identifiable {
        public let folder: URL
        /// 화면에 쓰는 짧은 이름.
        public let label: String
        /// 이 폴더를 열면 무엇을 찾을 수 있는지. 열기 대화상자 문구에 쓴다.
        public let purpose: String

        public var id: String { label }

        /// UserDefaults 키. 폴더마다 따로 저장한다.
        var key: String { "folderBookmark." + label.replacingOccurrences(of: "/", with: "_") }
    }

    private static func inHome(_ relative: String) -> URL {
        Sandbox.userHome.appending(path: relative)
    }

    /// 열어 달라고 할 폴더들. 위가 우선이다 — `~/Library` 하나로 대부분이 켜진다.
    ///
    /// `~/Library`는 Finder에서 숨김이지만 `NSOpenPanel.directoryURL`로 지정하면
    /// 그 폴더가 선택된 채로 열려서, 사용자는 "허용"만 누르면 된다.
    public static let grantables: [Grantable] = [
        .init(folder: inHome("Library"), label: "~/Library",
              purpose: "시뮬레이터 · 앱 웹 캐시 · 브라우저 캐시 · 로그"),
        .init(folder: inHome(".npm"), label: "~/.npm",
              purpose: "npm 내려받기 캐시"),
        .init(folder: inHome(".expo"), label: "~/.expo",
              purpose: "Expo 캐시"),
    ]

    /// 앱 전체가 공유하는 허락 상태.
    public static let shared = Registry()

    /// 지금 열려 있는 폴더들을 들고 있는 곳. 관문·스캐너가 이것만 본다.
    public final class Registry: @unchecked Sendable {
        private let defaults: UserDefaults
        /// 이전 버전 북마크가 가리키던 곳. 테스트가 진짜 홈에 폴더를 만들지 않게 주입한다.
        private let legacy: Grantable
        private let lock = NSLock()
        private var grantedURLs: [URL] = []

        /// 저장소를 주입할 수 있게 연다 — 테스트가 `.standard`나 진짜 홈을 건드리지 않게.
        init(defaults: UserDefaults = .standard,
             legacy: Grantable = FolderAccess.legacyGrantable) {
            self.defaults = defaults
            self.legacy = legacy
        }

        /// 지금 열려 있는 폴더들(링크를 푼 정규 경로).
        public var urls: [URL] {
            lock.lock(); defer { lock.unlock() }
            return grantedURLs
        }

        /// 이 폴더가 열려 있는가. 자신이 열렸거나, 자신을 품는 폴더가 열렸으면 그렇다.
        ///
        /// **경로 구성요소로 비교한다.** `URL ==`는 쓸 수 없다 — 북마크에서 푼 URL은
        /// 디렉토리라 끝에 `/`가 붙어 나오는데, 같은 곳을 가리켜도 URL 값은 달라진다.
        /// 물어보는 쪽 경로도 링크를 푼다. 열린 목록은 정규 경로로 저장되기 때문이다(`start`).
        public func isGranted(_ grantable: Grantable) -> Bool {
            let target = FolderAccess.components(of: grantable.folder)
            return urls.contains { open in
                let ancestor = FolderAccess.components(of: open)
                return target.count >= ancestor.count
                    && Array(target.prefix(ancestor.count)) == ancestor
            }
        }

        /// 하나라도 열렸는가. 허락 화면을 띄울지 판단한다.
        public var hasAny: Bool { !urls.isEmpty }

        /// 열기 대화상자에서 고른 폴더를 받는다. 맞으면 북마크를 저장하고 접근을 시작한다.
        public func grant(_ picked: URL, as grantable: Grantable) throws(Failure) {
            guard FolderAccess.matches(picked, folder: grantable.folder) else {
                throw .wrongFolder(expected: grantable.label, picked: picked)
            }

            let data: Data
            do {
                data = try picked.bookmarkData(options: .withSecurityScope,
                                               includingResourceValuesForKeys: nil,
                                               relativeTo: nil)
            } catch {
                throw .bookmark(error.localizedDescription)
            }
            defaults.set(data, forKey: grantable.key)
            start(picked)
        }

        /// 앱 시작 때 한 번. 저장된 북마크를 전부 풀어 접근을 다시 연다.
        ///
        /// 낡았으면(폴더가 옮겨졌다 돌아온 경우 등) 새로 저장한다. 못 풀거나 엉뚱한 곳을
        /// 가리키면 북마크를 지운다 — 남겨 두면 매 실행 같은 실패를 되풀이하고,
        /// 사용자는 허락 화면을 다시 볼 기회도 없이 빈 정크 탭만 본다.
        public func restoreAll() {
            migrateLegacyBookmark()
            // `legacyGrantable`도 함께 돈다. 새로 허락받을 목록(`grantables`)에는 없지만
            // 이전 버전에서 그것만 허락한 사용자의 접근을 열어야 한다.
            for grantable in FolderAccess.grantables + [legacy] {
                restore(grantable)
            }
        }

        /// 폴더 하나를 복원한다. 테스트가 폴더 단위로 확인할 수 있게 열어 둔다.
        func restore(_ grantable: Grantable) {
            guard let data = defaults.data(forKey: grantable.key) else { return }

            var stale = false
            guard let resolved = try? URL(resolvingBookmarkData: data,
                                          options: .withSecurityScope,
                                          relativeTo: nil,
                                          bookmarkDataIsStale: &stale),
                  FolderAccess.matches(resolved, folder: grantable.folder)
            else {
                defaults.removeObject(forKey: grantable.key)
                return
            }

            start(resolved)
            if stale, let fresh = try? resolved.bookmarkData(options: .withSecurityScope,
                                                             includingResourceValuesForKeys: nil,
                                                             relativeTo: nil) {
                defaults.set(fresh, forKey: grantable.key)
            }
        }

        /// 접근을 시작하고 기억한다. 멈추지 않는다 — 프로세스 수명 동안 쓴다.
        private func start(_ url: URL) {
            _ = url.startAccessingSecurityScopedResource()
            let canonical = url.resolvingSymlinksInPath().standardizedFileURL
            lock.lock(); defer { lock.unlock() }
            // 같은 이유로 경로 구성요소를 본다 — 끝의 `/` 하나 때문에 같은 폴더가 두 번 쌓인다.
            let components = FolderAccess.components(of: canonical)
            guard !grantedURLs.contains(where: { FolderAccess.components(of: $0) == components })
            else { return }
            grantedURLs.append(canonical)
        }

        // MARK: - 이전 버전에서 넘어오기

        /// 빌드 3까지는 키가 하나였다 — `~/Library/Developer` 전용.
        private static let legacyKey = "developerFolderBookmark"

        /// 옛 키를 `~/Library/Developer` 허락으로 읽어 새 키로 옮겨 적고 지운다.
        ///
        /// 그냥 두면 이미 허락한 사용자가 허락 화면을 다시 본다. 폴더를 또 고르게 하면
        /// "왜 다시 묻지"가 되고, 업데이트가 기능을 되돌린 것처럼 보인다.
        private func migrateLegacyBookmark() {
            guard let data = defaults.data(forKey: Self.legacyKey) else { return }
            defaults.set(data, forKey: legacy.key)
            defaults.removeObject(forKey: Self.legacyKey)
        }
    }

    /// 옛 북마크가 가리키던 곳. `grantables`에는 없다 — 새로 허락받을 때는
    /// 그 상위인 `~/Library`를 권하는 쪽이 한 번에 더 많이 연다.
    /// 이미 이것만 허락한 사용자를 위해 복원 경로로만 남긴다.
    static let legacyGrantable = Grantable(
        folder: inHome("Library/Developer"),
        label: "~/Library/Developer",
        purpose: "Xcode 산출물 · 시뮬레이터")

    /// 고른 곳이 열어야 할 폴더인가. 링크·`..`·끝의 `/`를 풀어 비교한다.
    /// 하위나 상위 폴더는 아니다 — 하위를 받으면 나머지가 막히고, 상위는 필요 이상으로 넓다.
    static func matches(_ picked: URL, folder: URL) -> Bool {
        normalized(picked) == normalized(folder)
    }

    private static func normalized(_ url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }

    /// 링크를 푼 경로 구성요소. 끝의 `/`나 `..`에 흔들리지 않는 비교 단위다.
    static func components(of url: URL) -> [String] {
        url.resolvingSymlinksInPath().standardizedFileURL.pathComponents
    }
}
