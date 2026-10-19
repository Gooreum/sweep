import Foundation

/// 디스크 맵 행 하나의 삭제 판정. 세 갈래다 — 지워도 됨 / 확인 필요 / 보호됨.
///
/// 관문(`ProtectedPaths`)은 "막히는가"만 답한다. 막히지 않는 것 중에도 캐시처럼 지워도
/// 잃는 게 없는 것과, 내 문서처럼 지울 수는 있지만 되돌릴 수 없는 것이 섞여 있다.
/// 그 둘을 한 색으로 칠하면 사용자는 뭘 믿고 눌러야 할지 모른다.
public enum RemovalVerdict: Equatable, Sendable {
    /// 다시 만들어지는 것. 캐시·로그·빌드 산출물·임시 파일.
    case safe(reason: String)
    /// 내 소유라 지울 수는 있지만 되돌릴 수 없을 수 있는 것. 내 파일·앱 데이터·내려받은 것.
    case caution(reason: String)
    /// 관문이 막는다.
    case blocked(RemovalVeto)

    /// 배지 색. 기존 안전도 팔레트를 그대로 쓴다.
    public var level: SafetyLevel {
        switch self {
        case .safe: .safe
        case .caution: .caution
        case .blocked: .danger
        }
    }

    /// 배지 글자.
    public var title: String {
        switch self {
        case .safe: String(localized: "지워도 됨")
        case .caution: String(localized: "확인 필요")
        case .blocked: String(localized: "보호됨")
        }
    }

    /// 왜 그렇게 판정했는지 한 문장. 툴팁·설명 줄·확인 대화상자에 그대로 쓴다.
    public var reason: String {
        switch self {
        case .safe(let reason), .caution(let reason): reason
        case .blocked(let veto): veto.message
        }
    }

    /// 막는 사유. 막히지 않으면 nil.
    public var veto: RemovalVeto? {
        if case .blocked(let veto) = self { veto } else { nil }
    }

    public var allowsRemoval: Bool { veto == nil }

    // MARK: - 판정

    /// 디스크 맵 범위로 관문을 지나고, 통과한 것은 위치로 안전/확인을 가른다.
    public static func forDiskMap(_ url: URL) -> RemovalVerdict {
        if let veto = ProtectedPaths.veto(for: url, scope: .diskMap) { return .blocked(veto) }
        return classify(url, home: Sandbox.userHome)
    }

    /// 홈을 주입받아 테스트한다. 관문은 거치지 않는다 — 위치 판정만 본다.
    ///
    /// 순서가 중요하다. 좁은 규칙(`Library/Developer/Xcode/DerivedData`)이 넓은 규칙
    /// (`Library` 일반)보다 먼저 와야 한다.
    static func classify(_ url: URL, home: URL) -> RemovalVerdict {
        let target = url.standardizedFileURL
        func under(_ relative: String) -> Bool {
            target.isDescendant(of: home.appending(path: relative))
        }

        // 안전 — 지워도 다시 만들어진다.
        if let rule = safeRules.first(where: { under($0.path) }) {
            return .safe(reason: rule.reason)
        }
        if target.isDescendant(of: URL(filePath: "/private/tmp"))
            || ProtectedPaths.userTemporaryRoots.contains(where: { target.isDescendant(of: $0) }) {
            return .safe(reason: String(localized: "임시 파일이에요. Mac을 재시동하면 비워져요."))
        }
        if under("Library/Application Support"), ProtectedPaths.matchesAppCacheName(target) {
            return .safe(reason: String(localized: "앱의 임시 파일이에요. 필요하면 앱이 다시 만들어요."))
        }

        // 확인 — 지울 수는 있지만 되돌릴 수 없을 수 있다. 위치별로 무엇이 사라지는지 말한다.
        if let rule = cautionRules.first(where: { under($0.path) }) {
            return .caution(reason: rule.reason)
        }
        if target.lastPathComponent.hasSuffix(".app") {
            return .caution(reason: String(localized: "앱이에요. 지우면 앱이 사라지고, 설정은 ~/Library 폴더에 남아요."))
        }
        if under("Library") {
            return .caution(reason: String(localized: "앱과 시스템의 설정 정보예요. 무엇인지 확실할 때만 지우세요."))
        }
        if target.isDescendant(of: home) {
            return .caution(reason: String(localized: "내 파일이에요. 휴지통으로 가지만 비우면 되돌릴 수 없어요."))
        }
        return .caution(reason: String(localized: "내 사용자 폴더 밖에 있는 내 소유 항목이에요. 어떤 프로그램이 쓰는지 확인하고 지우세요."))
    }

    private struct Rule {
        let path: String
        let reason: String
    }

    /// 지워도 다시 만들어지는 곳. 스캐너의 안전 판정과 같은 근거다.
    private static let safeRules: [Rule] = [
        .init(path: "Library/Developer/Xcode/DerivedData",
              reason: String(localized: "Xcode가 앱을 만들 때 다시 생겨요")),
        .init(path: "Library/Developer/CoreSimulator/Caches",
              reason: String(localized: "앱 시험 도구의 임시 파일이에요")),
        .init(path: "Library/Developer/CoreSimulator/Temp",
              reason: String(localized: "앱 시험 도구가 쓰다 남긴 임시 파일이에요")),
        .init(path: "Library/Caches",
              reason: String(localized: "앱의 임시 파일이에요. 필요하면 앱이 다시 만들어요.")),
        .init(path: "Library/Logs",
              reason: String(localized: "앱 활동 기록이에요. 다시 쌓여요.")),
        .init(path: ".npm/_cacache",
              reason: String(localized: "npm 임시 파일이에요. 설치할 때 다시 받아요.")),
        .init(path: ".expo",
              reason: String(localized: "Expo 임시 파일이에요. 앱을 만들 때 다시 받아요.")),
    ]

    /// 지울 수는 있지만 무엇이 사라지는지 알고 눌러야 하는 곳.
    private static let cautionRules: [Rule] = [
        .init(path: "Library/Developer/Xcode/Archives",
              reason: String(localized: "앱 심사 제출본이에요. 지우면 복구할 수 없어요")),
        .init(path: "Library/Developer/Xcode/iOS DeviceSupport",
              reason: String(localized: "기기를 다시 연결하면 내려받아요")),
        .init(path: "Library/Developer/DVTDownloads",
              reason: String(localized: "Xcode가 내려받은 구성요소예요")),
        .init(path: "Library/Developer/XCTestDevices",
              reason: String(localized: "앱을 시험하는 데 쓰는 가상 기기예요")),
        .init(path: "Library/Developer/CoreSimulator/Devices",
              reason: String(localized: "앱 시험용 가상 기기예요. 안의 앱과 데이터가 함께 사라져요.")),
        .init(path: "Library/Application Support",
              reason: String(localized: "앱 데이터예요. 지우면 그 앱의 설정, 로그인 정보, 문서가 사라질 수 있어요.")),
        .init(path: "Library/Containers",
              reason: String(localized: "앱이 따로 보관하는 데이터예요. 앱을 지웠다면 남은 파일이지만, 쓰는 앱이면 데이터가 사라져요.")),
        .init(path: "Library/Group Containers",
              reason: String(localized: "앱이 따로 보관하는 데이터예요. 앱을 지웠다면 남은 파일이지만, 쓰는 앱이면 데이터가 사라져요.")),
        .init(path: "Downloads",
              reason: String(localized: "내려받은 파일이에요. 다시 받을 수 있으면 지워도 돼요.")),
    ]
}
