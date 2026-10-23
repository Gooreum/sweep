import Foundation

/// 화면이 제대로 돌려면 켜야 하는 것 하나. 화면은 이것을 받아 한 줄 안내와 켜는 버튼을 그린다.
///
/// 권한이 없으면 스캐너는 조용히 빈 결과를 낸다. "정리할 것 없음"과 "볼 수 없음"이
/// 같은 화면으로 보이면 사용자는 권한이 꺼진 줄 모른다 — 그래서 이유를 따로 든다.
public enum PermissionNeed: Hashable, Sendable {
    /// 열기 대화상자에서 허용받을 폴더.
    case folder(FolderAccess.Grantable)
    /// 시스템 설정 › 전체 디스크 접근. 앱이 대신 켤 수 없어 설정 창을 연다.
    case fullDiskAccess
}
