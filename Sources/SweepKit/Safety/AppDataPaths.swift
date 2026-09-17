import Foundation

/// macOS가 "다른 앱의 데이터"로 보호하는 곳.
///
/// 이 **안쪽**을 열려고 하면 앱 폴더마다 프롬프트가 뜬다
/// (`kTCCServiceSystemPolicyAppData`). 한 번 허용해도 다음 앱 폴더에서 또 묻는다 —
/// 끝이 없다. 전체 디스크 접근이 있으면 한 번도 뜨지 않는다.
///
/// 그래서 전체 디스크 접근이 없을 때는 **열어 보지 않는다.** 프롬프트를 띄우고
/// 처리하는 것이 아니라 애초에 만들지 않는 것이다.
enum AppDataPaths {

    private static let relatives = [
        "Library/Containers",
        "Library/Group Containers",
        "Library/Application Support",
    ]

    static func roots(home: URL = Sandbox.userHome) -> [URL] {
        relatives.map { home.appending(path: $0) }
    }

    /// 보호 구역 **안쪽**인가.
    ///
    /// **구역 자신은 아니다.** `~/Library/Containers`는 목록에 보여야 하고
    /// (그 자체를 여는 것은 묻지 않는다), 프롬프트를 부르는 것은 그 아래 앱 폴더다.
    static func isInside(_ url: URL, home: URL = Sandbox.userHome) -> Bool {
        roots(home: home).contains { url.isDescendant(of: $0) }
    }
}
