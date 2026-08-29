import SwiftUI
import SweepKit

/// 메뉴 막대에서 내려오는 패널. Cleaner One 퀵 윈도우와 같은 400pt 폭.
///
/// Cleaner One은 여기에 CPU·메모리·네트워크 그래프까지 담지만
/// **Sweep은 그것들을 재지 않는다.** 없는 데이터를 위한 자리를 만들면
/// 영영 빈칸이거나 거짓말이 된다 — 아는 것만 담는다.
struct MenuBarPanel: View {
    @Bindable var app: AppModel

    /// 창을 앞으로 부르는 동작. 씬 밖에서는 `openWindow`를 쓸 수 없어 주입받는다.
    let openMain: () -> Void

    /// 볼륨 용량은 스캔과 무관하고 패널이 열릴 때마다 바뀌지 않는다.
    private let usage = VolumeUsage.current()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            diskSection
            Divider()
            scanSection
            Divider()
            actions
        }
        .frame(width: Theme.panelWidth)
    }

    /// 디스크 사용량. 스캔하지 않아도 늘 보여줄 수 있는 유일한 값이다.
    ///
    /// 읽지 못하면 아예 그리지 않는다 — 사이드바 게이지와 같은 판단이다.
    @ViewBuilder
    private var diskSection: some View {
        if let usage {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("디스크").font(Theme.bodyText.weight(.medium))
                    Spacer()
                    Text("\(Int(usage.usedFraction * 100))% 사용됨")
                        .font(Theme.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.separator)
                        Capsule()
                            .fill(Theme.accent)
                            .frame(width: geometry.size.width * usage.usedFraction)
                    }
                }
                .frame(height: 8)

                Text("사용 가능: \(usage.formattedAvailable)  전체: \(usage.formattedTotal)")
                    .font(Theme.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(Theme.panelPadding)
        }
    }

    /// 마지막 스캔 결과. 요약은 모델이 계산한다 — 여기서 다시 세면 어긋난다.
    private var scanSection: some View {
        let summary = app.menuBarSummary

        return VStack(alignment: .leading, spacing: 8) {
            if let percent = summary.scanPercent {
                HStack {
                    Text("훑는 중").font(Theme.bodyText)
                    Spacer()
                    Text("\(percent)%")
                        .font(Theme.bodyText.monospacedDigit())
                        .foregroundStyle(Theme.accent)
                }
            } else if let reclaimable = summary.reclaimable {
                HStack {
                    Text("회수 가능").font(Theme.bodyText.weight(.medium))
                    Spacer()
                    Text(reclaimable)
                        .font(.system(size: 17, weight: .medium).monospacedDigit())
                        .foregroundStyle(Theme.accent)
                }

                // 발견량이 0인 기능은 애초에 빠져 있다
                ForEach(summary.breakdown) { row in
                    HStack {
                        Text(row.feature.displayName)
                            .font(Theme.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(row.formattedSize) · \(row.count)개")
                            .font(Theme.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            } else {
                // 훑지 않은 것과 훑었는데 없는 것은 다르다. 0을 지어내지 않는다.
                Text("아직 훑어보지 않았습니다")
                    .font(Theme.bodyText)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(Theme.panelPadding)
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button("검색") {
                let model = app.model(for: .smartScan)
                Task { await model.scan() }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(app.menuBarSummary.isScanning)

            Spacer()

            Button("Sweep 열기", action: openMain)
        }
        .padding(Theme.panelPadding)
    }
}
