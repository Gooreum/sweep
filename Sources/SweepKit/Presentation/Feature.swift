import Foundation

/// 사이드바 항목 하나.
///
/// 항목마다 **독립된 기능**이고 자기 스캐너만 돌린다.
/// 큰 파일 하나 보려고 43초짜리 전체 스캔을 기다릴 이유가 없다.
public enum Feature: String, CaseIterable, Identifiable, Sendable {
    case smartScan
    case junk
    case largeFile
    case duplicate
    case diskMap

    public var id: Self { self }

    public var displayName: String {
        switch self {
        case .smartScan: "스마트 스캔"
        case .junk: "정크 파일"
        case .largeFile: "큰 파일"
        case .duplicate: "중복 파일"
        case .diskMap: "디스크 맵"
        }
    }

    public var systemImageName: String {
        switch self {
        case .smartScan: "sparkles"
        case .junk: "trash"
        case .largeFile: "arrow.down.doc"
        case .duplicate: "doc.on.doc"
        case .diskMap: "chart.pie"
        }
    }

    /// 시작 화면에 뜨는 설명 한 줄. 무엇을 하는 화면인지 먼저 말한다.
    public var summary: String {
        switch self {
        case .smartScan: "한 번에 전체를 점검하고 회수할 수 있는 용량을 알려줍니다."
        // 샌드박스에서는 사용자가 연 개발 폴더만 본다. 임시 파일·캐시라고 쓰면 과장이다.
        case .junk: Sandbox.isActive
            ? "Xcode 빌드 산출물·시뮬레이터 파일을 찾아 디스크 공간을 확보합니다."
            : "임시 파일·빌드 산출물·개발 캐시를 찾아 디스크 공간을 확보합니다."
        case .largeFile: "허용된 범위 안에서 유난히 큰 파일을 찾습니다."
        case .duplicate: "내용이 같은 파일을 찾아 한 벌만 남깁니다."
        case .diskMap: "어디가 용량을 차지하는지 크기순으로 훑어봅니다."
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
        let devCache = ifReadable(["Library/Caches", "Library/Logs", ".npm", ".expo"]) {
            DevCacheScanner()
        }
        // 폭주 임시 파일은 샌드박스에서 살릴 방법이 없다.
        let runaway: [any CleanupScanner] = sandboxed ? [] : [RunawayTempScanner()]

        switch self {
        case .smartScan:
            return runaway + xcode + devCache + appCache + staleCache
                + [LargeFileScanner(), DuplicateScanner()]
        case .junk:
            return runaway + xcode + devCache + appCache + staleCache
        case .largeFile:
            return [LargeFileScanner()]
        case .duplicate:
            return [DuplicateScanner()]
        case .diskMap:
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
        case .largeFile: (0xB69BFF, 0x5B33C4)
        case .duplicate: (0x5FD3C4, 0x0C6558)
        case .diskMap:   (0x7ED88F, 0x186628)
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

    public var coordinator: ScanCoordinator { ScanCoordinator(scanners: scanners) }
}
