import Foundation

/// 사이드바 항목 하나.
///
/// 항목마다 **독립된 기능**이고 자기 스캐너만 돌린다.
/// 큰 파일 하나 보려고 43초짜리 전체 스캔을 기다릴 이유가 없다.
public enum Feature: String, CaseIterable, Identifiable, Sendable {
    case smartScan
    case junk
    /// 등록한 코드 폴더의 node_modules·빌드 폴더. 폴더를 등록하기 전에는 스캐너가 없다.
    case projects
    case largeFile
    case duplicate
    /// 휴지통 비우기. 정크와 나눠 둔다 — 다른 정리는 휴지통으로 옮겨 되살릴 수 있는데
    /// 이것만은 바로 지워진다. 같은 화면·같은 문구에 섞으면 그 차이가 가려진다.
    case trash
    case diskMap
    /// 유일하게 디스크와 무관한 기능. 읽기 전용이라 `.diskMap`과 같은 자리에 산다.
    case cpu

    public var id: Self { self }

    public var displayName: String {
        switch self {
        case .smartScan: String(localized: "한번에 찾기")
        case .junk: String(localized: "정리할 파일")
        case .projects: String(localized: "개발 프로젝트")
        case .largeFile: String(localized: "큰 파일")
        case .duplicate: String(localized: "중복 파일")
        case .trash: String(localized: "휴지통")
        case .diskMap: String(localized: "공간 보기")
        case .cpu: "CPU"
        }
    }

    public var systemImageName: String {
        switch self {
        case .smartScan: "sparkles"
        case .junk: "trash"
        case .projects: "folder.badge.gearshape"
        case .largeFile: "arrow.down.doc"
        case .duplicate: "doc.on.doc"
        case .trash: "trash"
        case .diskMap: "chart.pie"
        case .cpu: "speedometer"
        }
    }

    /// 시작 화면에 뜨는 설명 한 줄. 무엇을 하는 화면인지 먼저 말한다.
    public var summary: String {
        switch self {
        case .smartScan: String(localized: "지울 만한 파일이 얼마나 있는지 한 번에 확인해 보세요.")
        // 샌드박스에서는 사용자가 연 개발 폴더만 본다. 임시 파일·캐시라고 쓰면 과장이다.
        case .junk: Sandbox.isActive
            ? String(localized: "Xcode 개발용 파일 중에서 정리할 것을 찾아보세요.")
            : String(localized: "앱이 만든 임시 파일과 개발용 파일, 기기 백업을 모아 보여줘요. 필요 없는 것을 골라 주세요.")
        case .projects: String(localized: "프로젝트에서 다시 만들 수 있는 폴더(node_modules, .venv, Pods 등)를 찾아요. 휴지통으로 옮겨도 다시 설치하거나 빌드하면 생겨요.")
        case .largeFile: String(localized: "내 폴더에 큰 파일이 있는지 살펴보세요. 직접 추가한 폴더도 함께 찾아요.")
        case .duplicate: String(localized: "똑같은 파일이 여러 개 있으면 여분을 골라 정리해 보세요.")
        case .trash: String(localized: "휴지통에서 지울 것을 골라 주세요. 큰 항목부터 보여줘요. 지운 항목은 되살릴 수 없어요.")
        case .diskMap: String(localized: "큰 폴더부터 열어 보며 어디에 공간을 많이 쓰는지 확인하세요.")
        // 내 계정 소유만 읽힌다는 것을 여기서 미리 말한다. 화면에 들어가서야
        // 알면 "왜 활성 상태 보기와 목록이 다르지"로 읽힌다.
        case .cpu: String(localized: "컴퓨터를 바쁘게 하는 프로그램을 확인해 보세요.")
        }
    }

    /// 검토 목록 위에 붙는 한 문장.
    ///
    /// `summary`(시작 화면용)와 다르다. 저쪽은 "무엇을 찾는 화면인가"를 말하고
    /// 여기는 **"무엇을 기준으로 고르라는 것인가"**를 말한다. 목록을 그냥 던지면
    /// 사용자는 판단 기준 없이 체크박스만 본다.
    public var reviewHint: String {
        switch self {
        case .junk:
            String(localized: "지워도 대부분 개발할 때 다시 생기는 파일이에요. 심사에 낸 앱은 복구할 수 없어 고르지 못하게 했어요.")
        case .projects:
            String(localized: "프로젝트 설정 파일을 확인해 다시 만들 수 있는 폴더를 찾았어요. 최근에 수정한 프로젝트에는 확인 필요 표시를 붙였어요.")
        case .largeFile:
            String(localized: "사진이나 영상 원본, 백업은 필요한지 먼저 확인하세요. 앱 설치 파일은 다시 받을 수 있어요.")
        case .duplicate:
            String(localized: "아래는 여분의 파일이에요. 지우더라도 내용이 똑같은 원본 하나는 반드시 남아요.")
        case .trash:
            String(localized: "여기서 고르면 휴지통에서도 완전히 없어져요. 다시 되살릴 수 없으니 꼭 확인하세요.")
        case .smartScan:
            String(localized: "종류별로 살펴보고 정리할 것을 고르세요. 복구할 수 없는 항목은 잠가 두었어요.")
        case .diskMap:
            ""
        case .cpu:
            ""
        }
    }

    /// 이 기능이 돌리는 스캐너. 디스크 맵은 읽기 전용이라 하나도 없다.
    ///
    /// 허락은 실행 중에 생긴다. 스캔할 때마다 새로 묻는다 — 모델이 시작할 때 한 번
    /// 받아 두면 허락한 뒤에도 Xcode를 훑지 않는다.
    public var scanners: [any CleanupScanner] {
        scanners(sandboxed: Sandbox.isActive, granted: FolderAccess.shared.urls)
    }

    /// 샌드박스에서는 **열린 곳만** 훑는다. Downloads는 entitlement로 늘 열리고,
    /// 나머지는 사용자가 그 폴더를 허락했을 때만 붙는다.
    /// 막힌 곳을 훑는 스캐너를 남기면 결과 없이 시간만 쓴다(폭주 감지는 3초 표본 수집).
    ///
    /// 정크 파일은 허락 전에는 스캐너가 없다. `isScannable`이 false라 요약 카드와
    /// ⌘R에서 빠지고, 화면은 허락을 받는 입구가 된다.
    ///
    /// 폭주 임시 파일(`/private/tmp`·임시 컨테이너)은 샌드박스에서 살릴 방법이 없다 —
    /// 사용자가 열기 대화상자에서 고를 수 있는 경로가 아니다.
    func scanners(sandboxed: Bool, granted: [URL]) -> [any CleanupScanner] {
        let home = Sandbox.userHome

        /// 나열한 곳 중 **하나라도** 읽을 수 있으면 스캐너를 붙인다.
        /// 스캐너가 빈 배열을 내는 것과 아예 안 붙는 것은 다르다 — 안 붙어야 진행률
        /// 가중치에서도 빠져서, 막힌 곳을 기다리는 시간이 사라진다.
        /// 여러 곳을 보는 스캐너는 일부만 열려도 붙인다. 못 읽는 쪽은 크기 0으로 걸러진다.
        func ifReadable(_ relatives: [String],
                        _ make: () -> any CleanupScanner) -> [any CleanupScanner] {
            guard sandboxed else { return [make()] }
            let open = relatives.contains { relative in
                let folder = home.appending(path: relative)
                return granted.contains { folder.isSameOrDescendant(of: $0) }
            }
            return open ? [make()] : []
        }

        let xcode = ifReadable(["Library/Developer"]) { XcodeScanner() }
        let appCache = ifReadable(["Library/Application Support", "Library/Caches"]) {
            AppCacheScanner()
        }
        let staleCache = ifReadable(["Library/Caches"]) { StaleCacheScanner() }
        let devCache = ifReadable(["Library/Caches", "Library/Logs", ".npm", ".expo",
                                   ".gradle", ".cargo", ".m2"]) {
            DevCacheScanner()
        }
        let mail = ifReadable(["Library/Containers/com.apple.mail"]) { MailDownloadsScanner() }
        let trash = ifReadable([".Trash", "Library/Mobile Documents"]) { TrashScanner() }
        let backup = ifReadable(["Library/Application Support/MobileSync"]) { DeviceBackupScanner() }
        // 폭주 임시 파일은 샌드박스에서 살릴 방법이 없다.
        let runaway: [any CleanupScanner] = sandboxed ? [] : [RunawayTempScanner()]
        let junk = runaway + xcode + devCache + appCache + staleCache + mail + backup
        // 등록한 프로젝트 폴더가 없으면 붙이지 않는다 — 정크 탭이 허락 전에 하는 것과 같다.
        let projectRoots = ProjectFolders.roots(sandboxed: sandboxed, granted: granted)
        let projects: [any CleanupScanner] = projectRoots.isEmpty
            ? [] : [ProjectArtifactScanner(roots: projectRoots)]

        switch self {
        case .smartScan:
            return junk + projects + trash + [LargeFileScanner(), DuplicateScanner()]
        case .junk:
            return junk
        case .projects:
            return projects
        case .trash:
            return trash
        case .largeFile:
            return [LargeFileScanner()]
        case .duplicate:
            return [DuplicateScanner()]
        case .diskMap:
            return []
        // 지울 것을 찾지 않는다. 비워 두면 `isScannable`이 false가 되어
        // 요약 카드·사이드바 배지·⌘R·툴바에서 알아서 빠진다.
        case .cpu:
            return []
        }
    }

    /// 이 기능이 만들어내는 결과 분류.
    ///
    /// 손으로 적지 않고 스캐너에게서 가져온다. 따로 적어 두면 스캐너를 바꿀 때
    /// 한쪽만 고쳐져 요약 화면이 조용히 어긋난다.
    public var categories: [ScanCategory] {
        var seen: [ScanCategory] = []
        for scanner in scanners where !seen.contains(scanner.category) {
            seen.append(scanner.category)
        }
        return seen
    }

    public var isScannable: Bool { !scanners.isEmpty }

    /// 기능 고유 색 (sRGB 24bit, 다크·라이트).
    ///
    /// 값을 여기 두는 이유: 뷰에 두면 대비와 색상각이 맞는지 테스트할 수 없다.
    /// 실측 기준 — 네 색 모두 다크·라이트 양쪽 표면에서 **4.5:1 이상**이고
    /// 인접 색상각이 **40° 이상** 떨어져 있다.
    ///
    /// 스마트 스캔은 '전체' 화면이라 고유색을 주지 않는다. 고유색을 주면
    /// 정크(212°)와 겹쳐 구분되지 않는다.
    public var tintHex: (dark: UInt32, light: UInt32)? {
        switch self {
        case .smartScan: nil
        case .junk:      (0x74B4FF, 0x0A5FD1)
        case .projects:  (0xF08AD8, 0x9E1F7E)
        case .largeFile: (0xB69BFF, 0x5B33C4)
        case .duplicate: (0x5FD3C4, 0x0C6558)
        case .trash:     (0xFF8A70, 0xB42318)
        case .diskMap:   (0x7ED88F, 0x186628)
        case .cpu:       (0xE8D46A, 0x6E5E00)
        }
    }

    /// 스마트 스캔 요약에 카드로 뜨는 기능들.
    ///
    /// 자기 자신과 읽기 전용(디스크 맵)은 뺀다. 손으로 나열하지 않아
    /// 기능을 추가하면 요약에도 자동으로 따라 붙는다.
    public static var summaryCards: [Feature] {
        allCases.filter { $0 != .smartScan && $0.isScannable }
    }

    /// 스캔 결과 중 이 기능이 담당하는 것만.
    ///
    /// 뷰에서 카테고리를 손으로 걸러 내면 스캐너가 바뀔 때 조용히 어긋난다.
    public func items(from items: [CleanupItem]) -> [CleanupItem] {
        let mine = Set(categories)
        return items.filter { mine.contains($0.category) }
    }

    /// 이 기능의 정리는 휴지통으로 옮기지 않고 **바로 지운다.** 확인 창·완료 화면 문구가 이것으로 갈린다.
    public var removesPermanently: Bool { self == .trash }

    public var coordinator: ScanCoordinator { ScanCoordinator(scanners: scanners) }
}
