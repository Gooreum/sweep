import SwiftUI
import SweepKit

/// 폴더 허용과 시스템 권한을 한곳에서 확인한다.
struct PermissionsSettingsView: View {
    @Bindable var app: AppModel
    let notifier: DiskAlertNotifier
    @Bindable var watcher: DiskWatcher

    @State private var failure: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if Sandbox.isActive {
                    Retro95GroupBox(title: String(localized: "폴더")) {
                        VStack(spacing: 0) {
                            ForEach(FolderAccess.grantables) { grantable in
                                folderRow(grantable)
                                if grantable != FolderAccess.grantables.last {
                                    Retro95Separator()
                                }
                            }
                        }
                        .background(R95.white)
                        .retroSunken()
                    }
                } else {
                    Text("이 빌드는 폴더 허용이 필요 없어요")
                        .font(Theme.bodyText)
                }

                Retro95GroupBox(title: String(localized: "전체 디스크 접근")) {
                    permissionRow(icon: .hardDrive,
                                  name: String(localized: "전체 디스크 접근"),
                                  purpose: fullDiskDescription,
                                  enabled: app.hasFullDiskAccess,
                                  measurable: app.canMeasureFullDiskAccess) {
                        Button("시스템 설정 열기") { PrivacySettings.openFullDiskAccess() }
                    }
                }

                Retro95GroupBox(title: String(localized: "알림")) {
                    permissionRow(icon: .info,
                                  name: String(localized: "알림"),
                                  purpose: String(localized: "저장 공간이 부족하면 알려드려요"),
                                  enabled: watcher.isAuthorized) {
                        // 아직 한 번도 묻지 않았으면 시스템 설정 목록에 Sweep이 없다. 앱이 먼저 묻는다.
                        if !watcher.isAuthorized && !watcher.isEnabled {
                            Button("켜기") { notifier.enable() }
                        } else {
                            Button("알림 설정 열기") { PrivacySettings.openNotifications() }
                        }
                    }
                }

                Text("폴더 허용은 macOS 시스템 설정에 나오지 않아요. 여기서 해제할 수 있어요.")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
        }
        // 열 때 맨 위(폴더)부터 보인다. 기본값이면 창이 열리며 아래로 밀려 폴더 줄이 잘렸다.
        .defaultScrollAnchor(.top)
        .foregroundStyle(Theme.textPrimary)
        .background(R95.gray)
        .buttonStyle(Retro95ButtonStyle())
        .onAppear {
            notifier.refreshAuthorization()
            app.refreshPermissions()
        }
        .alert("필요한 폴더와 달라요",
               isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("확인") { failure = nil }
        } message: {
            Text(failure ?? "")
        }
    }

    private var fullDiskDescription: String {
        guard app.canMeasureFullDiskAccess else {
            return String(localized: "홈 폴더를 허용하면 확인할 수 있어요")
        }
        return String(localized: "휴지통과 다른 앱이 저장한 파일도 찾을 수 있어요.")
            + " " + PermissionNotice.fullDiskAccessHowTo
    }

    private func folderRow(_ grantable: FolderAccess.Grantable) -> some View {
        let granted = app.isGranted(grantable)
        let ancestor = grantingAncestor(of: grantable)

        return permissionRow(icon: .folder,
                             name: PermissionNotice.name(of: grantable),
                             purpose: grantable.purpose,
                             enabled: granted,
                             inheritedFrom: ancestor.map { PermissionNotice.name(of: $0) }) {
            if ancestor == nil {
                if granted {
                    Button(String(localized: "folderAccess.revoke", defaultValue: "해제")) {
                        app.revokeFolderAccess(grantable)
                    }
                } else {
                    Button("허용…") {
                        if case .failed(let message) = FolderPicker.grant(grantable, app: app) {
                            failure = message
                        }
                    }
                }
            }
        }
    }

    /// 가장 넓은 허용부터 찾는다. 홈도 이 Mac 덕분에 열릴 수 있다.
    private func grantingAncestor(of grantable: FolderAccess.Grantable) -> FolderAccess.Grantable? {
        FolderAccess.grantables.first {
            isStrictAncestor($0.folder, of: grantable.folder) && app.isGranted($0)
        }
    }

    private func isStrictAncestor(_ ancestor: URL, of folder: URL) -> Bool {
        let parent = ancestor.resolvingSymlinksInPath().standardizedFileURL.pathComponents
        let child = folder.resolvingSymlinksInPath().standardizedFileURL.pathComponents
        return parent.count < child.count && child.starts(with: parent)
    }

    private func permissionRow<Action: View>(
        icon: PixelArt, name: String, purpose: String, enabled: Bool,
        measurable: Bool = true, inheritedFrom: String? = nil,
        @ViewBuilder action: () -> Action
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            PixelIcon(art: icon, size: 16)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 8) {
                Text(name).font(Theme.bodyText)
                Text(purpose)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    PixelIcon(art: measurable && enabled ? .check : .warning, size: 16)
                    if !measurable {
                        Text("확인 불가")
                    } else if let inheritedFrom {
                        Text("켜짐 · \(inheritedFrom)으로 열림")
                    } else if enabled {
                        Text("켜짐")
                    } else {
                        Text("꺼짐")
                    }
                }
                .font(Theme.caption)
                .foregroundStyle(measurable && enabled ? Theme.textSecondary : Theme.cautionText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            action()
                .fixedSize()
        }
        .padding(8)
    }
}
