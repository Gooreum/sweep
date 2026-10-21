import SwiftUI
import SweepKit

/// 앱 메뉴 › 설정…(⌘,). 지금은 디스크 부족 알림 하나뿐이다.
struct SweepSettingsView: View {
    let notifier: DiskAlertNotifier
    @Bindable var watcher: DiskWatcher

    var body: some View {
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
        .padding(Theme.panelPadding)
        .frame(width: Theme.panelWidth)
        .foregroundStyle(R95.black)
        .background(R95.gray)
        .onAppear { notifier.refreshAuthorization() }
    }
}
