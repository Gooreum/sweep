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
    /// 현재 사용자의 소유가 아니다.
    case notOwnedByCurrentUser(URL)

    public var message: String {
        switch self {
        case .outsideAllowedRoots(let u): "정리 대상 범위 밖입니다: \(u.path)"
        case .protectedPath(let u): "보호된 경로입니다: \(u.path)"
        case .symlinkEscape(let u): "심볼릭 링크가 허용 범위 밖을 가리킵니다: \(u.path)"
        case .rootOrHome(let u): "루트 또는 홈 디렉토리는 삭제할 수 없습니다: \(u.path)"
        case .allowedRootItself(let u): "정리 루트 자체는 삭제할 수 없습니다: \(u.path)"
        case .notOwnedByCurrentUser(let u): "다른 사용자·시스템 소유라 정리할 수 없습니다: \(u.path)"
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

    /// 이 사용자의 임시 파일 컨테이너 안 `C`(Caches)와 `T`(TemporaryItems).
    ///
    /// `/private/var/folders`나 그 아래 버킷(`mg`)을 루트로 두면 안 된다.
    /// 버킷은 root 소유이고, 컨테이너 하나가 사용자의 임시 데이터 전부를 담고 있어
    /// 통째로 지우면 실행 중인 모든 앱이 깨진다. 개별 항목만 후보가 되어야 한다.
    ///
    /// 컨테이너가 사용자 소유라서 소유권 검사로는 막을 수 없다.
    /// 루트 자체를 좁히는 것이 유일한 해법이다.
    static var userTemporaryRoots: [URL] {
        // NSTemporaryDirectory()가 `<컨테이너>/T`를 준다. 그 부모가 컨테이너다.
        let container = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .deletingLastPathComponent()
        return [container.appending(path: "C"), container.appending(path: "T")]
    }

    /// 이 루트들의 **하위**만 삭제할 수 있다.
    public static let allowedRoots: [URL] = [
        inHome("Library/Developer"),
        inHome("Library/Caches"),
        inHome("Downloads"),
        URL(filePath: "/private/tmp"),
    ] + userTemporaryRoots

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
        let resolved = canonical(requested)

        let home = canonical(FileManager.default.homeDirectoryForCurrentUser)

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
        //    마지막 구성요소는 그것 자체가 링크일 수 있으므로 풀지 않고, 그 위치만 따진다.
        let requestedLocation = canonical(requested.deletingLastPathComponent())
            .appending(path: requested.lastPathComponent)
        if resolved != requestedLocation,
           !roots.contains(where: { requestedLocation.isDescendant(of: $0) }) {
            throw RemovalVeto.symlinkEscape(requested)
        }

        // 6. 남의 소유는 거부한다. 지울 수 없을 뿐 아니라, 지워지면 다른 프로세스가 깨진다.
        //    경로가 없으면 소유자를 읽을 수 없어 nil이 되고 검사를 건너뛴다 —
        //    존재 여부는 관문의 관심사가 아니고, 실제 삭제 시 자연스럽게 실패한다.
        if let owner = ownerID(of: resolved), owner != getuid() {
            throw RemovalVeto.notOwnedByCurrentUser(resolved)
        }
    }

    /// 소유자 uid. 읽을 수 없으면(주로 경로가 없으면) nil.
    private static func ownerID(of url: URL) -> uid_t? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let id = attributes[.ownerAccountID] as? NSNumber
        else { return nil }
        return uid_t(id.uint32Value)
    }

    /// 존재하지 않는 경로에도 일관된 실경로를 준다.
    ///
    /// `resolvingSymlinksInPath()`는 경로가 실재할 때만 `/private/tmp`를 `/tmp`로 접는다.
    /// 없는 경로는 그대로 둬서, **같은 위치가 존재 여부에 따라 다른 문자열이 된다.**
    /// 그대로 두면 허용 루트(`/tmp`)와 후보(`/private/tmp/x`)가 어긋나 오판한다.
    ///
    /// 더 위험한 쪽은 반대 방향이다. `~/Library/Caches/링크/없는파일`처럼 마지막 구성요소만
    /// 없으면 중간의 링크가 풀리지 않아, 바깥을 가리키는 링크가 허용 루트 안으로 보인다.
    /// 실재하는 최상위 조상까지 풀고 나머지를 다시 붙여 두 문제를 함께 없앤다.
    static func canonical(_ url: URL) -> URL {
        let fm = FileManager.default
        var probe = url.standardizedFileURL
        var missing: [String] = []

        while !fm.fileExists(atPath: probe.path), probe.pathComponents.count > 1 {
            missing.append(probe.lastPathComponent)
            probe = probe.deletingLastPathComponent()
        }

        var result = probe.resolvingSymlinksInPath().standardizedFileURL
        for component in missing.reversed() {
            result = result.appending(path: component)
        }
        return result.standardizedFileURL
    }

    /// 던지지 않는 판정 버전. UI에서 목록을 거를 때 쓴다.
    public static func isRemovable(_ url: URL) -> Bool {
        do { try validate(url); return true } catch { return false }
    }

    // 심볼릭 링크가 섞인 실제 경로(예: /tmp → /private/tmp)로 정규화해 둔다.
    private static func resolvedRoots() -> [URL] {
        (allowedRoots + additionalRootsForTesting).map(canonical)
    }

    private static func resolvedDenyList() -> [URL] {
        denyList.map(canonical)
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
