import SwiftUI
import SweepKit

/// 창 전체. 왼쪽 사이드바가 기능을 고르고 오른쪽이 그 기능의 화면이다.
struct ContentView: View {
    @State private var app = AppModel()

    var body: some View {
        HStack(spacing: 0) {
            Sidebar(app: app)

            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.contentBackground)
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch app.selected {
        case .diskMap:
            // 읽기 전용이라 스캔 모델이 없다. 자기 상태를 직접 들고 있는다.
            DiskMapView()

        case .smartScan:
            // 첫 화면. 전체를 훑고 기능별로 얼마가 나왔는지 카드로 보여준다.
            SmartScanView(app: app, model: app.model(for: .smartScan))

        case let feature:
            FeatureScreen(feature: feature, model: app.model(for: feature))
                // 기능을 바꾸면 뷰를 새로 만든다. 안 그러면 이전 기능의
                // 스크롤 위치와 애니메이션 상태가 그대로 따라온다.
                .id(feature)
        }
    }
}
