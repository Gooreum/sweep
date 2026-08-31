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
                .foregroundStyle(Theme.accent)

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
        VStack(spacing: 24) {
            VStack(spacing: 4) {
                Text("회수 가능 \(model.formattedTotalSize)")
                    .font(Theme.displayMono)
                Text("\(model.items.count)개 항목")
                    .font(Theme.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            HStack(spacing: 16) {
                // 카드를 손으로 나열하지 않는다. 기능이 늘면 여기도 따라온다.
                ForEach(Feature.summaryCards) { card($0) }
            }

            Button("다시 검색") { Task { await model.scan() } }
                .buttonStyle(PrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func card(_ feature: Feature) -> some View {
        // 카테고리를 손으로 거르지 않는다 — 스캐너가 바뀌면 조용히 어긋난다
        let matched = feature.items(from: model.items)
        let isEmpty = matched.isEmpty

        return Button {
            app.selected = feature
        } label: {
            VStack(spacing: 10) {
                Image(systemName: feature.systemImageName)
                    .font(.system(size: Theme.Icon.medium))
                    .foregroundStyle(isEmpty ? Color.secondary : Theme.accent)

                Text(feature.displayName)
                    .font(Theme.bodyText)
                    .foregroundStyle(.primary)

                Text(matched.formattedTotalSize)
                    .font(Theme.headlineMono)
                    .foregroundStyle(isEmpty ? Color.secondary : Theme.accent)

                Text("\(matched.count)개")
                    .font(Theme.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .frame(width: 160, height: 150)
            .background(Theme.surfaceRaised.opacity(isEmpty ? 0.5 : 1),
                        in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        }
        .buttonStyle(.plain)
        // 찾은 것이 없는 카드를 누르면 빈 결과 화면으로 떨어진다
        .disabled(isEmpty)
    }
}
