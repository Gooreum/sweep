import Foundation

/// 스캔 결과를 사용자에게 보여주는 최상위 분류.
public enum ScanCategory: String, CaseIterable, Sendable, Hashable {
    /// 폭주 중인 임시 파일. 이 앱의 존재 이유.
    case runawayTemp
    /// Xcode / 시뮬레이터 계열 산출물.
    case xcode
    /// 재생성 가능한 개발 도구 캐시.
    case devCache
    /// 앱이 만든 웹 캐시. Electron·Chromium 앱이 공통 이름으로 쌓는다.
    case appCache
    /// 오래 손대지 않은 캐시.
    /// 주인이 사라졌는지는 알 수 없으므로 "묵었다"고만 말한다.
    case staleCache
    /// 허용 루트 안의 크고 독립적인 파일.
    case largeFile
    /// 내용이 같은 중복 파일.
    case duplicate

    public var displayName: String {
        switch self {
        case .runawayTemp: String(localized: "폭주 임시 파일")
        case .xcode: String(localized: "Xcode · 시뮬레이터")
        case .devCache: String(localized: "개발 캐시")
        case .appCache: String(localized: "앱 웹 캐시")
        case .staleCache: String(localized: "묵은 캐시")
        case .largeFile: String(localized: "대용량 파일")
        case .duplicate: String(localized: "중복 파일")
        }
    }

    /// 목록에서의 표시 순서. 위험한 것이 위로 온다.
    /// 뒤로 갈수록 "재생성 쉬움"에서 "사용자 판단이 필요함"으로 옮겨간다.
    public var sortOrder: Int {
        switch self {
        case .runawayTemp: 0
        case .xcode: 1
        case .devCache: 2
        case .appCache: 3
        case .staleCache: 4
        case .largeFile: 5
        case .duplicate: 6
        }
    }

    /// 이 분류의 항목을 어느 관문 범위로 검사할지.
    ///
    /// 큰 파일·중복 파일만 사용자 폴더(`~/Documents` 등)를 연다. 나머지가 그 폴더 경로를
    /// 내면 버그이고, 관문이 막아야 한다.
    public var removalScope: RemovalScope {
        switch self {
        case .largeFile, .duplicate: .userFiles
        default: .cleanup
        }
    }

    public var systemImageName: String {
        switch self {
        case .runawayTemp: "exclamationmark.triangle.fill"
        case .xcode: "hammer.fill"
        case .devCache: "shippingbox.fill"
        case .appCache: "globe"
        case .staleCache: "clock.arrow.circlepath"
        case .largeFile: "arrow.down.doc.fill"
        case .duplicate: "doc.on.doc.fill"
        }
    }
}
