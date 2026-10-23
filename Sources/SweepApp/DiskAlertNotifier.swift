import AppKit
import UserNotifications
import SweepKit

/// 디스크 부족 알림을 macOS 알림 센터로 보내고, 누르면 Sweep 창을 연다.
///
/// 판정은 `DiskWatcher`가 한다. 여기는 알림 센터와 창 열기만 맡는다 — 로컬 알림뿐이고
/// 네트워크도 데이터 수집도 없다.
@MainActor
final class DiskAlertNotifier: NSObject, UNUserNotificationCenterDelegate {

    /// 고정이다. 같은 식별자로 보내면 알림 센터에 쌓이지 않고 교체된다.
    static let identifier = "disk-low"

    private var diskMapAuthorizationAsked = false
    private var diskMapAuthorizationTask: Task<Void, Never>?
    private let app: AppModel
    private(set) var watcher: DiskWatcher!

    /// 창을 앞으로 부르는 동작. `openWindow`는 씬 환경에서만 얻을 수 있어 앱이 넣어 준다.
    var openMain: (() -> Void)?

    /// SPM 실행 파일(`swift run`)은 앱 번들이 아니다. 그때 `UNUserNotificationCenter.current()`를
    /// 부르면 번들 식별자가 없어 프로세스가 죽는다 — 알림 기능만 조용히 끈다.
    private var center: UNUserNotificationCenter? {
        Bundle.main.bundleURL.pathExtension == "app" ? .current() : nil
    }

    init(app: AppModel, interval: Duration) {
        self.app = app
        super.init()
        watcher = DiskWatcher(interval: interval) { [weak self] usage in
            self?.post(usage)
        }
        // 앱이 다 뜨기 전에 등록해야 알림을 눌러 앱이 실행된 경우도 받는다.
        center?.delegate = self
        refreshAuthorization()
        // 시스템 설정에서 알림을 끄고 돌아오는 경우. 돌아올 때마다 다시 묻는다.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshAuthorization() }
        }
    }

    /// [켜기]·설정 스위치. 권한을 처음 묻는 것도 여기다 — 앱을 열자마자 묻지 않는다.
    func enable() {
        watcher.consentAsked = true
        guard let center else { watcher.isEnabled = true; return }
        Task {
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            watcher.isAuthorized = granted
            watcher.isEnabled = true
        }
    }

    func refreshAuthorization() {
        guard let center else { return }
        Task {
            let status = await center.notificationSettings().authorizationStatus
            watcher.isAuthorized = status == .authorized || status == .provisional
        }
    }

    /// Separate consent from the disk-space watcher toggle. Only ask on the first load.
    func diskMapLoadingStarted() {
        guard !diskMapAuthorizationAsked, let center else { return }
        diskMapAuthorizationAsked = true
        diskMapAuthorizationTask = Task {
            let status = await center.notificationSettings().authorizationStatus
            if status == .notDetermined {
                _ = try? await center.requestAuthorization(options: [.alert, .sound])
            }
            refreshAuthorization()
        }
    }

    func postDiskMapDone() {
        guard let center else { return }
        Task {
            await diskMapAuthorizationTask?.value
            let status = await center.notificationSettings().authorizationStatus
            guard status == .authorized || status == .provisional,
                  !(NSApp.isActive && app.selected == .diskMap) else { return }
            let content = UNMutableNotificationContent()
            content.title = String(localized: "공간 보기 준비가 끝났어요")
            content.body = String(localized: "어느 폴더가 공간을 많이 쓰는지 확인해 보세요")
            try? await center.add(UNNotificationRequest(
                identifier: "diskmap-done", content: content, trigger: nil))
        }
    }

    private func post(_ usage: VolumeUsage) {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "저장 공간이 얼마 남지 않았어요")
        content.body = String(localized: "남은 저장 공간은 \(usage.formattedAvailable)예요. 눌러서 정리할 파일을 찾아보세요.")
        let request = UNNotificationRequest(identifier: Self.identifier, content: content, trigger: nil)
        // 전송이 거부되면 감시기에 알린다. 안 그러면 알림이 안 갔는데도 "보냈다"고 쳐서 다시 시도하지 않는다.
        center.add(request) { [weak self] error in
            guard error != nil else { return }
            Task { @MainActor in self?.watcher.deliveryFailed() }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// 검색을 자동으로 시작하지 않는다. 알림 한 번에 43초 스캔을 돌리지 않는다.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let isDiskMap = response.notification.request.identifier == "diskmap-done"
        await MainActor.run {
            app.selected = isDiskMap ? .diskMap : .smartScan
            openMain?()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    /// Sweep이 앞에 있어도 배너를 띄운다. 기본은 앞에 있으면 아무것도 보이지 않는다.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        if notification.request.identifier == "diskmap-done" {
            return await MainActor.run {
                NSApp.isActive && app.selected == .diskMap ? [] : [.banner, .list]
            }
        }
        return [.banner, .list]
    }
}
