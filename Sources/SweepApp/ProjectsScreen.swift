import SwiftUI
import SweepKit

/// 개발 프로젝트 탭. 위에 「보는 폴더」 줄, 아래에 산출물 목록.
///
/// 등록한 폴더가 없으면 스캐너가 없어(`Feature.isScannable == false`) 목록 대신
/// 폴더를 등록받는 입구만 보인다. 정크 탭이 허락 전에 하는 것과 같다.
struct ProjectsScreen: View {
    @Bindable var app: AppModel

    /// 등록을 거절한 이유. nil이면 닫혀 있다.
    @State private var failure: String?

    var body: some View {
        // 폴더 수가 바뀌면 다시 그린다. 목록 자체는 관찰되지 않는 저장소에 있다.
        let _ = app.projectFolderCount
        let folders = app.projectFolderURLs

        VStack(spacing: 8) {
            if folders.isEmpty {
                emptyState
            } else {
                foldersBox(folders)
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                FeatureScreen(feature: .projects, model: app.model(for: .projects))
                    .id(Feature.projects)
            }
        }
        .alert("이 폴더는 추가할 수 없어요",
               isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("확인") { failure = nil }
        } message: {
            Text(failure ?? "")
        }
    }

    private var emptyState: some View {
        Retro95Dialog(title: String(localized: "프로젝트는 어디에 있나요?"), icon: .devProject) {
            VStack(alignment: .leading, spacing: 12) {
                Text("프로젝트가 있는 폴더를 추가해 주세요. package.json이나 Cargo.toml 같은 설정 파일이 있는 곳에서 다시 만들 수 있는 폴더만 찾아요.")
                    .font(R95.ui())
                    .foregroundStyle(R95.deep)
                    .multilineTextAlignment(.leading)
                HStack {
                    Spacer()
                    Button("폴더 추가…") { addFolder() }
                        .buttonStyle(Retro95ButtonStyle())
                }
            }
        }
        .frame(maxWidth: R95.dialogWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func foldersBox(_ folders: [URL]) -> some View {
        Retro95GroupBox(title: String(localized: "보는 폴더")) {
            VStack(spacing: 0) {
                ForEach(folders, id: \.self) { folder in
                    row(folder)
                }
                HStack {
                    Spacer()
                    Button("추가…") { addFolder() }
                        .buttonStyle(Retro95ButtonStyle())
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .background(R95.white)
            .retroSunken()
        }
    }

    @ViewBuilder
    private func row(_ folder: URL) -> some View {
        let grantable = ProjectFolders.grantable(for: folder)
        // 샌드박스에서 북마크를 되살리지 못한 폴더(옮겼거나 지운 경우)는 다시 열어 달라고 한다.
        let reachable = !Sandbox.isActive || app.isGranted(grantable)

        HStack(spacing: 12) {
            PixelIcon(art: .folder, size: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(ProjectFolders.displayPath(folder))
                    .font(Theme.bodyMono)
                if !reachable {
                    Text("다시 골라 주세요")
                        .font(Theme.caption)
                        .foregroundStyle(R95.danger)
                }
            }
            Spacer(minLength: 12)
            if !reachable {
                Button("열기…") { reopen(grantable) }
                    .buttonStyle(Retro95ButtonStyle())
            }
            Button("빼기") { app.removeProjectFolder(folder) }
                .buttonStyle(Retro95ButtonStyle())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private func addFolder() {
        guard let picked = FolderPicker.askProjectFolder() else { return }
        do {
            try app.addProjectFolder(picked)
        } catch {
            failure = ProjectFolders.message(for: error)
        }
    }

    private func reopen(_ grantable: FolderAccess.Grantable) {
        guard let picked = FolderPicker.ask(for: grantable) else { return }
        do {
            try app.grantFolderAccess(picked, as: grantable)
        } catch {
            failure = error.message
        }
    }
}
