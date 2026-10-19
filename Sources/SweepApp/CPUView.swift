import SwiftUI
import AppKit
import SweepKit

/// CPU를 끝내는 일은 활성 상태 보기에 맡기고, 이 화면에서는 비중과 실행 경로를 보여준다.
struct CPUView: View {
    // 탭을 오갈 때 측정을 다시 준비하지 않도록 ContentView의 모델을 그대로 쓴다.
    @Bindable var model: CPUModel

    private enum Columns {
        static let percent: CGFloat = 60
        static let pid: CGFloat = 60
        static let actions: CGFloat = 96
        static let headers: [Retro95TableHeader.Column] = [
            .init(title: String(localized: "점유율 ▼"), width: percent),
            .init(title: String(localized: "프로세스 / 실행 경로")),
            .init(title: String(localized: "PID"), width: pid),
            .init(title: String(localized: "위치 / 복사"), width: actions)
        ]
    }

    var body: some View {
        VStack(spacing: 12) {
            header
            HStack(alignment: .top, spacing: 10) {
                chart.frame(width: 272)
                processTable
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(10)
        .background(R95.gray)
        // 탭을 떠나면 측정 작업도 취소되어 보이지 않는 화면이 CPU를 쓰지 않는다.
        .task { await model.run() }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("코어 \(model.cores)개 전체 = 100% · 내 계정으로 실행된 프로세스만 보입니다.")
                    .font(R95.ui(12, bold: true))
                    .foregroundStyle(R95.black)
                Text("활성 상태 보기는 코어 하나를 100%로 세므로 같은 프로세스도 숫자가 다릅니다.")
                    .font(R95.ui(11))
                    .foregroundStyle(R95.deep)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("활성 상태 보기 열기") { openActivityMonitor() }
                .buttonStyle(Retro95ButtonStyle())
                .fixedSize()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
    }

    private var shares: [CPUShare] { CPUShare.slices(from: model.usage) }
    private var used: Double { model.usage.reduce(0) { $0 + $1.percent } }
    private var idle: Double { shares.first(where: { $0.kind == .idle })?.percent ?? 0 }

    private var chart: some View {
        VStack(spacing: 10) {
            Retro95GroupBox(title: String(localized: "CPU 전체 부하")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 18) {
                        PixelIcon(art: .computer, size: 32)
                        VStack(alignment: .leading, spacing: 0) {
                            // 준비 중에는 0%를 꾸며내지 않는다.
                            Text(model.isWarmingUp ? "—" : String(format: "%.0f%%", used))
                                .font(R95.mono(30))
                                .foregroundStyle(R95.navy)
                            Text("사용 중").font(R95.ui(13, bold: true))
                        }
                    }
                    Retro95ProgressBar(fraction: model.isWarmingUp ? nil : used / 100)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("코어 \(model.cores)개 전체 = 100%")
                            .font(R95.ui(12, bold: true))
                        if !model.isWarmingUp {
                            Text("유휴 \(String(format: "%.1f%%", idle))")
                                .font(R95.ui(11))
                                .foregroundStyle(R95.deep)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                }
            }
            Retro95GroupBox(title: String(localized: "상위 프로세스 점유율")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("전체 CPU 기준 · 각 막대 100%")
                        .font(R95.ui(11))
                        .foregroundStyle(R95.deep)
                    if !model.isWarmingUp {
                        // 창이 낮으면 넘친 만큼 화면 전체가 밀려 제목·상태 막대가 창 밖으로 나갔다.
                        // 이 목록만 스크롤시켜 높이를 창 안에 가둔다.
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(shares) { share in
                                    shareRow(share)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .foregroundStyle(R95.black)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func shareRow(_ share: CPUShare) -> some View {
        VStack(spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(shareName(share)).font(R95.ui(12, bold: true))
                    .lineLimit(1).truncationMode(.middle)
                if case .process(let pid) = share.kind {
                    Text(verbatim: "pid \(pid)")
                        .font(R95.mono(9)).foregroundStyle(R95.deep)
                }
                Spacer(minLength: 0)
                Text(share.formattedPercent).font(R95.mono(12)).foregroundStyle(R95.navy)
            }
            // 유휴는 쓰이지 않은 몫이라 회색으로 물러나게 한다.
            Retro95ProgressBar(fraction: share.percent / 100, height: 14,
                               fill: share.kind == .idle ? R95.shadow : R95.navy)
        }
    }

    private func shareName(_ share: CPUShare) -> String {
        switch share.kind {
        case .process: share.name
        case .other: String(localized: "기타")
        case .idle: String(localized: "유휴")
        }
    }

    private var processTable: some View {
        Retro95GroupBox(title: String(localized: "프로세스 · 점유율순")) {
            VStack(spacing: 0) {
                Retro95TableHeader(columns: Columns.headers)
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(R95.white)
            .retroSunken()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var content: some View {
        if model.isWarmingUp {
            placeholder(String(localized: "측정 중…"),
                        detail: String(localized: "두 번 재야 사용률이 나옵니다."))
        } else if model.usage.isEmpty {
            placeholder(String(localized: "지금 CPU를 쓰는 프로세스가 없습니다."),
                        detail: String(localized: "직전 구간 동안 아무것도 계산하지 않았습니다."))
        } else {
            // 주기적 갱신이 NSTableView 대리자로 재진입하지 않도록 List 대신 스크롤 뷰를 쓴다.
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(model.usage) { usage in
                        row(usage)
                        if usage.id != model.usage.last?.id {
                            Rectangle().fill(R95.light).frame(height: 1)
                        }
                    }
                }
            }
            .scrollIndicators(.visible)
        }
    }

    private func row(_ usage: ProcessUsage) -> some View {
        HStack(spacing: 0) {
            Text(usage.formattedPercent)
                .font(R95.mono(12)).foregroundStyle(R95.navy)
                .padding(.horizontal, 6)
                .frame(width: Columns.percent, alignment: .trailing)
            VStack(alignment: .leading, spacing: 2) {
                Text(usage.name).font(R95.ui(12, bold: true))
                    .foregroundStyle(R95.black)
                    .lineLimit(1).truncationMode(.middle)
                if let path = usage.displayPath {
                    Text(path).font(R95.ui(10)).foregroundStyle(R95.deep)
                        .lineLimit(1).truncationMode(.middle)
                }
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            // 열 머리가 이미 PID라 "pid " 접두어를 빼야 좁은 칸에서 줄이 꺾이지 않는다.
            Text(verbatim: "\(usage.pid)").font(R95.mono(10)).foregroundStyle(R95.deep)
                .padding(.horizontal, 6)
                .frame(width: Columns.pid, alignment: .trailing)
            HStack(spacing: 4) {
                if let path = usage.executablePath {
                    let url = URL(filePath: path)
                    iconButton(.folder, String(localized: "Finder에서 보기")) { ItemActions.reveal(url) }
                    iconButton(.documents, String(localized: "경로 복사")) { ItemActions.copyPath(url) }
                }
            }
            .frame(width: Columns.actions)
        }
        .frame(minHeight: R95.tableRowHeight)
    }

    /// 활성 상태 보기를 연다. **샌드박스에서도 된다** — 실측으로 확인했다.
    /// 남의 프로세스를 다루는 것 중 이 앱이 할 수 있는 유일한 일이다.
    private func openActivityMonitor() {
        NSWorkspace.shared.open(
            URL(filePath: "/System/Applications/Utilities/Activity Monitor.app"))
    }

    private func iconButton(_ art: PixelArt, _ hint: String,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            PixelIcon(art: art, size: 16)
        }
        .buttonStyle(Retro95ButtonStyle())
        .frame(width: DiskMapColumns.iconButton)
        .help(hint)
        .accessibilityLabel(hint)
    }

    private func placeholder(_ title: String, detail: String) -> some View {
        VStack(spacing: 8) {
            PixelIcon(art: .computer, size: 32)
            Text(title).font(R95.ui(13, bold: true)).foregroundStyle(R95.black)
            Text(detail).font(R95.ui(12)).foregroundStyle(R95.deep)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
