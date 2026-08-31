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

    public var id: String { url.path }
}

extension CleanupScope {

    /// **`ProtectedPaths.allowedRoots`에서 유도한다.**
    ///
    /// 손으로 적으면 안전 게이트가 바뀔 때 화면만 낡아 거짓말을 하게 된다.
    /// 설명이 없는 루트는 목록에서 빠지는 것이 아니라 경로만 보여준다.
    public static var all: [CleanupScope] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        /// 임시 컨테이너는 `/private/var/folders/<해시>/C` 같은 경로라
        /// 화면에 그대로 쓰면 읽히지 않는다. 하나로 묶는다.
        var sawTemporary = false

        return ProtectedPaths.allowedRoots.compactMap { url -> CleanupScope? in
            let path = url.path

            // `/private/var/folders/...`와 `/var/folders/...` 둘 다 나온다.
            // 앞의 `/private`는 심볼릭 링크라 경로에 있을 수도, 없을 수도 있다.
            if path.hasPrefix("/var/folders/") || path.hasPrefix("/private/var/folders/") {
                guard !sawTemporary else { return nil }
                sawTemporary = true
                return CleanupScope(url: url, label: "앱 임시 폴더",
                                    detail: "앱이 쓰다 남긴 임시 파일")
            }

            let label = path.hasPrefix(home)
                ? "~" + path.dropFirst(home.count)
                : path

            return CleanupScope(url: url, label: label, detail: Self.detail(for: label))
        }
    }

    private static func detail(for label: String) -> String {
        switch label {
        case "~/Library/Developer": "Xcode 산출물 · 시뮬레이터 · DerivedData"
        case "~/Library/Caches": "앱이 다시 만들 수 있는 캐시"
        case "~/Library/Logs": "앱 로그"
        case "~/Downloads": "내려받은 파일 · 중복본"
        case "/private/tmp": "시스템 임시 파일"
        default: ""
        }
    }
}
