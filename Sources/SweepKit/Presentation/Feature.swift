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
        case .junk: "임시 파일·빌드 산출물·개발 캐시를 찾아 디스크 공간을 확보합니다."
        case .largeFile: "허용된 범위 안에서 유난히 큰 파일을 찾습니다."
        case .duplicate: "내용이 같은 파일을 찾아 한 벌만 남깁니다."
        case .diskMap: "어디가 용량을 차지하는지 크기순으로 훑어봅니다."
        }
    }

    /// 이 기능이 돌리는 스캐너. 디스크 맵은 읽기 전용이라 하나도 없다.
    public var scanners: [any CleanupScanner] {
        switch self {
        case .smartScan:
            [RunawayTempScanner(), XcodeScanner(), DevCacheScanner(),
             StaleCacheScanner(), LargeFileScanner(), DuplicateScanner()]
        case .junk:
            [RunawayTempScanner(), XcodeScanner(), DevCacheScanner(), StaleCacheScanner()]
        case .largeFile:
            [LargeFileScanner()]
        case .duplicate:
            [DuplicateScanner()]
        case .diskMap:
            []
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
