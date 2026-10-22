import SwiftUI
import SweepKit

/// 기능 목록과 디스크 정보를 같은 불투명 패널에 두어 창의 탐색 영역을 구분한다.
struct Sidebar: View {
    @Bindable var app: AppModel

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

            permissionsEntry
        }
        .frame(width: R95.sidebarWidth)
        .frame(maxHeight: .infinity)
        .background(R95.gray)
        .overlay(alignment: .trailing) {
            Retro95SidebarEdge()
        }
    }

    private var permissionsEntry: some View {
        let hasOff = Feature.allCases.contains { !app.permissionNeeds(for: $0).isEmpty }

        return VStack(alignment: .leading, spacing: 8) {
            Retro95Separator()
            HStack(spacing: 8) {
                PixelIcon(art: hasOff ? .warning : .check, size: 16)
                    .accessibilityHidden(true)
                Text(hasOff ? "꺼진 권한이 있어요" : "필요한 권한이 켜져 있어요")
                    .font(R95.ui(11))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(hasOff ? Theme.cautionText : Theme.textSecondary)
            SettingsLink {
                Text("권한 모두 보기")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(Retro95ButtonStyle())
            .accessibilityLabel(Text("권한 모두 보기"))
        }
        .padding(8)
    }

    private func row(_ feature: Feature, badge: String?) -> some View {
        // 선택 상태를 따로 들고 있지 않는다. 두 곳에 있으면 어긋난다.
        let isSelected = app.selected == feature
        let status = app.status(of: feature)

        return HStack(spacing: 4) {
            PixelIcon(art: feature.pixelArt, size: 24)
            Text(feature.displayName)
                .font(R95.ui(13))
                .lineLimit(1)
                // 이름이 숫자보다 먼저 자리를 얻되, 모자라면 이름이 조금 줄어든다.
                // 숫자가 "26.88…"로 잘리면 용량을 알 수 없다.
                .minimumScaleFactor(0.85)
                .layoutPriority(1)
            Spacer(minLength: 0)

            HStack(spacing: 4) {
                if feature != .cpu {
                    Group {
                        switch status {
                        case .idle: EmptyView()
                        case .loading: Retro95Hourglass(size: 16)
                        case .done: PixelIcon(art: .check, size: 16)
                        }
                    }
                    // 픽셀의 검은 테두리도 선택 배경에서 보이게 한다.
                    .background(R95.gray)
                    .accessibilityHidden(true)
                }
                if let badge {
                    Text(badge).font(R95.mono(11)).lineLimit(1).fixedSize(horizontal: true, vertical: false)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .foregroundStyle(isSelected ? R95.white : R95.black)
        .padding(.horizontal, 4)
        .frame(height: R95.sidebarRowHeight)
        .background(isSelected ? R95.navy : R95.gray)
        // 글자 위가 아니라 행 어디를 눌러도 반응해야 한다.
        .contentShape(Rectangle())
        .onTapGesture { app.selected = feature }
        .accessibilityElement(children: .combine)
        .accessibilityValue(accessibilityStatus(for: feature))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .padding(.horizontal, 4)
    }

    private func accessibilityStatus(for feature: Feature) -> String {
        let status = app.status(of: feature)
        if feature == .diskMap {
            switch status {
            case .idle: return ""
            case .loading: return String(localized: "공간 보기 읽는 중")
            case .done: return String(localized: "공간 보기 완료")
            }
        }
        guard feature != .cpu else { return "" }
        switch status {
        case .idle: return ""
        case .loading: return String(localized: "\(feature.displayName) 찾는 중")
        case .done: return String(localized: "\(feature.displayName) 찾기 완료")
        }
    }

    /// 용량을 읽지 못하면 아예 그리지 않는다 — 0으로 그리면
    /// "0바이트 중 0바이트"라는 거짓말이 된다.
    @ViewBuilder
    private var diskGauge: some View {
        // 디스크 용량은 `AppModel`이 들고 있다가 정리·되돌리기 직후 다시 읽는다.
        // 여기서 볼륨을 조회하지 않는다 — body는 스캔 진행률마다 다시 돈다.
        if let usage = app.volumeUsage {
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
                Text("사용 \(usage.formattedUsed), 전체 \(usage.formattedTotal)")
                    .font(R95.mono(10))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(R95.black)
            .padding(.horizontal, 8)
        }
    }
}
