import SwiftUI
import SweepKit

/// 첫 화면. 한 번에 전체를 훑고 기능별로 얼마가 나왔는지 보여준다.
///
/// 사이드바를 하나씩 눌러 보지 않아도 어디에 용량이 묶여 있는지 알 수 있어야 한다.
struct SmartScanView: View {
    @Bindable var app: AppModel
    @Bindable var model: ScanModel

    /// 볼륨 용량은 스캔과 무관하고 화면을 보는 동안 거의 변하지 않는다.
    /// body 안에서 부르면 스캔 진행률이 바뀔 때마다 볼륨을 다시 조회한다 —
    /// `Sidebar`·`MenuBarPanel`이 이미 저장 프로퍼티로 쓰고 있다.
    private let usage = VolumeUsage.current()

    /// 허용 루트는 실행 중에 바뀌지 않는다. 매 렌더마다 다시 만들 이유가 없다.
    private let scopes = CleanupScope.all

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

    /// 스캔 전 화면. **빈 판을 두지 않는다.**
    ///
    /// 열자마자 보여줄 게 있어야 한다 — 디스크 현황은 스캔 없이 즉시 알 수 있고,
    /// "무엇을 건드리는지"는 파일을 지우는 앱에서 첫 화면에 있을 값이다.
    private var welcome: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 요약을 한 번만 만들어 넘긴다. 화면 안에서 두 번 부르면
                // 그때마다 전체 항목을 기능 수만큼 필터링한다.
                diskCard(model.summary)
                scopeCard

                Button("전체 검색") { Task { await model.scan() } }
                    .buttonStyle(PrimaryButtonStyle())
            }
            .frame(maxWidth: 640, alignment: .leading)
            .padding(32)
            .frame(maxWidth: .infinity)
        }
    }

    /// 히어로 도넛.
    ///
    /// 스캔 결과가 있으면 **회수 가능한 6.78GB의 구성**을 그린다.
    /// 디스크 전체(494GB)를 그리면 기능 조각이 1.4%짜리 실이 되어
    /// 색이 있으나 마나다. 전체 용량은 큰 숫자와 사이드바 게이지가 이미 말한다.
    @ViewBuilder
    private func diskCard(_ summary: MenuBarSummary) -> some View {
        if let usage {
            let breakdown = summary.breakdown
            let scanned = !breakdown.isEmpty

            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(scanned ? model.formattedTotalSize : usage.formattedAvailable)
                        .font(Theme.displayMono)
                        .foregroundStyle(Theme.textPrimary)
                    Text(scanned ? "회수 가능" : "사용 가능")
                        .font(Theme.bodyText)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    if scanned {
                        Text("전체 \(usage.formattedTotal) 중")
                            .font(Theme.captionMono)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                DiskDonut(slices: scanned ? reclaimSlices(breakdown) : diskSlices(usage),
                          centerValue: scanned
                              ? "\(breakdown.count)종"
                              : "\(Int(usage.usedFraction * 100))%",
                          centerCaption: scanned ? "정리 대상" : "사용됨")
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        }
    }

    /// 스캔 전 — 디스크 전체. 회색 두 개로 끝나지 않게 사용됨에 톤을 준다.
    private func diskSlices(_ usage: VolumeUsage) -> [DiskDonut.Slice] {
        [.init(id: "used", label: "사용됨", bytes: usage.used, color: Theme.usedSlice),
         .init(id: "free", label: "사용 가능", bytes: usage.available, color: Theme.freeSlice)]
    }

    /// 스캔 후 — 회수 가능한 몫의 구성. 링 전체가 기능 색으로 찬다.
    private func reclaimSlices(_ breakdown: [MenuBarSummary.Row]) -> [DiskDonut.Slice] {
        breakdown.map { row in
            .init(id: row.feature.rawValue, label: row.feature.displayName,
                  bytes: row.bytes, color: Theme.tint(row.feature))
        }
    }

    /// Sweep이 들여다보는 곳. 목록은 안전 게이트의 허용 루트에서 유도된다.
    private var scopeCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Sweep이 보는 곳")
                    .font(Theme.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("이 밖은 건드리지 않습니다")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider().overlay(Theme.border)

            ForEach(Array(scopes.enumerated()), id: \.element.id) { index, scope in
                HStack(spacing: 12) {
                    Image(systemName: "folder")
                        .font(.system(size: Theme.Icon.small))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: Theme.Icon.medium)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(scope.label)
                            .font(Theme.bodyMono)
                            .foregroundStyle(Theme.textPrimary)
                        if !scope.detail.isEmpty {
                            Text(scope.detail)
                                .font(Theme.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                if index < scopes.count - 1 {
                    Divider().overlay(Theme.border).padding(.leading, 52)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
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
        let summary = model.summary
        let largest = summary.breakdown.first?.bytes ?? 0

        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 도넛을 여기서도 보여준다. 스캔 후에 사라지면 히어로 요소가
                // 정작 데이터가 생긴 순간에 없어진다 — 지금은 조각이 기능 색으로 갈린다.
                diskCard(summary)

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
            .frame(maxWidth: 640, alignment: .leading)
            .padding(32)
            .frame(maxWidth: .infinity)
        }
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
                    .foregroundStyle(Theme.tint(row.feature))
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
                                .fill(Theme.tint(row.feature))
                                .frame(width: max(geometry.size.width * ratio(row, largest), 2))
                        }
                    }
                    .frame(height: 4)
                }

                Text(row.formattedSize)
                    .font(isTop ? Theme.headlineMono : Theme.bodyMono)
                    .foregroundStyle(isTop ? Theme.tint(row.feature) : Theme.textPrimary)
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
