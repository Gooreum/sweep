import SwiftUI
import SweepKit

/// Finder에서 휴지통을 여는 버튼. 열지 못하면 **왜 못 여는지와 켜는 버튼**을 같이 띄운다.
///
/// 샌드박스에서 `~/.Trash`는 홈 폴더 허용과 전체 디스크 접근이 둘 다 있어야 열린다(실측).
/// 화면마다 따로 두었을 때는 실패를 무시하거나 "Dock에서 여세요"만 말해서,
/// 사용자는 권한이 없다는 것만 알고 무엇을 켜야 하는지 몰랐다.
///
/// 비우지는 않는다 — 영구 삭제는 사용자가 Finder에서 직접 한다.
struct TrashOpenButton: View {
    var app: AppModel?
    /// 권한 문제가 아닐 때 할 말. 화면마다 다음 할 일이 달라 넘겨받는다(되돌려 놓기 안내 등).
    var fallback: LocalizedStringKey = "화면 아래 Dock에서 휴지통을 열고 필요한 파일이 남아 있는지 확인해 주세요. 휴지통을 비우면 복구할 수 없어요."

    @State private var need: PermissionNeed?
    @State private var failed = false
    /// 다른 폴더를 골랐을 때 알려줄 말.
    @State private var grantFailure: String?

    var body: some View {
        Button("휴지통 열기") { open() }
            .alert(need == nil ? "휴지통을 열지 못했어요" : "휴지통을 열 권한이 꺼져 있어요",
                   isPresented: $failed) {
                switch need {
                case .folder(let grantable):
                    Button("홈 폴더 허용…") { grant(grantable) }
                case .fullDiskAccess:
                    Button("시스템 설정 열기") { PrivacySettings.openFullDiskAccess() }
                case nil:
                    EmptyView()
                }
                Button("닫기", role: .cancel) {}
            } message: {
                switch need {
                case .folder:
                    Text("휴지통은 홈 폴더 안에 있어요. 홈 폴더를 허용하면 열 수 있어요.")
                case .fullDiskAccess:
                    Text("macOS가 휴지통을 보호하고 있어요. 시스템 설정의 전체 디스크 접근에서 Sweep을 켜 주세요. \(PermissionNotice.fullDiskAccessHowTo)")
                case nil:
                    Text(fallback)
                }
            }
            .alert("필요한 폴더와 달라요",
                   isPresented: Binding(get: { grantFailure != nil }, set: { if !$0 { grantFailure = nil } })) {
                Button("확인") { grantFailure = nil }
            } message: {
                Text(grantFailure ?? "")
            }
    }

    private func open() {
        guard !ItemActions.openTrash() else { return }
        need = ItemActions.trashOpenNeed()
        failed = true
    }

    /// 허용하면 바로 다시 연다. 전체 디스크 접근이 아직 없으면 그 안내가 이어서 뜬다.
    private func grant(_ grantable: FolderAccess.Grantable) {
        switch FolderPicker.grant(grantable, app: app) {
        case .granted:
            // 지금 닫히는 알림 뒤에 새 알림을 띄워야 한다. 같은 틱에 올리면 SwiftUI가 무시한다.
            DispatchQueue.main.async { open() }
        case .cancelled:
            break
        case .failed(let message):
            grantFailure = message
        }
    }
}
