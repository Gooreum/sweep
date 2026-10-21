import SwiftUI
import SweepKit

/// 창 전체. 왼쪽 사이드바가 기능을 고르고 오른쪽이 그 기능의 화면이다.
struct ContentView: View {
    /// 앱이 소유한다 — 메뉴 명령도 같은 모델을 건드려야 한다.
    @Bindable var app: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Sidebar(app: app)
                VStack(spacing: 0) {
                    Retro95TitleStrip(title: "Sweep - \(app.selected.displayName)",
                                      icon: app.selected.pixelArt)
                    // 디스크 맵·폴더 허락 화면은 스캔하지 않으므로 명령이 없다.
                    if app.currentModel != nil {
                        CommandBar(app: app)
                    }
                    detail
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .background(R95.gray)
            }
            AppStatusBar(app: app)
        }
        .background(R95.gray)
        // 기능 이름은 **창 제목**으로 둔다. 명령은 시스템 툴바가 아니라 창 안의 명령줄에 있다 —
        // 툴바에 두면 둥근 유리 캡슐로 그려져 Win95 화면과 따로 논다.
        .navigationTitle(app.selected.displayName)
    }

    @ViewBuilder
    private var detail: some View {
        switch app.selected {
        case .diskMap:
            // 스캔 모델은 아니지만 **소유는 다른 기능과 똑같이** AppModel이 한다.
            // 뷰가 들고 있으면 탭을 옮기는 순간 트리가 사라져 10초를 다시 기다린다.
            DiskMapView(model: app.diskMap(), app: app)

        case .cpu:
            // 스캔 모델이 없다. 디스크 맵과 같은 이유로 소유는 AppModel이 한다.
            //
            // **아래 `case let feature:`보다 위에 있어야 한다.** catch-all이
            // 먼저 잡으면 스캐너 0개짜리 FeatureScreen으로 떨어져 검색 버튼만
            // 있는 빈 화면이 되는데, 컴파일은 그대로 통과한다.
            CPUView(model: app.cpu())

        case .smartScan:
            // 첫 화면. 전체를 훑고 기능별로 얼마가 나왔는지 카드로 보여준다.
            SmartScanView(app: app, model: app.model(for: .smartScan))

        case .junk where app.needsFolderAccess:
            // App Store 빌드에서 개발 폴더를 아직 열지 않았다. 검색 버튼을 두면
            // 훑을 곳이 없어 늘 "정리할 항목이 없음"이 나온다 — 허락부터 받는다.
            FolderAccessView(app: app)

        case .projects:
            // 등록한 폴더가 없으면 화면이 등록 입구가 된다. 있으면 「보는 폴더」 줄 아래에 목록.
            ProjectsScreen(app: app)

        case let feature:
            FeatureScreen(feature: feature, model: app.model(for: feature))
                // 기능을 바꾸면 뷰를 새로 만든다. 안 그러면 이전 기능의
                // 스크롤 위치와 애니메이션 상태가 그대로 따라온다.
                .id(feature)
        }
    }
}

/// 진행률을 읽는 곳을 이 줄로 가둔다. ContentView가 읽으면 진행 tick마다
/// 사이드바·타이틀·화면까지 창 전체가 다시 평가된다.
private struct AppStatusBar: View {
    let app: AppModel

    var body: some View {
        let line = app.statusLine
        Retro95StatusBar(segments: [
            .init(text: line.status),
            .init(text: line.count, width: 170),
            .init(text: line.size, width: 190),
        ])
    }
}

/// 시스템 툴바 대신 창 안의 명령줄. 주 동작이 스크롤에 밀려 화면 밖으로 사라지지 않는다.
private struct CommandBar: View {
    let app: AppModel

    var body: some View {
        // 세로 패딩 없이 `frame(height:)` 안에서 중심 정렬한다. 패딩을 두면 기본 베벨의
        // 1px 테두리 때문에 검색 버튼만 반 픽셀 밀려 두 버튼의 중심이 어긋난다.
        HStack(alignment: .center, spacing: 8) {
            // 주 동작. 12pt 회색 버튼이었을 때 사용자가 못 찾았다 — 아이콘과 굵은 글자로 키운다.
            // `CommandBar`는 `currentModel`이 있을 때만 그려지므로 `if let`은 안전망이다.
            if let model = app.currentModel {
                ScanButton(model: model,
                           title: app.selected == .smartScan
                               ? String(localized: "전체 검색") : String(localized: "검색"),
                           showsShortcut: true)
            }

            // 한 번에 고르는 가장 흔한 경우. 메뉴로 접어 두면 두 번 눌러야 한다.
            // 검색 버튼과 같은 높이·글자 크기로 나란히 선다. 보조 동작이라 굵기와
            // 기본 베벨은 주지 않는다 — 둘 다 굵으면 어느 쪽이 주 동작인지 모른다.
            Button { app.currentModel?.apply(.safeOnly) } label: {
                HStack(spacing: 8) {
                    PixelIcon(art: .check, size: 24)
                    Text("안전 항목 선택")
                        .font(R95.ui(14))
                }
                .frame(minHeight: ItemTableColumns.actionButtonHeight - 10)
            }
            .buttonStyle(Retro95ButtonStyle())
            .disabled(app.currentModel?.items.isEmpty ?? true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(height: 48)
        .background(R95.gray)
        .overlay(alignment: .bottom) { Retro95Separator() }
    }
}
