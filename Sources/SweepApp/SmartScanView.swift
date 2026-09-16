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

    /// 샌드박스에서는 폴더를 **여러 번** 허락할 수 있다. 생성 때 한 번만 읽으면
    /// 두 번째 허락이 목록에 반영되지 않는다 — 예전에는 허락이 한 번뿐이라
    /// `let`으로 두고 부모가 다시 그리는 것에 기댔다.
    ///
    /// 그렇다고 `body`에서 매번 부르면 스캔 진행률이 바뀔 때마다 루트를 다시 계산한다.
    /// 허락한 폴더 수가 바뀔 때만 다시 읽는다.
    @State private var scopes = CleanupScope.all

    /// 틀린 폴더를 골랐을 때 알려줄 말. nil이면 닫혀 있다.
    @State private var grantFailure: String?

    /// 보는 곳마다 지금 읽을 수 있는지. 줄마다 디스크를 두드리지 않도록 한 번에 만든다.
    ///
    /// 권한은 실행 중에 막히거나 풀린다 — TCC 프롬프트를 거부하거나, 시스템 설정에서
    /// 켜고 돌아오거나. 화면이 그것을 반영하지 못하면 사용자는 "정리할 항목 없음"만 본다.
    @State private var readability: [String: FolderReadability] = [:]

    var body: some View {
        Group {
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
        // 폴더를 새로 허락하면 "보는 곳" 목록이 늘고, 읽기 상태도 달라진다.
        .onChange(of: app.grantedFolderCount) { refreshReadability() }
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
                    Text(scanned
                         ? "\(summary.breakdown.reduce(0) { $0 + $1.count })개 항목"
                         : "전체 \(usage.formattedTotal) 중")
                        .font(Theme.captionMono)
                        .foregroundStyle(Theme.textSecondary)
                }

                if scanned {
                    // 스캔 후에는 **회수 가능한 몫의 구성**을 막대로 그린다.
                    // 도넛은 조각이 셋이고 비율이 1:1:0.01일 때 가장 작은 것이
                    // 실처럼 사라져 색만 있고 읽히지 않았다.
                    ReclaimBar(rows: breakdown)
                    ReclaimLegend(rows: breakdown)
                } else {
                    // 스캔 전에는 조각이 둘(사용/사용가능)뿐이라 링이 제 몫을 한다.
                    DiskDonut(slices: diskSlices(usage),
                              centerValue: "\(Int(usage.usedFraction * 100))%",
                              centerCaption: "사용됨")
                }
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
                let blocked = readability[scope.id] == .denied

                HStack(spacing: 12) {
                    Image(systemName: blocked ? "exclamationmark.triangle.fill" : "folder")
                        .font(.system(size: Theme.Icon.small))
                        .foregroundStyle(blocked ? SafetyLevel.caution.tint : Theme.textSecondary)
                        .frame(width: Theme.Icon.medium)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(scope.label)
                            .font(Theme.bodyMono)
                            .foregroundStyle(Theme.textPrimary)
                        // 막혔으면 무엇을 찾는 곳인지보다 왜 비어 있는지가 먼저다.
                        if blocked {
                            Text("권한이 막혀 읽을 수 없습니다")
                                .font(Theme.caption)
                                .foregroundStyle(SafetyLevel.caution.tint)
                        } else if !scope.detail.isEmpty {
                            Text(scope.detail)
                                .font(Theme.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    Spacer(minLength: 12)

                    if blocked {
                        Button("열기…") { unblock(scope) }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                if index < scopes.count - 1 {
                    Divider().overlay(Theme.border).padding(.leading, 52)
                }
            }

            folderAccessRows
            blockedFooter
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .task { refreshReadability() }
        .alert("다른 폴더를 골랐습니다",
               isPresented: Binding(get: { grantFailure != nil },
                                    set: { if !$0 { grantFailure = nil } })) {
            Button("확인") { grantFailure = nil }
        } message: {
            Text(grantFailure ?? "")
        }
    }

    /// 폴더를 더 열거나 거두는 줄. **샌드박스에서만 보인다.**
    ///
    /// 이 허락은 시스템 설정 어디에도 나타나지 않는다. 앱이 입구를 주지 않으면
    /// 사용자는 마음을 바꿀 방법이 없다 — 여기가 그 유일한 곳이다.
    ///
    /// 얼마나 더 찾을 수 있는지(용량)는 보여줄 수 없다. 크기를 재려면 그 폴더를
    /// 읽어야 하는데 허락 전에는 읽지 못한다. 대신 무엇이 있는지를 말한다.
    @ViewBuilder
    private var folderAccessRows: some View {
        if Sandbox.isActive {
            Divider().overlay(Theme.border)

            ForEach(FolderAccess.grantables) { grantable in
                let granted = app.isGranted(grantable)

                HStack(spacing: 12) {
                    Image(systemName: granted ? "folder.fill" : "plus.circle")
                        .font(.system(size: Theme.Icon.small))
                        .foregroundStyle(granted ? Theme.accentText : Theme.textSecondary)
                        .frame(width: Theme.Icon.medium)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(grantable.label)
                            .font(Theme.bodyMono)
                            .foregroundStyle(Theme.textPrimary)
                        Text(grantable.purpose)
                            .font(Theme.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer(minLength: 12)

                    if granted {
                        Button("해제") { app.revokeFolderAccess(grantable) }
                    } else {
                        Button("열기…") { grant(grantable) }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
    }

    private func grant(_ grantable: FolderAccess.Grantable) {
        guard let picked = FolderPicker.ask(for: grantable) else { return }
        do {
            try app.grantFolderAccess(picked, as: grantable)
            refreshReadability()
        } catch {
            grantFailure = error.message
        }
    }

    /// 막힌 폴더가 하나라도 있으면 보인다.
    ///
    /// 열기 대화상자로 고르면 대개 풀리지만, TCC가 이미 거부를 기록했다면
    /// 시스템 설정에서 되돌리는 것이 확실한 길이다. 둘 다 준다.
    @ViewBuilder
    private var blockedFooter: some View {
        if readability.values.contains(.denied) {
            Divider().overlay(Theme.border)

            HStack(spacing: 12) {
                Text("권한이 막힌 폴더가 있어요")
                    .font(Theme.caption)
                    .foregroundStyle(SafetyLevel.caution.tint)
                Spacer(minLength: 12)
                Button("시스템 설정 열기") { PrivacySettings.openFilesAndFolders() }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    /// 막힌 폴더를 열기 대화상자로 직접 고르게 한다.
    ///
    /// TCC 거부는 "앱이 알아서 여는 것"을 막는 것이라, 사용자가 명시적으로 고른
    /// 폴더는 보안 범위 접근이 따로 부여된다. 그것으로도 안 풀리면 시스템 설정이 남는다.
    private func unblock(_ scope: CleanupScope) {
        let grantable = FolderAccess.Grantable(folder: scope.url,
                                               label: scope.label,
                                               purpose: scope.detail.isEmpty
                                                   ? "정리 대상" : scope.detail)
        guard let picked = FolderPicker.ask(for: grantable) else { return }
        do {
            try app.grantFolderAccess(picked, as: grantable)
        } catch let failure as FolderAccess.Failure {
            grantFailure = failure.message
        } catch {
            grantFailure = error.localizedDescription
        }
        // 허락에 실패해도 다시 읽어 본다 — 사용자가 그 사이 설정에서 풀었을 수 있다.
        refreshReadability()
    }

    /// 보는 곳의 읽기 상태를 다시 계산한다. 권한은 실행 중에 바뀐다.
    private func refreshReadability() {
        scopes = CleanupScope.all
        readability = CleanupScope.readabilityMap(of: scopes)
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
                                .fill(Theme.tintFill(row.feature))
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
