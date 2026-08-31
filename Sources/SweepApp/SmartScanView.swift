import SwiftUI
import SweepKit

/// 첫 화면. 한 번에 전체를 훑고 기능별로 얼마가 나왔는지 보여준다.
///
/// 사이드바를 하나씩 눌러 보지 않아도 어디에 용량이 묶여 있는지 알 수 있어야 한다.
struct SmartScanView: View {
    @Bindable var app: AppModel
    @Bindable var model: ScanModel

    var body: some View {
        switch model.phase {
        case .idle:
            welcome
        case let .scanning(percent, remaining):
            scanning(percent: percent, remaining: remaining)
        case let .removing(done, total):
            RingGauge(percent: total > 0 ? done * 100 / total : 0, caption: "정리하는 중")
        case .results, .cleaned:
            summary
        }
    }

    private var welcome: some View {
        VStack(spacing: 16) {
            Image(systemName: Feature.smartScan.systemImageName)
                .font(.system(size: Theme.Icon.large))
                .foregroundStyle(Theme.accentText)

            Text(Feature.smartScan.displayName)
                .font(Theme.title)

            Text(Feature.smartScan.summary)
                .font(Theme.bodyText)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            Button("검색") { Task { await model.scan() } }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func scanning(percent: Int, remaining: Int?) -> some View {
        VStack(spacing: 16) {
            // 첫 화면이라 기능 화면(180)보다 크게 잡는다
            RingGauge(percent: percent, caption: "훑는 중", diameter: 220)

            if let remaining {
                Text("약 \(ProgressDisplay.readable(seconds: remaining)) 남음")
                    .font(Theme.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var summary: some View {
        // 받은 모델에서 뽑는다. app을 거치면 하니스에서 다른 모델을 보게 된다.
        let summary = model.summary
        let largest = summary.breakdown.first?.bytes ?? 0

        return VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text("회수 가능")
                    .font(Theme.bodyText)
                    .foregroundStyle(Theme.textSecondary)
                Text(model.formattedTotalSize)
                    .font(Theme.displayMono)
                    .foregroundStyle(Theme.textPrimary)
                Text("\(model.items.count)개 항목")
                    .font(Theme.captionMono)
                    .foregroundStyle(Theme.textSecondary)
            }

            // 같은 크기 카드 3장을 한 줄에 놓으면 5.6GB와 104MB가 같은 무게로
            // 읽힌다. 크기순 목록 + 비율 막대로 어디에 묶여 있는지를 먼저 보인다.
            VStack(spacing: 0) {
                ForEach(Array(summary.breakdown.enumerated()), id: \.element.id) { index, row in
                    breakdownRow(row, largest: largest, isTop: index == 0)
                    if index < summary.breakdown.count - 1 {
                        Divider().overlay(Theme.border)
                    }
                }
            }
            .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.cardRadius))

            Button("다시 검색") { Task { await model.scan() } }
                .buttonStyle(SecondaryButtonStyle())
        }
        .frame(maxWidth: 520, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 기능 한 줄. 1위만 강조색 숫자를 받는다 — 나머지까지 강조하면 위계가 없다.
    private func breakdownRow(_ row: MenuBarSummary.Row,
                              largest: Int64, isTop: Bool) -> some View {
        Button {
            app.selected = row.feature
        } label: {
            HStack(spacing: 12) {
                Image(systemName: row.feature.systemImageName)
                    .font(.system(size: Theme.Icon.small))
                    .foregroundStyle(isTop ? Theme.accentText : Theme.textSecondary)
                    .frame(width: Theme.Icon.medium)

                VStack(alignment: .leading, spacing: 4) {
                    Text(row.feature.displayName)
                        .font(isTop ? Theme.bodyText.weight(.medium) : Theme.bodyText)
                        .foregroundStyle(Theme.textPrimary)

                    // 비율 막대. 숫자만으로는 53배 차이가 눈에 안 들어온다.
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.border)
                            Capsule()
                                .fill(isTop ? Theme.accent : Theme.textTertiary)
                                .frame(width: max(geometry.size.width * ratio(row, largest), 2))
                        }
                    }
                    .frame(height: 4)
                }

                Text(row.formattedSize)
                    .font(isTop ? Theme.headlineMono : Theme.bodyMono)
                    .foregroundStyle(isTop ? Theme.accentText : Theme.textPrimary)
                    .frame(width: 88, alignment: .trailing)

                Text("\(row.count)개")
                    .font(Theme.captionMono)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 44, alignment: .trailing)

                Image(systemName: "chevron.right")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// 0으로 나누지 않는다. 1위가 0이면 아무것도 못 찾은 것이라 막대도 없다.
    private func ratio(_ row: MenuBarSummary.Row, _ largest: Int64) -> Double {
        largest > 0 ? Double(row.bytes) / Double(largest) : 0
    }

}
