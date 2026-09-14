import Foundation

/// App Store 빌드는 App Sandbox 안에서 돈다. 그 안에서는 남의 앱 파일을 열 수 없어
/// 정리 루트 대부분이 막힌다 — 막힌 곳을 화면에 올리면 "안 되는 기능"을 보여주는 셈이다.
///
/// 컴파일 플래그가 아니라 **실행 중에** 판정한다. 같은 소스라도 서명에 샌드박스
/// 권한이 붙었는지로 갈리므로, 실제로 갇혔는지를 보는 것이 정확하다.
public enum Sandbox {
    /// 샌드박스 프로세스에만 시스템이 넣어 주는 환경 변수 (실측: 컨테이너 ID가 들어 있다).
    public static let isActive: Bool =
        ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil

    /// 사용자의 진짜 홈. 샌드박스에서 `homeDirectoryForCurrentUser`는 컨테이너
    /// (`~/Library/Containers/<id>/Data`)를 준다 — 실측. passwd 항목은 그대로다.
    /// 샌드박스 밖에서는 두 값이 같다.
    ///
    /// SweepKit에서 "사용자 홈"은 전부 이것이다. 컨테이너를 홈으로 쓰면 허락받은
    /// `~/Library/Developer`가 아니라 컨테이너 안을 훑고, 보호 목록(`denyList`)도
    /// 컨테이너 경로를 가리켜 진짜 프로비저닝 프로파일이 보호되지 않는다.
    public static let userHome: URL = {
        guard let entry = getpwuid(getuid()), let dir = entry.pointee.pw_dir else {
            return FileManager.default.homeDirectoryForCurrentUser
        }
        return URL(filePath: String(cString: dir), directoryHint: .isDirectory)
    }()
}
