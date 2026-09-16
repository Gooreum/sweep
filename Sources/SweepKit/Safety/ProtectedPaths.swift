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
    /// 파일 플래그(불변·삭제금지·SIP)가 걸려 있어 커널이 삭제를 거부한다.
    case systemProtected(URL)

    public var message: String {
        switch self {
        case .outsideAllowedRoots(let u): "정리 대상 범위 밖입니다: \(u.path)"
        case .protectedPath(let u): "보호된 경로입니다: \(u.path)"
        case .symlinkEscape(let u): "심볼릭 링크가 허용 범위 밖을 가리킵니다: \(u.path)"
        case .rootOrHome(let u): "루트 또는 홈 디렉토리는 삭제할 수 없습니다: \(u.path)"
        case .allowedRootItself(let u): "정리 루트 자체는 삭제할 수 없습니다: \(u.path)"
        case .notOwnedByCurrentUser(let u): "다른 사용자·시스템 소유라 정리할 수 없습니다: \(u.path)"
        case .systemProtected(let u): "시스템이 보호 중이라 삭제할 수 없습니다: \(u.path)"
        }
    }
}

/// 모든 삭제가 반드시 통과해야 하는 관문.
///
/// 블랙리스트가 아니라 **화이트리스트**다. 허용된 루트 하위가 아니면 전부 거부한다.
/// 스캐너가 버그로 엉뚱한 경로를 뱉어도 여기서 막히는 것이 설계 의도다.
public enum ProtectedPaths {

    private static func inHome(_ relative: String) -> URL {
        Sandbox.userHome.appending(path: relative)
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
    public static let allowedRoots: [URL] = roots(sandboxed: Sandbox.isActive)

    /// 샌드박스 안에서는 `~/Downloads`만 늘 열린다 — `files.downloads.read-write`가 여는
    /// 유일한 곳이다. 나머지는 실측에서 전부 권한 거부였다. 사용자가 열어 준
    /// `~/Library/Developer`(`developer`)가 있으면 그것도 더한다.
    /// 샌드박스의 임시 폴더는 컨테이너 안(`Data/tmp`)이라 `userTemporaryRoots`도 뜻이 없다.
    /// 홈 바로 아래 개발 도구 폴더. 도구의 최상위 폴더를 루트로 둔다 —
    /// "루트 자체는 삭제할 수 없다"는 기존 규칙이 `~/.npm`을 지키고 하위만 후보가 된다.
    /// 새 규칙을 만들지 않고 있는 규칙을 쓰는 것이다.
    ///
    /// 안에 캐시만 들어 있는 폴더여야 한다. 실행 파일이 섞인 곳은 넣지 않는다 —
    /// `~/.nvm`은 node 런타임이고, `~/.turso`는 `sqld`(39M)·`turso`(17M) 실행 파일 둘뿐이다.
    /// 지우면 명령어가 사라진다.
    ///
    /// `~/.expo`는 루트로 두되 스캐너가 하위 캐시 폴더만 고른다. 같은 층에
    /// `ngrok.yml`(인증 토큰)과 `state.json`(로그인 상태)이 있어 통째로 올리면 안 된다.
    static let homeToolRoots: [String] = [".npm", ".expo"]

    static func roots(sandboxed: Bool, granted: [URL] = []) -> [URL] {
        let downloads = inHome("Downloads")
        let all = [
            inHome("Library/Developer"),
            inHome("Library/Caches"),
            inHome("Library/Logs"),
            downloads,
            URL(filePath: "/private/tmp"),
        ] + homeToolRoots.map(inHome) + userTemporaryRoots

        guard sandboxed else { return all }

        // 샌드박스에서도 **같은 목록**을 쓰고, 사용자가 열어 준 폴더 안에 있는 것만 켠다.
        //
        // 허락받은 폴더를 그대로 루트로 넣지 않는 것이 핵심이다. `~/Library`를 루트로 만들면
        // `~/Library/Safari`·`Mail`이 전부 삭제 가능해진다. 루트 목록은 그대로 두고
        // **켜고 끄는 열쇠**로만 쓰면, 허락이 넓어져도 지울 수 있는 것은 넓어지지 않는다.
        //
        // `/private/tmp`와 임시 컨테이너는 샌드박스에서 살릴 방법이 없다 —
        // 사용자가 열기 대화상자에서 고를 수 있는 경로가 아니다.
        return [downloads] + all.filter { root in
            root != downloads && granted.contains { root.isSameOrDescendant(of: $0) }
        }
    }

    /// 앱 캐시를 들여다볼 수 있는 상태인가. 샌드박스 밖에서는 늘 그렇다.
    private static var isAppSupportReadable: Bool {
        guard Sandbox.isActive else { return true }
        return FolderAccess.shared.urls.contains { appSupportRoot.isSameOrDescendant(of: $0) }
    }

    /// 지금 이 순간의 허용 루트. 허락은 실행 중에 생기므로 시작할 때 고정되는
    /// `allowedRoots`와 따로 둔다. 화면(보는 곳 목록)이 이것을 본다.
    public static var currentRoots: [URL] {
        Sandbox.isActive
            ? roots(sandboxed: true, granted: FolderAccess.shared.urls)
            : allowedRoots
    }

    /// Electron·Chromium 앱이 공통으로 쓰는 캐시 폴더 이름.
    ///
    /// `~/Library/Application Support`는 **허용 루트에 넣지 않는다.** 그 아래는 기본이
    /// 사용자 데이터다 — 실측으로 앱 로그인 세션, 로컬 DB(`notion.db` 79M),
    /// iCloud·Dropbox 상태(`FileProvider` 829M)가 들어 있다. `userTemporaryRoots`와 같은
    /// 상황이고 같은 답을 쓴다: 사용자 소유라 소유권 검사가 듣지 않으니 범위를 좁히는 수밖에 없다.
    ///
    /// 게다가 관문은 스캐너만 지나는 문이 아니다. 디스크 맵은 스캐너를 거치지 않고
    /// 관문에게만 물어보고 휴지통 버튼을 켠다. 루트를 넓히면 그 폴더들이 클릭 한 번 거리로 들어온다.
    ///
    /// 그래서 루트 대신 **끝 이름**으로 연다. 정확한 경로 목록은 쓸 수 없다 —
    /// 앱 이름도, 프로필 버전(`Figma/DesktopProfile/v39`)도, 파티션 이름도 기계마다 다르다.
    ///
    /// `Service Worker`는 통째로 열지 않는다. 그 아래 `Database`가 서비스 워커 등록 정보라
    /// 지우면 켜져 있는 앱이 재등록에 실패한다. 캐시 실체인 `CacheStorage`만 연다.
    ///
    /// 뺀 것: `IndexedDB`, `Local Storage`, `Local Extension Settings`, `WebStorage`,
    /// `File System`, `Shared Dictionary` — 전부 사용자 데이터다.
    static let appCacheSuffixes: [[String]] = [
        ["Cache"], ["Code Cache"], ["GPUCache"],
        ["DawnCache"], ["DawnGraphiteCache"], ["DawnWebGPUCache"],
        ["GrShaderCache"], ["GraphiteDawnCache"],
        ["Service Worker", "CacheStorage"],
    ]

    /// `Application Support`로부터 몇 단계까지 내려가 찾을지.
    ///
    /// 실측: `Google/Chrome/Default/Service Worker/CacheStorage`가 5단계다.
    /// 6으로 넓혀도 잡히는 건 `Chrome-headless/scoped_dir*` 찌꺼기뿐이었다.
    static let appCacheMaxDepth = 5

    static var appSupportRoot: URL { inHome("Library/Application Support") }

    /// 끝 이름이 앱 캐시 폴더 이름인가. **위치는 보지 않는다.**
    ///
    /// 스캐너가 후보를 고를 때 쓴다. 스캐너는 가짜 홈을 주입받아 돌 수 있어야 하는데
    /// 위치까지 따지면 실제 홈 기준이라 테스트에서 전부 걸러진다.
    /// 위치 판정은 관문이 `validate`에서 따로 한다 — 스캐너가 이름을 잘못 골라도
    /// `ScanCoordinator.normalize`의 2차 방어선에서 막힌다.
    static func matchesAppCacheName(_ url: URL) -> Bool {
        let components = url.standardizedFileURL.pathComponents
        return appCacheSuffixes.contains { suffix in
            components.count >= suffix.count
                && Array(components.suffix(suffix.count)) == suffix
        }
    }

    /// `~/Library/Application Support` 아래의 앱 캐시 폴더인가.
    ///
    /// 세 조건을 모두 만족해야 한다 — 그 아래에 있을 것, 끝 이름이 맞을 것,
    /// 너무 깊지 않을 것. 하나라도 어긋나면 관문은 이 경로를 모르는 것으로 친다.
    static func isAppCacheFolder(_ components: [String], appSupport: [String]) -> Bool {
        let depth = components.count - appSupport.count
        guard depth > 0, depth <= appCacheMaxDepth,
              Array(components.prefix(appSupport.count)) == appSupport
        else { return false }

        return appCacheSuffixes.contains { suffix in
            components.count >= suffix.count
                && Array(components.suffix(suffix.count)) == suffix
        }
    }

    /// 허용 루트 안이어도 절대 건드리지 않는 경로.
    /// 재생성 비용이 크거나(프로비저닝 프로파일) 사용자 설정(키바인딩·테마)이다.
    public static let denyList: [URL] = [
        inHome("Library/Developer/Xcode/UserData/Provisioning Profiles"),
        inHome("Library/Developer/Xcode/UserData/KeyBindings"),
        inHome("Library/Developer/Xcode/UserData/FontAndColorThemes"),
        inHome("Library/Developer/Xcode/UserData/XcodeCloud"),
        inHome("Library/Developer/Xcode/UserData/Capabilities"),
    ]

    /// 삭제해도 되는 경로인지 검사한다. 통과하지 못하면 던진다.
    /// `RemovalVeto`만 던진다 — 타입으로 고정한다.
    ///
    /// 예전엔 `throws`라 부르는 쪽마다 "그 밖의 오류"를 상상해 분기를 뒀는데,
    /// 그 분기는 도달할 수 없어 테스트로 고정할 수도 없었다.
    public static func validate(_ url: URL) throws(RemovalVeto) {
        let requested = url.standardizedFileURL
        let resolved = canonical(requested)

        let home = cachedHome

        // 1. 루트·홈 자체는 무조건 거부
        guard resolved.path != "/", resolved != home else {
            throw RemovalVeto.rootOrHome(resolved)
        }

        // 구성요소는 한 번만 쪼갠다. 아래에서 12번 넘게 비교하기 때문이다.
        let resolvedComponents = resolved.standardizedFileURL.pathComponents
        let roots = rootComponents()

        // 2. 허용 루트 자체를 통째로 지우는 것도 거부 (하위만 허용)
        if roots.contains(resolvedComponents) {
            throw RemovalVeto.allowedRootItself(resolved)
        }

        // 3. deny-list 우선 — 허용 루트 안이어도 막는다
        if cachedDenyComponents.contains(where: {
            resolvedComponents == $0 || Self.isDescendant(resolvedComponents, of: $0)
        }) {
            throw RemovalVeto.protectedPath(resolved)
        }

        // 4. 실경로가 허용 루트 하위이거나, 이름으로 열어 준 앱 캐시 폴더여야 한다.
        //    허용 루트 안의 심볼릭 링크가 바깥을 가리키면 여기서 걸린다.
        guard Self.isInsideAllowedArea(resolvedComponents, roots: roots) else {
            throw RemovalVeto.outsideAllowedRoots(resolved)
        }

        // 5. 링크를 타고 들어온 경우(요청 경로 ≠ 실경로), 요청 경로 자체도 허용 범위여야 한다.
        //    마지막 구성요소는 그것 자체가 링크일 수 있으므로 풀지 않고, 그 위치만 따진다.
        //    4단계와 같은 판정을 쓴다 — 두 벌로 두면 언젠가 갈라진다.
        let requestedLocation = canonical(requested.deletingLastPathComponent())
            .appending(path: requested.lastPathComponent)
        if resolved != requestedLocation {
            let locationComponents = requestedLocation.standardizedFileURL.pathComponents
            guard Self.isInsideAllowedArea(locationComponents, roots: roots) else {
                throw RemovalVeto.symlinkEscape(requested)
            }
        }

        // 6·7단계는 lstat 한 번으로 함께 처리한다. 예전엔 소유자를 읽으려고
        // attributesOfItem으로 속성 딕셔너리를 통째로 만들었다 — uid 하나 때문에 0.285ms.
        //
        // 경로가 없으면 nil이 되어 두 검사를 모두 건너뛴다 —
        // 존재 여부는 관문의 관심사가 아니고, 실제 삭제 시 자연스럽게 실패한다.
        if let info = fileInfo(of: resolved) {
            // 6. 남의 소유는 거부한다. 지울 수 없을 뿐 아니라, 지워지면 다른 프로세스가 깨진다.
            guard info.uid == getuid() else {
                throw RemovalVeto.notOwnedByCurrentUser(resolved)
            }

            // 7. 커널이 삭제를 거부하는 플래그가 걸려 있으면 후보로 올리지 않는다.
            //    소유자가 나이고 부모가 쓰기 가능해도 SF_NOUNLINK·SIP면 unlink가 실패한다.
            //
            //    부모 디렉토리의 플래그는 보지 않는다. 임시 컨테이너의 `T` 자신이
            //    SF_NOUNLINK를 갖지만 그 안의 항목은 자유롭게 지워지므로,
            //    부모까지 보면 지울 수 있는 항목 수천 개가 통째로 사라진다.
            guard info.flags & Self.undeletableFlags == 0 else {
                throw RemovalVeto.systemProtected(resolved)
            }
        }
    }

    /// 심볼릭 링크를 따라가지 않고 소유자와 파일 플래그를 **한 번의 lstat으로** 읽는다.
    /// 읽을 수 없으면(주로 경로가 없으면) nil.
    static func fileInfo(of url: URL) -> (uid: uid_t, flags: UInt32)? {
        var info = stat()
        guard lstat(url.path, &info) == 0 else { return nil }
        return (uid: info.st_uid, flags: info.st_flags)
    }

    /// 삭제를 막는 BSD 파일 플래그.
    ///
    /// `UF_NOUNLINK`은 Darwin 모듈이 노출하지 않아 값을 직접 쓴다.
    /// SIP(`com.apple.rootless`) 항목은 전수 조사 결과 전부 이 플래그들을 함께 갖고 있어
    /// 확장 속성을 따로 읽을 필요가 없다.
    static let undeletableFlags: UInt32 =
        UInt32(UF_IMMUTABLE) | 0x0000_0010 /* UF_NOUNLINK */
        | UInt32(SF_IMMUTABLE) | UInt32(SF_NOUNLINK) | UInt32(SF_RESTRICTED)

    /// 파일 플래그만 필요할 때 쓰는 편의 입구.
    ///
    /// `URLResourceValues`의 `isUserImmutable`/`isSystemImmutable`로는 부족하다.
    /// 실제로 삭제를 막는 `SF_NOUNLINK`를 둘 다 보지 않아 false를 돌려준다.
    static func fileFlags(of url: URL) -> UInt32? { fileInfo(of: url)?.flags }

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

    /// 던지지 않는 판정 버전. 통과면 nil, 막히면 **사유**를 돌려준다.
    ///
    /// 화면이 "왜 못 지우는지"를 말할 수 있어야 한다 — 눌러 보고 실패해야
    /// 아는 것은 알려준 것이 아니다.
    public static func veto(for url: URL) -> RemovalVeto? {
        do {
            try validate(url)
            return nil
        } catch {
            // 타입이 `RemovalVeto`로 고정돼 있어 다른 오류가 올 수 없다.
            return error
        }
    }

    /// 목록을 거를 때 쓴다. **판정 로직을 두 벌로 두지 않는다** —
    /// 화면이 보여주는 것과 실제 삭제 판정이 갈라지면 안 된다.
    public static func isRemovable(_ url: URL) -> Bool { veto(for: url) == nil }

    // 심볼릭 링크가 섞인 실제 경로(예: /tmp → /private/tmp)로 정규화해 둔다.
    //
    // 한 번만 계산해 캐시한다. `allowedRoots`·`denyList`는 `let` 상수인데도
    // 예전엔 `validate()` 호출마다 다시 정규화했다 — 실측 0.657ms + 0.47ms이고
    // 후보 5389개를 거르면 그것만으로 6초가 넘었다.
    private static let cachedRoots: [URL] = allowedRoots.map(canonical)
    private static let cachedDenyList: [URL] = denyList.map(canonical)

    // 경로 구성요소까지 미리 쪼개 둔다.
    // `isDescendant`는 호출마다 `standardizedFileURL.pathComponents`를 다시 만드는데,
    // 루트 7개 + denyList 5개를 훑느라 validate 한 번에 12번 반복됐다 — 실측 2.9ms.
    private static let cachedRootComponents: [[String]] =
        cachedRoots.map { $0.standardizedFileURL.pathComponents }
    private static let cachedDenyComponents: [[String]] =
        cachedDenyList.map { $0.standardizedFileURL.pathComponents }
    /// 홈은 프로세스 수명 동안 바뀌지 않는다.
    private static let cachedHome: URL = canonical(
        Sandbox.userHome)

    private static func resolvedRoots() -> [URL] { cachedRoots }

    /// 사용자가 열어 준 폴더는 실행 중에 생겨서 캐시에 넣을 수 없다.
    /// 몇 개뿐이고 이미 정규 경로로 저장돼 있어(`FolderAccess.start`) 매번 붙여도 싸다.
    /// 샌드박스 밖에서는 붙이지 않는다 — 거기서는 이미 허용 루트다.
    ///
    /// 허락받은 폴더 자체가 아니라 **그 안에서 켜진 루트**를 붙인다.
    /// `~/Library`를 열어 줬다고 `~/Library/Safari`까지 지울 수 있으면 안 된다.
    private static func rootComponents() -> [[String]] {
        guard Sandbox.isActive else { return cachedRootComponents }
        let granted = FolderAccess.shared.urls
        guard !granted.isEmpty else { return cachedRootComponents }
        return roots(sandboxed: true, granted: granted)
            .map { canonical($0).standardizedFileURL.pathComponents }
    }

    /// 경로 구성요소 단위 하위 판정. URL을 다시 정규화하지 않아 값싸다.
    private static func isDescendant(_ path: [String], of ancestor: [String]) -> Bool {
        path.count > ancestor.count && Array(path.prefix(ancestor.count)) == ancestor
    }

    /// 루트와 같은 이유로 미리 쪼개 둔다 — `validate`가 후보마다 부른다.
    private static let cachedAppSupportComponents: [String] =
        canonical(appSupportRoot).standardizedFileURL.pathComponents

    /// 허용 루트의 하위이거나, 이름으로 열어 준 앱 캐시 폴더인가.
    ///
    /// `validate`의 4단계(실경로)와 5단계(링크를 타고 온 요청 경로)가 같은 판정을 쓴다.
    private static func isInsideAllowedArea(_ components: [String], roots: [[String]]) -> Bool {
        if roots.contains(where: { isDescendant(components, of: $0) }) { return true }
        // 샌드박스에서는 `Application Support` 자체를 읽을 수 없어 이 길이 열려도 뜻이 없다.
        guard isAppSupportReadable else { return false }
        return isAppCacheFolder(components, appSupport: cachedAppSupportComponents)
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
