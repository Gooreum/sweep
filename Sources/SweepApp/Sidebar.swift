import SwiftUI
import SweepKit

/// 기능 목록과 디스크 정보를 같은 불투명 패널에 두어 창의 탐색 영역을 구분한다.
struct Sidebar: View {
    @Bindable var app: AppModel

    /// 볼륨 용량은 스캔과 무관하고 화면을 보는 동안 거의 변하지 않는다.
    /// 매 렌더마다 읽으면 디스크를 두드리는 값이라 한 번만 읽어 둔다.
    private let usage = VolumeUsage.current()

    var body: some View {
        // 배지를 한 번만 계산해 행으로 내려보낸다. 행마다 물으면 같은 항목
        // 목록을 기능 수만큼 훑는다.
        let badges = app.badges

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                PixelIcon(art: .computer, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sweep").font(R95.ui(18, bold: true))
                    Text("Developer Disk Cleaner").font(R95.ui(10))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .foregroundStyle(R95.black)
            .padding(8)

            Retro95Separator().padding(.horizontal, 4)

            // 항목을 손으로 나열하지 않는다. 기능이 늘면 사이드바가 따라와야 한다.
            VStack(spacing: 0) {
                ForEach(Feature.allCases) { row($0, badge: badges[$0]) }
            }
            .padding(.top, 4)

            // 디스크는 스캔과 무관하게 늘 유효한 유일한 숫자다. 맨 아래 구석이
            // 아니라 항목 바로 아래에 둬서 눈이 닿는 자리에 놓는다.
            diskGauge.padding(.top, 24)

            Spacer(minLength: 0)
        }
        .frame(width: R95.sidebarWidth)
        .frame(maxHeight: .infinity)
        .background(R95.gray)
        .overlay(alignment: .trailing) {
            Retro95SidebarEdge()
        }
    }

    private func row(_ feature: Feature, badge: String?) -> some View {
        // 선택 상태를 따로 들고 있지 않는다. 두 곳에 있으면 어긋난다.
        let isSelected = app.selected == feature

        return HStack(spacing: 8) {
            PixelIcon(art: feature.pixelArt, size: 24)
            Text(feature.displayName)
                .font(R95.ui(13))
                .lineLimit(1)
            Spacer(minLength: 0)

            // 스캔 결과를 사이드바에서 바로 본다. 어디에 용량이 묶여 있는지
            // 화면을 옮기지 않고 알 수 있어야 한다.
            if let badge {
                Text(badge).font(R95.mono(11)).lineLimit(1)
            }
        }
        .foregroundStyle(isSelected ? R95.white : R95.black)
        .padding(.horizontal, 4)
        .frame(height: R95.sidebarRowHeight)
        .background(isSelected ? R95.navy : R95.gray)
        // 글자 위가 아니라 행 어디를 눌러도 반응해야 한다.
        .contentShape(Rectangle())
        .onTapGesture { app.selected = feature }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .padding(.horizontal, 4)
    }

    /// 용량을 읽지 못하면 아예 그리지 않는다 — 0으로 그리면
    /// "0바이트 중 0바이트"라는 거짓말이 된다.
    @ViewBuilder
    private var diskGauge: some View {
        if let usage {
            VStack(alignment: .leading, spacing: 8) {
                Retro95Separator()
                HStack(spacing: 4) {
                    PixelIcon(art: .hardDrive)
                    Text("사용 가능").font(R95.ui(11))
                    Spacer(minLength: 0)
                    // 남은 용량이 이 앱의 존재 이유다. 캡션이 아니라 수치로 읽힌다.
                    Text(usage.formattedAvailable).font(R95.mono(11))
                }
                Retro95ProgressBar(fraction: usage.usedFraction)
                Text("\(usage.formattedUsed) 사용됨 · 전체 \(usage.formattedTotal)")
                    .font(R95.mono(10))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(R95.black)
            .padding(.horizontal, 8)
        }
    }
}
