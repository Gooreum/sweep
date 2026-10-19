import Foundation

/// Sweep이 들여다보는 곳 한 군데.
///
/// 스캔하지 않아도 보여줄 수 있는 정보다. 앱을 열자마자 "이 앱이 무엇을
/// 건드리는지"가 보여야 한다 — 파일을 지우는 앱에서 이건 첫 화면에 있을 값이다.
public struct CleanupScope: Identifiable, Sendable, Hashable {
    public let url: URL
    /// 화면에 쓰는 짧은 경로. 홈은 `~`로 줄인다.
    public let label: String
    public let detail: String
    /// 사용자가 직접 추가한 폴더인가. 화면이 "빼기" 버튼을 붙인다.
    public let isCustom: Bool

    public init(url: URL, label: String, detail: String, isCustom: Bool = false) {
        self.url = url
        self.label = label
        self.detail = detail
        self.isCustom = isCustom
    }

    public var id: String { url.path }
}

extension CleanupScope {

    /// **`ProtectedPaths.allowedRoots`에서 유도한다.**
    ///
    /// 손으로 적으면 안전 게이트가 바뀔 때 화면만 낡아 거짓말을 하게 된다.
    /// 설명이 없는 루트는 목록에서 빠지는 것이 아니라 경로만 보여준다.
    /// 지금 허용 루트(`currentRoots`)를 본다 — 샌드박스에서 개발 폴더를 허락하면 한 줄 는다.
    public static var all: [CleanupScope] { scopes(roots: ProtectedPaths.currentRoots) }

    /// 루트를 주입할 수 있게 연다 — 샌드박스 쪽 목록은 테스트 프로세스에서 만들 수 없다.
    ///
    /// `userRoots`는 큰 파일·중복 파일을 찾는 사용자 폴더다. 이름이 기계마다 달라
    /// (`~/Code`, `~/katamari`) 경로로 설명을 고를 수 없으니 목록으로 알아본다.
    ///
    /// 홈 바로 아래 사용자 폴더는 **한 줄로 묶는다.** 실측 이 기계에서 17곳이라
    /// 한 줄씩 두면 카드가 창을 다 차지한다. 사용자가 추가한 폴더만 따로 둔다 —
    /// 그것은 뺄 수 있어야 해서 줄마다 버튼이 붙는다.
    static func scopes(roots: [URL],
                       userRoots: [URL] = UserFolders.roots(),
                       custom: [URL] = UserFolders.shared.custom) -> [CleanupScope] {
        let home = Sandbox.userHome.path
        let userFolders = Set(userRoots.map(FolderAccess.components(of:)))
        let customFolders = Set(custom.map(FolderAccess.components(of:)))
        var homeFolders: [URL] = []
        var customScopes: [CleanupScope] = []

        /// 임시 컨테이너는 `/private/var/folders/<해시>/C` 같은 경로라
        /// 화면에 그대로 쓰면 읽히지 않는다. 하나로 묶는다.
        var sawTemporary = false

        let fixed = roots.compactMap { url -> CleanupScope? in
            let path = url.path

            // `/private/var/folders/...`와 `/var/folders/...` 둘 다 나온다.
            // 앞의 `/private`는 심볼릭 링크라 경로에 있을 수도, 없을 수도 있다.
            if path.hasPrefix("/var/folders/") || path.hasPrefix("/private/var/folders/") {
                guard !sawTemporary else { return nil }
                sawTemporary = true
                return CleanupScope(url: url, label: String(localized: "앱 임시 폴더"),
                                    detail: String(localized: "앱이 쓰다 남긴 임시 파일"))
            }

            let label = path.hasPrefix(home)
                ? "~" + path.dropFirst(home.count)
                : path

            let known = Self.detail(for: label)
            let components = FolderAccess.components(of: url)
            if known.isEmpty, customFolders.contains(components) {
                customScopes.append(CleanupScope(url: url, label: label,
                                                 detail: String(localized: "큰 파일 · 중복 파일 · 직접 추가함"),
                                                 isCustom: true))
                return nil
            }
            if known.isEmpty, userFolders.contains(components) {
                homeFolders.append(url)
                return nil
            }
            return CleanupScope(url: url, label: label, detail: known)
        }

        guard !homeFolders.isEmpty else { return fixed + customScopes }
        let grouped = CleanupScope(url: Sandbox.userHome,
                                   label: String(localized: "~ 홈 폴더"),
                                   detail: homeFoldersDetail(homeFolders.map(\.lastPathComponent)))
        return fixed + [grouped] + customScopes
    }

    /// "큰 파일 · 중복 파일 — Desktop · Documents 외 15곳". 셋까지는 이름을 다 쓴다.
    static func homeFoldersDetail(_ names: [String]) -> String {
        let limit = names.count <= 3 ? names.count : 2
        let shown = names.prefix(limit).joined(separator: " · ")
        let rest = names.count - limit
        return rest > 0
            ? String(localized: "큰 파일 · 중복 파일 — \(shown) 외 \(rest)곳")
            : String(localized: "큰 파일 · 중복 파일 — \(shown)")
    }

    private static func detail(for label: String) -> String {
        switch label {
        case "~/Library/Developer": String(localized: "Xcode 산출물 · 시뮬레이터 · DerivedData")
        case "~/Library/Caches": String(localized: "앱이 다시 만들 수 있는 캐시")
        case "~/Library/Logs": String(localized: "앱 로그")
        case "~/Downloads": String(localized: "내려받은 파일 · 중복본")
        case "/private/tmp": String(localized: "시스템 임시 파일")
        // 폴더 전체가 아니라 안의 캐시만 본다. 설정과 인증 정보는 건드리지 않는다.
        case "~/.npm": String(localized: "npm 내려받기 캐시")
        case "~/.expo": String(localized: "Expo 캐시")
        case "~/.gradle/caches": String(localized: "Gradle 캐시")
        case "~/.cargo/registry": String(localized: "Cargo 레지스트리 캐시")
        case "~/.m2/repository": String(localized: "Maven 저장소 캐시")
        case "~/.Trash": String(localized: "휴지통 — 비우면 되돌릴 수 없습니다")
        case "~/Library/Mobile Documents/.Trash":
            String(localized: "iCloud Drive 휴지통 — 비우면 다른 기기에서도 사라집니다")
        case "~/Library/Application Support/MobileSync/Backup": String(localized: "iOS 기기 백업")
        case "~/Library/Containers/com.apple.mail/Data/Library/Mail Downloads":
            String(localized: "메일 첨부 사본")
        default: ""
        }
    }
}
