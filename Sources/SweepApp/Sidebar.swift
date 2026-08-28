import SwiftUI
import SweepKit

/// 왼쪽 220pt 기능 목록. 항목 하나가 곧 독립된 화면이다.
struct Sidebar: View {
    @Bindable var app: AppModel

    /// 볼륨 용량은 스캔과 무관하고 화면을 보는 동안 거의 변하지 않는다.
    /// 매 렌더마다 읽으면 디스크를 두드리는 값이라 한 번만 읽어 둔다.
    private let usage = VolumeUsage.current()

    var body: some View {
        VStack(spacing: 0) {
            // 항목을 손으로 나열하지 않는다. 기능이 늘면 사이드바가 따라와야 한다.
            ForEach(Feature.allCases) { row($0) }

            Spacer(minLength: 0)
            diskGauge
        }
        .padding(.top, 8)
        .frame(width: Theme.sidebarWidth)
        .background(Theme.sidebarBackground)
        // nib의 {{219, 0}, {1, 680}} — 사이드바 오른쪽 끝에 붙은 1pt 선
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Theme.separator)
                .frame(width: 1)
        }
    }

    private func row(_ feature: Feature) -> some View {
        // 선택 상태를 따로 들고 있지 않는다. 두 곳에 있으면 어긋난다.
        let isSelected = app.selected == feature

        return HStack(spacing: 0) {
            Image(systemName: feature.systemImageName)
                .font(.system(size: 15))
                .frame(width: Theme.sidebarIconSize, height: Theme.sidebarIconSize)
                .padding(.leading, Theme.sidebarIconLeading)

            Text(feature.displayName)
                .font(Theme.bodyText)
                .padding(.leading, 10)

            Spacer(minLength: 0)
        }
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .frame(height: Theme.sidebarRowHeight)
        .background {
            RoundedRectangle(cornerRadius: Theme.rowCornerRadius)
                .fill(isSelected ? Theme.accent : .clear)
                .padding(.horizontal, Theme.sidebarRowInset)
        }
        // 글자 위가 아니라 행 어디를 눌러도 반응해야 한다
        .contentShape(Rectangle())
        .onTapGesture { app.selected = feature }
    }

    /// "사용 가능: %@  전체: %@".
    ///
    /// 용량을 읽지 못하면 아예 그리지 않는다 — 0으로 그리면
    /// "0바이트 중 0바이트"라는 거짓말이 된다.
    @ViewBuilder
    private var diskGauge: some View {
        if let usage {
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.separator)
                        Capsule()
                            .fill(Theme.accent)
                            .frame(width: geometry.size.width * usage.usedFraction)
                    }
                }
                .frame(height: 6)

                Text("사용 가능: \(usage.formattedAvailable)  전체: \(usage.formattedTotal)")
                    .font(Theme.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
}
