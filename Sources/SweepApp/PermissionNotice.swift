import SwiftUI
import SweepKit

/// 이 화면을 쓰려면 켜야 하는 것을 알리는 줄. 그 자리에서 켜는 버튼을 같이 둔다.
///
/// 권한이 없으면 결과가 조용히 빈다. "정리할 것 없음"으로 읽히면 사용자는 권한이
/// 꺼진 줄 모른다 — 실제로 휴지통을 못 연다는 말만 듣고 무엇을 켜야 하는지 몰랐다.
struct PermissionNotice: View {
    let need: PermissionNeed
    let feature: Feature
    let app: AppModel

    /// 틀린 폴더를 골랐을 때 알려줄 말. nil이면 닫혀 있다.
    @State private var failure: String?

    var body: some View {
        switch need {
        case .folder(let grantable):
            folderRow(grantable)
        case .fullDiskAccess:
            FullDiskAccessBanner(message: fullDiskAccessMessage)
        }
    }

    private func folderRow(_ grantable: FolderAccess.Grantable) -> some View {
        HStack(spacing: 12) {
            PixelIcon(art: .warning, size: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text("‘\(Self.name(of: grantable))’ 폴더를 아직 허용하지 않았어요")
                    .font(Theme.bodyText)
                    .foregroundStyle(Theme.textPrimary)
                Text(folderMessage(grantable))
                    .font(Theme.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer(minLength: 12)

            Button("허용…") {
                if case .failed(let message) = FolderPicker.grant(grantable, app: app) {
                    failure = message
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(R95.gray)
        .retroRaised()
        .buttonStyle(Retro95ButtonStyle())
        .alert("필요한 폴더와 달라요",
               isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("확인") { failure = nil }
        } message: {
            Text(failure ?? "")
        }
    }

    /// 홈은 라벨이 `~`라 문장에 넣으면 읽히지 않는다.
    static func name(of grantable: FolderAccess.Grantable) -> String {
        grantable == FolderAccess.home ? String(localized: "홈") : grantable.label
    }

    /// 지금 무엇을 못 보고 있는지 먼저 말한다. 허용하면 무엇이 달라지는지가 그 다음이다.
    private func folderMessage(_ grantable: FolderAccess.Grantable) -> String {
        switch feature {
        case .largeFile, .duplicate:
            String(localized: "지금은 다운로드 폴더에서만 찾아요. 홈 폴더를 허용하면 문서·데스크탑 등 내 폴더 전체에서 찾아요.")
        case .trash:
            String(localized: "휴지통은 홈 폴더 안에 있어요. 홈 폴더를 허용해야 버린 파일을 찾을 수 있어요.")
        default:
            grantable.purpose
        }
    }

    private var fullDiskAccessMessage: String {
        let reason = feature == .trash
            ? String(localized: "휴지통 안을 보려면 시스템 설정의 전체 디스크 접근에서 Sweep을 켜 주세요.")
            : String(localized: "시스템 설정의 전체 디스크 접근에서 Sweep을 켜 주세요.")
        return reason + " " + Self.fullDiskAccessHowTo
    }

    /// App Store 빌드는 목록에 처음부터 없을 수 있다. 켜고 돌아오면 다시 재므로 그것도 말한다.
    static let fullDiskAccessHowTo = String(localized: "목록에 Sweep이 없으면 + 버튼으로 추가해 주세요. 켜고 돌아오면 바로 반영돼요.")
}
