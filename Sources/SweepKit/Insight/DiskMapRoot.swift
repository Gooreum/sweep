import Foundation

/// 디스크 맵이 훑을 수 있는 시작점 하나.
///
/// `ProtectedPaths.allowedRoots`를 그대로 쓰던 것을 대체한다. 정리 범위와
/// 보는 범위는 목적이 다르다 — 정리는 "안전하게 지울 것"을 찾고,
/// 디스크 맵은 "용량이 어디 갔나"를 찾는다. 후자는 못 지우는 것도 보여야 한다.
///
/// 예전에는 정리 루트만 보여줘서, 홈 87GB 중 18GB만 훑고 "디스크 맵"이라고
/// 불렀다. `~/Library/Containers`도 `Application Support`도 보이지 않았다.
public struct DiskMapRoot: Identifiable, Sendable, Hashable {

    /// Picker를 섹션으로 나눈다. 열 몇 개를 한 줄로 늘어놓으면 고르기 어렵다.
    public enum Group: String, Sendable, CaseIterable {
        case whole = "전체"
        case home = "홈 안"
        case apps = "응용 프로그램"
        case cleanup = "정리 대상"
    }

    public let url: URL
    public let label: String
    public let group: Group

    public init(url: URL, label: String, group: Group) {
        self.url = url
        self.label = label
        self.group = group
    }

    public var id: String { url.path }
}

extension DiskMapRoot {

    /// 홈 아래에서 따로 보여줄 만한 곳. 손으로 적되 실재하는 것만 살아남는다.
    private static let homeFolders = [
        "Desktop", "Documents", "Downloads", "Pictures", "Movies", "Music", "Library",
    ]

    /// **실재하는 것만** 돌려준다. 없는 경로를 Picker에 올리면 고른 뒤에야 빈 화면이 뜬다.
    ///
    /// 같은 경로가 두 그룹에 겹치면(`~/Downloads`는 홈이자 정리 대상)
    /// 먼저 나온 그룹만 남긴다 — 같은 줄이 두 번 보이면 고를 때 헷갈린다.
    public static var all: [DiskMapRoot] {
        roots(home: FileManager.default.homeDirectoryForCurrentUser)
    }

    /// 홈과 실재 판정을 주입할 수 있게 열어 둔다.
    ///
    /// 이 기계에 홈 폴더가 전부 있으면 "없는 건 뺀다"는 성질을 확인할 방법이 없다 —
    /// 실제로 검사를 지워 봐도 TC가 통과했다. 공허한 TC를 남기지 않으려고 뚫는다.
    static func roots(home: URL,
                      exists: (String) -> Bool
                          = { FileManager.default.fileExists(atPath: $0) })
        -> [DiskMapRoot] {
        var seenPaths = Set<String>()
        var seenLabels = Set<String>()
        var result: [DiskMapRoot] = []

        /// 경로**와 라벨** 둘 다로 거른다.
        ///
        /// 임시 컨테이너는 `.../C`와 `.../T` 두 경로인데 둘 다 "앱 임시 폴더"로
        /// 줄인다. 경로만 보면 다르므로 통과해서 **같은 줄이 두 번 뜬다** —
        /// 실제로 Picker에 그렇게 나왔다. 사용자에게는 글자가 같으면 같은 항목이다.
        func add(_ url: URL, _ label: String, _ group: Group) {
            let path = url.standardizedFileURL.path
            guard !seenPaths.contains(path), !seenLabels.contains(label),
                  exists(path)
            else { return }
            seenPaths.insert(path)
            seenLabels.insert(label)
            result.append(DiskMapRoot(url: url, label: label, group: group))
        }

        add(home, "홈", .whole)
        add(URL(filePath: "/"), "이 Mac", .whole)

        for name in homeFolders {
            add(home.appending(path: name), "~/\(name)", .home)
        }

        add(URL(filePath: "/Applications"), "응용 프로그램", .apps)

        // 정리 화면과 같은 범위. 여기서 시작하면 "보이는 건 다 지울 수 있다"가 성립한다.
        for url in ProtectedPaths.allowedRoots {
            add(url, cleanupLabel(for: url, home: home), .cleanup)
        }

        return result
    }

    /// 첫 진입에 자동으로 훑을 곳.
    ///
    /// 홈이 없을 리 없지만, 없으면 첫 항목으로 떨어진다 —
    /// nil을 돌려주면 화면이 "시작 지점을 고르세요"에서 멈춘다.
    public static var initial: DiskMapRoot? {
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL
        let roots = all
        return roots.first { $0.url.standardizedFileURL == home } ?? roots.first
    }

    /// `CleanupScope`와 같은 규칙 — 홈은 `~`로 줄이고 임시 컨테이너는 하나로 묶는다.
    ///
    /// `/private/var/folders/...`와 `/var/folders/...` 둘 다 나온다.
    /// 앞의 `/private`는 심볼릭 링크라 경로에 있을 수도, 없을 수도 있다.
    private static func cleanupLabel(for url: URL, home: URL) -> String {
        let path = url.path
        if path.hasPrefix("/var/folders/") || path.hasPrefix("/private/var/folders/") {
            return "앱 임시 폴더"
        }
        return path.hasPrefix(home.path)
            ? "~" + path.dropFirst(home.path.count)
            : path
    }
}
