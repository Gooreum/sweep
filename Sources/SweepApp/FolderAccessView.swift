import SwiftUI
import AppKit
import SweepKit

/// 샌드박스(App Store 빌드)의 정크 파일 탭. 훑을 폴더를 열어 달라고 한다.
///
/// 샌드박스는 홈 아래를 스스로 열 수 없다. 사용자가 열기 대화상자에서 고른 폴더만
/// 열리므로, 무엇을 왜 고르는지 먼저 말하고 대화상자를 그 폴더에서 연다.
///
/// 폴더가 여럿이라 한 줄씩 늘어놓되 **맨 위 하나면 대부분 된다**고 말한다.
/// 셋 다 눌러야 할 것처럼 보이면 첫 화면부터 일이 많아 보인다.
struct FolderAccessView: View {
    @Bindable var app: AppModel

    /// 틀린 폴더를 골랐을 때 알려줄 말. nil이면 닫혀 있다.
    @State private var failure: String?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: Theme.Icon.large))
                .foregroundStyle(Theme.accentText)

            Text("정리할 폴더 열기")
                .font(Theme.title)

            VStack(spacing: 6) {
                Text("App Store 버전은 macOS 샌드박스 안에서 동작해서, 폴더를 열려면 한 번 허락이 필요해요.")
                Text("맨 위 하나만 허용해도 대부분 찾을 수 있어요.")
            }
            .font(Theme.bodyText)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 460)

            VStack(spacing: 8) {
                ForEach(FolderAccess.grantables) { grantable in
                    row(for: grantable)
                }
            }
            .frame(maxWidth: 460)
            .padding(.top, 8)
        }
        .alert("다른 폴더를 골랐습니다",
               isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("확인") { failure = nil }
        } message: {
            Text(failure ?? "")
        }
    }

    @ViewBuilder
    private func row(for grantable: FolderAccess.Grantable) -> some View {
        let granted = app.isGranted(grantable)

        HStack(spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(granted ? Color.green : Color.secondary)
                .font(.system(size: Theme.Icon.small))

            VStack(alignment: .leading, spacing: 2) {
                Text(grantable.label)
                    .font(Theme.bodyText)
                Text(grantable.purpose)
                    .font(Theme.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            if granted {
                Text("허용됨")
                    .font(Theme.caption)
                    .foregroundStyle(.secondary)
            } else {
                Button("열기…") { choose(grantable) }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    private func choose(_ grantable: FolderAccess.Grantable) {
        guard let picked = FolderPicker.ask(for: grantable) else { return }
        do {
            try app.grantFolderAccess(picked, as: grantable)
        } catch {
            failure = error.message
        }
    }
}
