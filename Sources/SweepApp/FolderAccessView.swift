import SwiftUI
import AppKit
import SweepKit

/// 샌드박스(App Store 빌드)의 정크 파일 탭. `~/Library/Developer`를 열어 달라고 한다.
///
/// 샌드박스는 이 폴더를 스스로 열 수 없다. 사용자가 열기 대화상자에서 고른 폴더만
/// 열리므로, 무엇을 왜 고르는지 먼저 말하고 대화상자를 그 폴더에서 연다.
struct FolderAccessView: View {
    @Bindable var app: AppModel

    /// 틀린 폴더를 골랐을 때 알려줄 말. nil이면 닫혀 있다.
    @State private var failure: String?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hammer")
                .font(.system(size: Theme.Icon.large))
                .foregroundStyle(Theme.accentText)

            Text("Xcode · 시뮬레이터 정리")
                .font(Theme.title)

            VStack(spacing: 6) {
                Text("App Store 버전은 macOS 샌드박스 안에서 동작해서, 개발 폴더를 열려면 한 번 허락이 필요해요.")
                Text("다음 창에서 Library › Developer 폴더가 선택된 그대로 \"허용\"을 누르세요.")
            }
            .font(Theme.bodyText)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 460)

            Button("개발 폴더 열기…") { choose() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 8)
        }
        .alert("다른 폴더를 골랐습니다",
               isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("확인") { failure = nil }
        } message: {
            Text(failure ?? "")
        }
    }

    /// Phase 4에서 폴더별 줄로 펼친다. 지금은 첫 항목(`~/Library`)만 연다.
    private var grantable: FolderAccess.Grantable { FolderAccess.grantables[0] }

    private func choose() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        // 그 폴더 안에서 연다. 사용자는 아무것도 고르지 않고 "허용"만 누르면 된다.
        panel.directoryURL = grantable.folder
        panel.prompt = "허용"
        panel.message = "Sweep이 Xcode 산출물과 시뮬레이터 파일을 찾을 수 있게 Developer 폴더를 허용하세요."

        guard panel.runModal() == .OK, let picked = panel.url else { return }
        do {
            try app.grantFolderAccess(picked, as: grantable)
        } catch {
            failure = error.message
        }
    }
}
