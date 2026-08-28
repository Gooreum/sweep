import Foundation

/// 항목을 지웠을 때의 위험도.
///
/// 기본 선택 여부를 여기서 결정한다. 사용자가 아무 생각 없이 "전체 선택 → 삭제"를 눌러도
/// 되돌릴 수 없는 것은 빠져 있어야 한다.
public enum SafetyLevel: String, CaseIterable, Sendable, Hashable, Comparable {
    /// 재생성된다. 지워도 잃는 것이 없다. (DerivedData, 각종 캐시)
    case safe
    /// 다시 받거나 다시 만들 수 있지만 시간이 든다. (시뮬레이터 런타임, DeviceSupport)
    case caution
    /// 복구 불가능하거나 대체물이 없다. (Archives — 앱 심사 제출본)
    case danger

    /// 스캔 직후 체크되어 있는지 여부. safe만 기본 선택된다.
    public var isSelectedByDefault: Bool { self == .safe }

    public var displayName: String {
        switch self {
        case .safe: "안전"
        case .caution: "주의"
        case .danger: "위험"
        }
    }

    /// 목록에서 좌측에 경고 바를 그릴지 여부.
    /// 되돌릴 수 없는 것만 표시한다 — 전부 표시하면 아무것도 눈에 띄지 않는다.
    public var needsWarningBar: Bool { self == .danger }

    /// 위험할수록 큰 값. 목록 정렬과 비교에 쓴다.
    private var rank: Int {
        switch self {
        case .safe: 0
        case .caution: 1
        case .danger: 2
        }
    }

    public static func < (lhs: SafetyLevel, rhs: SafetyLevel) -> Bool {
        lhs.rank < rhs.rank
    }
}
