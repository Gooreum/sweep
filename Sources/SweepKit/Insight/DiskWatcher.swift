import Foundation
import Observation

/// 메뉴 막대에 떠 있는 동안 여유 공간을 주기적으로 읽고, 부족해지면 한 번 알린다.
///
/// UserNotifications를 import하지 않는다. 알림을 보내는 쪽은 주입받아서
/// 판정과 반복 여부를 앱 번들 없이 검증할 수 있게 둔다.
@MainActor
@Observable
public final class DiskWatcher {

    /// 회복 여유분. 기준 근처에서 오르내릴 때 알림이 다시 뜨지 않게 한다.
    public static let rearmMargin: Int64 = 2 * gigabyte
    public static let defaultInterval: Duration = .seconds(5 * 60)
    static let gigabyte: Int64 = 1_000_000_000

    public var isEnabled: Bool {
        didSet { settings.enabled = isEnabled; update() }
    }

    /// 기준을 바꾸면 새 상황이다. 장전을 다시 채워 새 기준으로 한 번은 알릴 수 있게 한다.
    public var thresholdGB: Int {
        didSet {
            settings.thresholdGB = thresholdGB
            settings.armed = true
        }
    }

    public var consentAsked: Bool {
        didSet { settings.consentAsked = consentAsked }
    }

    /// 알림 권한. 권한이 없으면 보낼 수 없으니 감시도 돌리지 않는다.
    /// 앱이 알림 센터에 물어보고 채운다.
    public var isAuthorized = false {
        didSet { update() }
    }

    public var isRunning: Bool { task != nil }

    public var policy: DiskAlertPolicy {
        DiskAlertPolicy(threshold: Int64(thresholdGB) * Self.gigabyte,
                        rearmMargin: Self.rearmMargin)
    }

    private let settings: DiskWatchSettings
    private let readVolumeUsage: @MainActor () -> VolumeUsage?
    private let notify: @MainActor (VolumeUsage) -> Void
    private let interval: Duration
    @ObservationIgnored private var task: Task<Void, Never>?

    public init(
        settings: DiskWatchSettings = .shared,
        interval: Duration = DiskWatcher.defaultInterval,
        readVolumeUsage: @escaping @MainActor () -> VolumeUsage? = { VolumeUsage.current() },
        notify: @escaping @MainActor (VolumeUsage) -> Void
    ) {
        self.settings = settings
        self.interval = interval
        self.readVolumeUsage = readVolumeUsage
        self.notify = notify
        isEnabled = settings.enabled
        thresholdGB = settings.thresholdGB
        consentAsked = settings.consentAsked
    }

    /// 판정을 한 번 돌린다. 알렸으면 true. 꺼져 있거나 권한이 없으면 읽지도 않는다.
    @discardableResult
    public func tick() -> Bool {
        guard isEnabled, isAuthorized else { return false }
        let usage = readVolumeUsage()
        let result = policy.evaluate(usage, armed: settings.armed)
        settings.armed = result.armed
        if result.notify, let usage { notify(usage) }
        return result.notify
    }

    /// 켜져 있고 권한이 있으면 돌리고, 아니면 멈춘다. 설정이 바뀔 때마다 부른다.
    private func update() {
        if isEnabled && isAuthorized { start() } else { stop() }
    }

    private func start() {
        guard task == nil else { return }
        let interval = interval
        task = Task { [weak self] in
            while !Task.isCancelled {
                // 잠자는 동안 감시기를 붙잡지 않는다
                self?.tick()
                try? await Task.sleep(for: interval)
            }
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
    }
}
