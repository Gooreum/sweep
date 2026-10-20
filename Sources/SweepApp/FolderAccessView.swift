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
        Retro95Dialog(title: String(localized: "어디에서 찾을까요?"), icon: .folder) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(spacing: 6) {
                    Text("파일을 찾으려면 폴더를 열 수 있어야 해요. 아래에서 찾을 곳을 허용해 주세요.")
                    Text("대부분은 맨 위 폴더 안에 있어요. 우선 그곳부터 열어 주세요.")
                }
                .font(R95.ui())
                .foregroundStyle(R95.deep)
                .multilineTextAlignment(.leading)

                Retro95GroupBox(title: String(localized: "찾을 폴더")) {
                    VStack(spacing: 0) {
                        ForEach(FolderAccess.grantables) { grantable in
                            row(for: grantable)
                        }
                    }
                    .background(R95.white)
                    .retroSunken()
                }
            }
        }
        .frame(maxWidth: R95.dialogWidth)
        .alert("필요한 폴더와 달라요",
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
            PixelIcon(art: granted ? .check : .folder, size: 16)

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
                    .buttonStyle(Retro95ButtonStyle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(R95.white)
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
