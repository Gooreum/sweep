import SwiftUI
import SweepKit

/// 왼쪽 220pt 기능 목록. 항목 하나가 곧 독립된 화면이다.
struct Sidebar: View {
    @Bindable var app: AppModel

    /// 볼륨 용량은 스캔과 무관하고 화면을 보는 동안 거의 변하지 않는다.
    /// 매 렌더마다 읽으면 디스크를 두드리는 값이라 한 번만 읽어 둔다.
    private let usage = VolumeUsage.current()

    @State private var hovered: Feature?

    var body: some View {
        // 배지를 한 번만 계산해 행으로 내려보낸다. 행마다 물으면 같은 항목
        // 목록을 기능 수만큼 훑는다.
        let badges = app.badges

        return VStack(alignment: .leading, spacing: 0) {
            // 항목을 손으로 나열하지 않는다. 기능이 늘면 사이드바가 따라와야 한다.
            ForEach(Feature.allCases) { row($0, badge: badges[$0]) }

            // 디스크는 스캔과 무관하게 늘 유효한 유일한 숫자다. 맨 아래 구석이
            // 아니라 항목 바로 아래에 둬서 눈이 닿는 자리에 놓는다.
            diskGauge
                .padding(.top, 24)

            Spacer(minLength: 0)
        }
        .padding(.top, 8)
        .frame(width: Theme.sidebarWidth)
        .background(Theme.surfaceSunken)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Theme.border)
                .frame(width: 1)
        }
    }

    private func row(_ feature: Feature, badge: String?) -> some View {
        // 선택 상태를 따로 들고 있지 않는다. 두 곳에 있으면 어긋난다.
        let isSelected = app.selected == feature
        let isHovered = hovered == feature

        return HStack(spacing: 0) {
            // 선택을 강조색 **면 전체**가 아니라 4pt 인디케이터로 알린다.
            // 다크에서 파란 슬래브는 화면에서 가장 밝은 덩어리가 되어
            // 정작 봐야 할 결과 목록보다 눈에 먼저 들어온다.
            RoundedRectangle(cornerRadius: 2)
                .fill(isSelected ? Theme.tintFill(feature) : .clear)
                .frame(width: 4, height: 16)
                .padding(.leading, 4)

            Image(systemName: feature.systemImageName)
                .font(.system(size: Theme.Icon.small))
                .frame(width: Theme.sidebarIconSize, height: Theme.sidebarIconSize)
                .foregroundStyle(Theme.tint(feature).opacity(isSelected ? 1 : 0.75))
                .padding(.leading, 8)

            Text(feature.displayName)
                .font(isSelected ? Theme.bodyText.weight(.medium) : Theme.bodyText)
                .foregroundStyle(Theme.textPrimary)
                .padding(.leading, 8)

            Spacer(minLength: 0)

            // 스캔 결과를 사이드바에서 바로 본다. 어디에 용량이 묶여 있는지
            // 화면을 옮기지 않고 알 수 있어야 한다.
            if let badge {
                Text(badge)
                    .font(Theme.captionMono)
                    .foregroundStyle(isSelected ? Theme.tint(feature) : Theme.textSecondary)
                    .padding(.trailing, 12)
            }
        }
        .frame(height: Theme.sidebarRowHeight)
        .background {
            RoundedRectangle(cornerRadius: Theme.rowCornerRadius)
                .fill(rowFill(isSelected: isSelected, isHovered: isHovered))
                .padding(.horizontal, Theme.sidebarRowInset)
        }
        // 글자 위가 아니라 행 어디를 눌러도 반응해야 한다
        .contentShape(Rectangle())
        .onTapGesture { app.selected = feature }
        .onHover { hovered = $0 ? feature : nil }
        .animation(Theme.transition, value: isSelected)
        .animation(Theme.transition, value: isHovered)
    }

    private func rowFill(isSelected: Bool, isHovered: Bool) -> Color {
        if isSelected { return Theme.surfaceRaised }
        return isHovered ? Theme.surfaceRaised.opacity(0.5) : .clear
    }

    /// "사용 가능 %@ / %@".
    ///
    /// 용량을 읽지 못하면 아예 그리지 않는다 — 0으로 그리면
    /// "0바이트 중 0바이트"라는 거짓말이 된다.
    @ViewBuilder
    private var diskGauge: some View {
        if let usage {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("사용 가능")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    // 남은 용량이 이 앱의 존재 이유다. 캡션이 아니라 수치로 읽힌다.
                    Text(usage.formattedAvailable)
                        .font(Theme.headlineMono)
                        .foregroundStyle(Theme.textPrimary)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.border)
                        Capsule()
                            .fill(Theme.accent)
                            .frame(width: geometry.size.width * usage.usedFraction)
                    }
                }
                .frame(height: 4)

                Text("\(usage.formattedUsed) 사용됨 · 전체 \(usage.formattedTotal)")
                    .font(Theme.captionMono)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 16)
        }
    }
}
