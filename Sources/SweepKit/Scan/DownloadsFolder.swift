import Foundation

/// 스캐너가 훑는 `~/Downloads`.
///
/// 샌드박스에서는 홈이 컨테이너(`~/Library/Containers/<id>/Data`)이고 그 안의
/// `Downloads`는 진짜 폴더를 가리키는 **심볼릭 링크**다. 열거자는 링크 루트를 열지
/// 못해 0개를 돌려준다 — 실측에서 App Store 빌드가 `총 0개`를 냈다.
///
/// 루트가 링크일 때만 푼다. 링크가 아니면 경로를 그대로 둬야 `/var` → `/private/var`
/// 같은 정규화로 결과 경로가 달라지지 않는다.
enum DownloadsFolder {
    static func url(in home: URL) -> URL {
        let url = home.appending(path: "Downloads")
        let isLink = (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]))?
            .isSymbolicLink == true
        return isLink ? url.resolvingSymlinksInPath() : url
    }
}
