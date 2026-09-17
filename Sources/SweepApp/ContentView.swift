import SwiftUI
import SweepKit

/// 창 전체. 왼쪽 사이드바가 기능을 고르고 오른쪽이 그 기능의 화면이다.
struct ContentView: View {
    /// 앱이 소유한다 — 메뉴 명령도 같은 모델을 건드려야 한다.
    @Bindable var app: AppModel

    var body: some View {
        HStack(spacing: 0) {
            Sidebar(app: app)

            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.surface)
        }
        // 전역 액션을 타이틀바로 올린다. 별도 툴바 줄을 만들면 사이드바 위에
        // 가로줄이 하나 더 생겨 화면이 그만큼 낮아진다 — 타이틀바는 어차피 비어 있다.
        // 기능 이름은 **창 제목**으로 둔다. 툴바 항목에 맨 글자를 넣으면 시스템이
        // 유리 캡슐을 씌우는데, 버튼이 아닌 글자에는 여백이 없어 캡슐이 글자 상자에
        // 달라붙는다 — 한글은 글자 상자가 높아 위아래가 깎여 보였다.
        .navigationTitle(app.selected.displayName)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // 한 번에 고르는 가장 흔한 경우. 메뉴로 접어 두면 두 번 눌러야 한다.
                // 라벨에 직접 여백을 준다. 시스템 유리 캡슐은 라벨 크기에 맞춰
                // 그려지는데, 한글은 글자 상자가 높아 기본 상태로는 캡슐이 글자에
                // 바짝 붙어 **잘린 것처럼** 보인다. `.controlSize(.large)`로는
                // 캡슐이 거의 안 커져서(실측) 여백을 직접 넣는다.
                Button { app.currentModel?.apply(.safeOnly) } label: {
                    Text("안전 항목 선택").font(.system(size: 12))
                }
                .disabled(app.currentModel?.items.isEmpty ?? true)

                Button {
                    guard let model = app.currentModel else { return }
                    Task { await model.scan() }
                } label: {
                    Text("다시 검색").font(.system(size: 12))
                }
                .disabled(!app.canScan)
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch app.selected {
        case .diskMap:
            // 스캔 모델은 아니지만 **소유는 다른 기능과 똑같이** AppModel이 한다.
            // 뷰가 들고 있으면 탭을 옮기는 순간 트리가 사라져 10초를 다시 기다린다.
            DiskMapView(model: app.diskMap(), app: app)

        case .smartScan:
            // 첫 화면. 전체를 훑고 기능별로 얼마가 나왔는지 카드로 보여준다.
            SmartScanView(app: app, model: app.model(for: .smartScan))

        case .junk where app.needsFolderAccess:
            // App Store 빌드에서 개발 폴더를 아직 열지 않았다. 검색 버튼을 두면
            // 훑을 곳이 없어 늘 "정리할 항목이 없음"이 나온다 — 허락부터 받는다.
            FolderAccessView(app: app)

        case let feature:
            FeatureScreen(feature: feature, model: app.model(for: feature))
                // 기능을 바꾸면 뷰를 새로 만든다. 안 그러면 이전 기능의
                // 스크롤 위치와 애니메이션 상태가 그대로 따라온다.
                .id(feature)
        }
    }
}
