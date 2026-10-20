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

    /// 휴지통을 열지 못했다(샌드박스). 대신 할 일을 말한다.
    @State private var trashOpenFailed = false

    var body: some View {
        // 요약을 한 번만 만들어 내려보낸다. 섹션마다 부르면 그때마다
        // 전체 항목을 기능 수만큼 필터링한다.
        let summary = app.menuBarSummary

        return VStack(alignment: .leading, spacing: 0) {
            diskSection
            Retro95Separator()
            scanSection(summary)
            Retro95Separator()
            actions(isScanning: summary.isScanning)
        }
        .frame(width: Theme.panelWidth)
        // 패널은 열 때마다 지금 디스크 용량을 보여준다. 마지막 정리 뒤 시간이 지났을 수 있다.
        .onAppear { app.refreshVolumeUsage() }
        .alert("휴지통을 열지 못했어요", isPresented: $trashOpenFailed) {
            Button("확인") {}
        } message: {
            Text("화면 아래 휴지통을 직접 열어 주세요. 비우면 되돌릴 수 없으니 안에 있는 파일을 먼저 확인해 주세요.")
        }
        .foregroundStyle(R95.black)
        .background(R95.gray)
        .retroRaised()
    }

    /// 디스크 사용량. 스캔하지 않아도 늘 보여줄 수 있는 유일한 값이다.
    ///
    /// 읽지 못하면 아예 그리지 않는다 — 사이드바 게이지와 같은 판단이다.
    @ViewBuilder
    private var diskSection: some View {
        // 디스크 용량은 `AppModel`이 들고 있다가 정리·되돌리기 직후 다시 읽는다.
        // 여기서 볼륨을 조회하지 않는다 — body는 스캔 진행률마다 다시 돈다.
        if let usage = app.volumeUsage {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("디스크").font(Theme.bodyText.weight(.medium))
                    Spacer()
                    Text("\(Int(usage.usedFraction * 100))% 사용됨")
                        .font(Theme.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Retro95ProgressBar(fraction: usage.usedFraction)

                Text("남은 공간은 \(usage.formattedAvailable)이에요. 전체는 \(usage.formattedTotal)이에요.")
                    .font(Theme.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(Theme.panelPadding)
        }
    }

    /// 마지막 스캔 결과. 요약은 모델이 계산한다 — 여기서 다시 세면 어긋난다.
    private func scanSection(_ summary: MenuBarSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let percent = summary.scanPercent {
                HStack {
                    Text("검색 중").font(Theme.bodyText)
                    Spacer()
                    Text("\(percent)%")
                        .font(Theme.bodyText.monospacedDigit())
                        .foregroundStyle(Theme.accentText)
                }
                Retro95ProgressBar(fraction: Double(percent) / 100)
            } else if let reclaimable = summary.reclaimable {
                HStack {
                    Text("정리 후보").font(Theme.bodyText.weight(.medium))
                    Spacer()
                    Text(reclaimable)
                        .font(Theme.headlineMono)
                        .foregroundStyle(Theme.accentText)
                }

                // 발견량이 0인 기능은 애초에 빠져 있다
                ForEach(summary.breakdown) { row in
                    HStack {
                        Text(row.feature.displayName)
                            .font(Theme.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(row.count)개, \(row.formattedSize)")
                            .font(Theme.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            } else {
                // 훑지 않은 것과 훑었는데 없는 것은 다르다. 0을 지어내지 않는다.
                Text("검색을 눌러 정리할 파일을 찾아보세요")
                    .font(Theme.bodyText)
                    .foregroundStyle(.secondary)
            }

            // 지금까지 비운 양. 기록이 없으면 줄이 없다.
            if let line = app.cleanupSummary.statusLine() {
                Text(line)
                    .font(Theme.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            // 옮긴 양은 휴지통을 비워야 공간이 된다. 앱은 비웠는지 알 수 없어 기록이 있으면 늘 둔다.
            if let hint = app.cleanupSummary.trashHint {
                HStack(spacing: 6) {
                    Text(hint)
                        .font(Theme.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Button("휴지통 열기") { trashOpenFailed = !ItemActions.openTrash() }
                        .buttonStyle(.link)
                        .font(Theme.caption)
                }
            }
        }
        .padding(Theme.panelPadding)
    }

    private func actions(isScanning: Bool) -> some View {
        HStack(spacing: 10) {
            Button("검색") {
                let model = app.model(for: .smartScan)
                Task { await model.scan() }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isScanning)

            Spacer()

            Button("Sweep 열기", action: openMain)
                .buttonStyle(SecondaryButtonStyle())
        }
        .padding(Theme.panelPadding)
    }
}
