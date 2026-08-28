import Foundation

/// 삭제가 거부된 이유.
public enum RemovalVeto: Error, Equatable, Sendable {
    /// 허용된 루트 어디에도 속하지 않는다.
    case outsideAllowedRoots(URL)
    /// 허용 루트 안이지만 명시적으로 보호된 경로다.
    case protectedPath(URL)
    /// 심볼릭 링크가 허용 범위 밖을 가리킨다.
    case symlinkEscape(URL)
    /// 루트 또는 홈 디렉토리 자체다.
    case rootOrHome(URL)
    /// 허용 루트 그 자체를 통째로 지우려 한다.
    case allowedRootItself(URL)

    public var message: String {
        switch self {
        case .outsideAllowedRoots(let u): "정리 대상 범위 밖입니다: \(u.path)"
        case .protectedPath(let u): "보호된 경로입니다: \(u.path)"
        case .symlinkEscape(let u): "심볼릭 링크가 허용 범위 밖을 가리킵니다: \(u.path)"
        case .rootOrHome(let u): "루트 또는 홈 디렉토리는 삭제할 수 없습니다: \(u.path)"
        case .allowedRootItself(let u): "정리 루트 자체는 삭제할 수 없습니다: \(u.path)"
        }
    }
}

/// 모든 삭제가 반드시 통과해야 하는 관문.
///
/// 블랙리스트가 아니라 **화이트리스트**다. 허용된 루트 하위가 아니면 전부 거부한다.
/// 스캐너가 버그로 엉뚱한 경로를 뱉어도 여기서 막히는 것이 설계 의도다.
public enum ProtectedPaths {

    private static func inHome(_ relative: String) -> URL {
        FileManager.default.homeDirectoryForCurrentUser.appending(path: relative)
    }

    /// 이 루트들의 **하위**만 삭제할 수 있다.
    public static let allowedRoots: [URL] = [
        inHome("Library/Developer"),
        inHome("Library/Caches"),
        inHome("Downloads"),
        URL(filePath: "/private/var/folders"),
        URL(filePath: "/private/tmp"),
    ]

    /// 허용 루트 안이어도 절대 건드리지 않는 경로.
    /// 재생성 비용이 크거나(프로비저닝 프로파일) 사용자 설정(키바인딩·테마)이다.
    public static let denyList: [URL] = [
        inHome("Library/Developer/Xcode/UserData/Provisioning Profiles"),
        inHome("Library/Developer/Xcode/UserData/KeyBindings"),
        inHome("Library/Developer/Xcode/UserData/FontAndColorThemes"),
        inHome("Library/Developer/Xcode/UserData/XcodeCloud"),
        inHome("Library/Developer/Xcode/UserData/Capabilities"),
    ]

    /// 테스트에서 임시 디렉토리를 허용 루트로 추가하기 위한 훅.
    /// 프로덕션 코드에서는 건드리지 않는다.
    nonisolated(unsafe) static var additionalRootsForTesting: [URL] = []

    /// 삭제해도 되는 경로인지 검사한다. 통과하지 못하면 던진다.
    public static func validate(_ url: URL) throws {
        let requested = url.standardizedFileURL
        let resolved = requested.resolvingSymlinksInPath().standardizedFileURL

        let home = FileManager.default.homeDirectoryForCurrentUser
            .resolvingSymlinksInPath().standardizedFileURL

        // 1. 루트·홈 자체는 무조건 거부
        guard resolved.path != "/", resolved != home else {
            throw RemovalVeto.rootOrHome(resolved)
        }

        let roots = resolvedRoots()

        // 2. 허용 루트 자체를 통째로 지우는 것도 거부 (하위만 허용)
        if roots.contains(resolved) {
            throw RemovalVeto.allowedRootItself(resolved)
        }

        // 3. deny-list 우선 — 허용 루트 안이어도 막는다
        if resolvedDenyList().contains(where: { resolved.isSameOrDescendant(of: $0) }) {
            throw RemovalVeto.protectedPath(resolved)
        }

        // 4. 실경로가 허용 루트 하위여야 한다.
        //    허용 루트 안의 심볼릭 링크가 바깥을 가리키면 여기서 걸린다.
        guard roots.contains(where: { resolved.isDescendant(of: $0) }) else {
            throw RemovalVeto.outsideAllowedRoots(resolved)
        }

        // 5. 링크를 타고 들어온 경우(요청 경로 ≠ 실경로), 요청 경로 자체도 허용 범위여야 한다.
        if resolved != requested,
           !roots.contains(where: { requested.isDescendant(of: $0) }) {
            throw RemovalVeto.symlinkEscape(requested)
        }
    }

    /// 던지지 않는 판정 버전. UI에서 목록을 거를 때 쓴다.
    public static func isRemovable(_ url: URL) -> Bool {
        do { try validate(url); return true } catch { return false }
    }

    // 심볼릭 링크가 섞인 실제 경로(예: /tmp → /private/tmp)로 정규화해 둔다.
    private static func resolvedRoots() -> [URL] {
        (allowedRoots + additionalRootsForTesting).map {
            $0.resolvingSymlinksInPath().standardizedFileURL
        }
    }

    private static func resolvedDenyList() -> [URL] {
        denyList.map { $0.resolvingSymlinksInPath().standardizedFileURL }
    }
}

extension URL {
    /// 경로 구성요소 단위로 하위인지 판정한다.
    /// 문자열 prefix 비교는 `/a/bc`를 `/a/b`의 하위로 잘못 판정하므로 쓰지 않는다.
    func isDescendant(of ancestor: URL) -> Bool {
        let mine = standardizedFileURL.pathComponents
        let theirs = ancestor.standardizedFileURL.pathComponents
        guard mine.count > theirs.count else { return false }
        return Array(mine.prefix(theirs.count)) == theirs
    }

    func isSameOrDescendant(of ancestor: URL) -> Bool {
        standardizedFileURL == ancestor.standardizedFileURL || isDescendant(of: ancestor)
    }
}
