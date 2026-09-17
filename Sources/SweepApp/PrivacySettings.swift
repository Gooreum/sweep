import AppKit

/// 시스템 설정의 "파일 및 폴더" 창을 연다.
///
/// TCC가 거부를 기록하면 앱이 다시 물어볼 수 없다. 사용자가 직접 켜야 하는데
/// 어디를 열어야 하는지 찾기 어렵다 — 바로 그 화면으로 보낸다.
enum PrivacySettings {

    /// macOS 버전에 따라 받는 URL이 다르다. 최신 것부터 시도하고,
    /// 마지막은 개인정보 보호 창이라도 열리게 둔다.
    private static let candidates = [
        "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Files",
        "x-apple.systempreferences:com.apple.preference.security?Privacy_Files",
        "x-apple.systempreferences:com.apple.preference.security",
    ]

    /// 전체 디스크 접근 목록.
    ///
    /// **Sweep은 이미 여기 등록돼 있고 스위치가 꺼져 있을 뿐이다**(실측: 시스템 TCC의
    /// `kTCCServiceSystemPolicyAllFiles`가 0). 사용자는 켜기만 하면 된다.
    private static let allFilesCandidates = [
        "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles",
        "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles",
        "x-apple.systempreferences:com.apple.preference.security",
    ]

    static func openFilesAndFolders() { open(candidates) }

    /// "다른 앱의 데이터" 물음을 통째로 없애는 스위치가 있는 곳.
    static func openFullDiskAccess() { open(allFilesCandidates) }

    private static func open(_ candidates: [String]) {
        for string in candidates {
            if let url = URL(string: string), NSWorkspace.shared.open(url) { return }
        }
    }
}
