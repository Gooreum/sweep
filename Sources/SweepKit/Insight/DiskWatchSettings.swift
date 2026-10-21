import Foundation

/// 디스크 부족 알림 설정 저장소.
///
/// `CleanupHistory`와 같은 모양이다 — 저장소를 주입하고, 테스트는
/// `UserDefaults(suiteName:)`를 넘겨 실제 설정을 건드리지 않는다.
public final class DiskWatchSettings: @unchecked Sendable {
    public static let shared = DiskWatchSettings()

    static let enabledKey = "diskWatch.enabled"
    static let thresholdKey = "diskWatch.thresholdGB"
    static let consentKey = "diskWatch.consentAsked"
    static let armedKey = "diskWatch.armed"

    /// 설정 화면에서 고를 수 있는 기준. 비율이 아니라 GB다 — 사람이 바로 이해한다.
    public static let thresholdChoices = [5, 10, 20, 50]
    public static let defaultThresholdGB = 10

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 옵트인이다. 묻기 전에는 꺼져 있다.
    public var enabled: Bool {
        get { defaults.bool(forKey: Self.enabledKey) }
        set { defaults.set(newValue, forKey: Self.enabledKey) }
    }

    public var thresholdGB: Int {
        get {
            let stored = defaults.integer(forKey: Self.thresholdKey)
            return stored > 0 ? stored : Self.defaultThresholdGB
        }
        set { defaults.set(newValue, forKey: Self.thresholdKey) }
    }

    /// 메뉴 막대 안내 줄을 이미 보여 줬는지. [켜기]든 [괜찮아요]든 한 번 답하면 다시 묻지 않는다.
    public var consentAsked: Bool {
        get { defaults.bool(forKey: Self.consentKey) }
        set { defaults.set(newValue, forKey: Self.consentKey) }
    }

    /// 저장해 두어야 앱을 다시 열어도 같은 부족 상황에서 알림이 또 뜨지 않는다.
    public var armed: Bool {
        get { defaults.object(forKey: Self.armedKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Self.armedKey) }
    }
}
