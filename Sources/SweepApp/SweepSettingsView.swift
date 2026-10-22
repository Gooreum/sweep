import SwiftUI
import SweepKit

/// 앱 메뉴 › 설정…(⌘,). 권한과 디스크 부족 알림을 관리한다.
struct SweepSettingsView: View {
    @Bindable var app: AppModel
    let notifier: DiskAlertNotifier
    @Bindable var watcher: DiskWatcher

    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            Retro95WindowTitleBar(title: String(localized: "Sweep 설정"), icon: .computer,
                                  fullScreenable: false, minimizable: false)
                // 아래 탭 패널 배경이 안전 영역으로 번져 제목줄을 덮지 않게 위에 그린다(메인 창과 같다).
                .zIndex(1)
            Retro95TabView(selection: $selectedTab,
                           titles: [String(localized: "권한"), String(localized: "알림")]) { index in
                if index == 0 {
                    PermissionsSettingsView(app: app, notifier: notifier, watcher: watcher)
                } else {
                    notifications.padding(Theme.panelPadding)
                }
            }
            .padding(8)
        }
        // 툴바를 떼면 창이 예전 높이(툴바 포함)를 유지해 아래에 흰 띠가 남는다. 남는 높이까지 채운다.
        .frame(width: 640)
        .frame(minHeight: 680, maxHeight: .infinity)
        .foregroundStyle(R95.black)
        .background(R95.gray)
        .retroRaised()
        .background(WindowChromeConfigurator(auxiliary: true))
        .ignoresSafeArea(edges: .top)
        .onAppear { notifier.refreshAuthorization() }
    }

    private var notifications: some View {
        Retro95GroupBox(title: String(localized: "알림")) {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("저장 공간 부족 알림", isOn: Binding(
                    get: { watcher.isEnabled },
                    // 켤 때는 권한부터 묻는다. 끌 때는 바로 멈춘다.
                    set: { $0 ? notifier.enable() : (watcher.isEnabled = false) }
                ))
                .toggleStyle(.checkbox)

                Picker("알림을 받을 남은 용량", selection: $watcher.thresholdGB) {
                    ForEach(DiskWatchSettings.thresholdChoices, id: \.self) { gb in
                        Text("\(gb)GB").tag(gb)
                    }
                }
                .fixedSize()
                .disabled(!watcher.isEnabled)

                Text("남은 저장 공간을 5분마다 살펴봐요. Sweep을 종료하면 확인도 멈춰요.")
                    .font(Theme.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                // 켰는데 권한이 없다 = 거부했거나 시스템 설정에서 껐다. 앱이 다시 물을 수 없다.
                if watcher.isEnabled && !watcher.isAuthorized {
                    HStack(spacing: 6) {
                        Text("알림을 받으려면 시스템 설정에서 Sweep 알림을 켜 주세요")
                            .font(Theme.caption)
                            .foregroundStyle(Theme.cautionText)
                        Button("알림 설정 열기") { PrivacySettings.openNotifications() }
                            .buttonStyle(.link)
                            .font(Theme.caption)
                    }
                }
            }
        }
    }
}
