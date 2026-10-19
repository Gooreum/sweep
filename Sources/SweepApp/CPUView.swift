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
            // 숫자가 왜 이렇게 나오는지를 숫자보다 먼저 말한다. 프로세스 %가 100을 넘거나
            // 합이 수백 %가 되는 것을 처음 보면 고장으로 읽힌다.
            VStack(alignment: .leading, spacing: 3) {
                Text(coreSentence)
                    .font(R95.ui(12, bold: true))
                    .foregroundStyle(R95.black)
                Text("프로세스 점유율은 활성 상태 보기와 같이 코어 하나를 100%로 셉니다. 여러 코어를 쓰면 100%를 넘고, 전부 합치면 최대 \(model.cores * 100)%입니다.")
                    .font(R95.ui(11))
                    .foregroundStyle(R95.deep)
                    .fixedSize(horizontal: false, vertical: true)
                Text("왼쪽 위 사용자·시스템·유휴는 Mac 전체를 100%로 본 값입니다.")
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

    /// "코어 8개(성능 4 + 효율 4)". 인텔 맥은 코어 종류가 하나라 총수만 말한다.
    private var coreSentence: String {
        if let performance = ProcessCPUSampler.performanceCores,
           let efficiency = ProcessCPUSampler.efficiencyCores {
            String(localized: "이 Mac의 CPU 코어는 \(model.cores)개입니다 (성능 \(performance) + 효율 \(efficiency)).")
        } else {
            String(localized: "이 Mac의 CPU 코어는 \(model.cores)개입니다.")
        }
    }

    private var chart: some View {
        VStack(spacing: 10) {
            Retro95GroupBox(title: String(localized: "CPU 부하")) {
                loadBox
            }
            Retro95GroupBox(title: String(localized: "상위 프로세스")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("막대가 꽉 차면 CPU 코어 하나를 통째로 쓰는 중입니다. 200%면 코어 두 개를 쓰는 것입니다.")
                        .font(R95.ui(11))
                        .foregroundStyle(R95.deep)
                        .fixedSize(horizontal: false, vertical: true)
                    if !model.isWarmingUp {
                        // 창이 낮으면 넘친 만큼 화면 전체가 밀려 제목·상태 막대가 창 밖으로 나갔다.
                        // 이 목록만 스크롤시켜 높이를 창 안에 가둔다.
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(model.rows.prefix(6)) { row in
                                    topRow(row)
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

    /// 활성 상태 보기 아래쪽 요약과 같은 숫자. 커널 합계라 root 프로세스까지 담는다.
    @ViewBuilder
    private var loadBox: some View {
        if let load = model.load {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 18) {
                    PixelIcon(art: .computer, size: 32)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(verbatim: String(format: "%.0f%%", load.used))
                            .font(R95.mono(30))
                            .foregroundStyle(R95.navy)
                        Text("사용 중").font(R95.ui(13, bold: true))
                    }
                }
                loadRow(String(localized: "사용자"), load.user, fill: R95.navy)
                loadRow(String(localized: "시스템"), load.system, fill: R95.navy)
                // 유휴는 쓰이지 않은 몫이라 회색으로 물러나게 한다.
                loadRow(String(localized: "유휴"), load.idle, fill: R95.shadow)
            }
        } else {
            // 준비 중이거나 커널 값을 못 읽었다. 프로세스 합으로 지어내지 않는다 —
            // root 프로세스 몫이 유휴로 둔갑한다.
            VStack(alignment: .leading, spacing: 8) {
                PixelIcon(art: .computer, size: 32)
                Text(model.isWarmingUp ? String(localized: "측정 중…")
                                       : String(localized: "Mac 전체 부하를 읽지 못했습니다."))
                    .font(R95.ui(12))
                    .foregroundStyle(R95.deep)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func loadRow(_ label: String, _ percent: Double, fill: Color) -> some View {
        VStack(spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(label).font(R95.ui(12, bold: true))
                Spacer(minLength: 0)
                Text(verbatim: String(format: "%.1f%%", percent))
                    .font(R95.mono(12)).foregroundStyle(R95.navy)
            }
            Retro95ProgressBar(fraction: percent / 100, height: 14, fill: fill)
        }
    }

    private func topRow(_ row: CPURow) -> some View {
        VStack(spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(name(of: row)).font(R95.ui(12, bold: true))
                    .lineLimit(1).truncationMode(.tail)
                if case .process(let usage) = row {
                    Text(verbatim: usage.formattedPID)
                        .font(R95.mono(9)).foregroundStyle(R95.deep)
                }
                Spacer(minLength: 0)
                Text(row.formattedPercent).font(R95.mono(12)).foregroundStyle(R95.navy)
            }
            // 막대 끝이 코어 1개다. 여러 코어를 쓰면 막대는 꽉 차고 숫자가 100을 넘는다.
            Retro95ProgressBar(fraction: min(1, row.percent / 100), height: 14)
        }
    }

    private func name(of row: CPURow) -> String {
        switch row {
        case .process(let usage): usage.name
        // 활성 상태 보기에서 가장 크게 보이는 두 이름을 앞에 둬야 "kernel_task가 없다"로
        // 읽히지 않는다. 다만 이 줄엔 잠깐 돌고 끝난 프로세스 몫도 섞여 있어(실측: 빌드 중
        // 기계 787% 중 top도 약 390%를 어느 행에도 못 붙였다) "합계"라고 밝힌다.
        case .unlisted: String(localized: "kernel_task·WindowServer 등 목록 밖 합계")
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
        } else if model.rows.isEmpty {
            placeholder(String(localized: "지금 CPU를 쓰는 프로세스가 없습니다."),
                        detail: String(localized: "직전 구간 동안 아무것도 계산하지 않았습니다."))
        } else {
            // 주기적 갱신이 NSTableView 대리자로 재진입하지 않도록 List 대신 스크롤 뷰를 쓴다.
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(model.rows) { item in
                        row(item)
                        if item.id != model.rows.last?.id {
                            Rectangle().fill(R95.light).frame(height: 1)
                        }
                    }
                }
            }
            .scrollIndicators(.visible)
        }
    }

    private func row(_ item: CPURow) -> some View {
        HStack(spacing: 0) {
            Text(item.formattedPercent)
                .font(R95.mono(12)).foregroundStyle(R95.navy)
                .padding(.horizontal, 6)
                .frame(width: Columns.percent, alignment: .trailing)
            VStack(alignment: .leading, spacing: 2) {
                Text(name(of: item)).font(R95.ui(12, bold: true))
                    .foregroundStyle(R95.black)
                    .lineLimit(1).truncationMode(.middle)
                if let detail = detail(of: item) {
                    Text(detail).font(R95.ui(10)).foregroundStyle(R95.deep)
                        .lineLimit(1).truncationMode(.middle)
                }
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            // 열 머리가 이미 PID라 "pid " 접두어를 빼야 좁은 칸에서 줄이 꺾이지 않는다.
            // 합계 행은 여러 프로세스라 pid가 없다.
            Text(verbatim: item.pidText).font(R95.mono(10)).foregroundStyle(R95.deep)
                .padding(.horizontal, 6)
                .frame(width: Columns.pid, alignment: .trailing)
            HStack(spacing: 4) {
                if case .process(let usage) = item, let path = usage.executablePath {
                    let url = URL(filePath: path)
                    iconButton(.folder, String(localized: "Finder에서 보기")) { ItemActions.reveal(url) }
                    iconButton(.documents, String(localized: "경로 복사")) { ItemActions.copyPath(url) }
                }
            }
            .frame(width: Columns.actions)
        }
        .frame(minHeight: R95.tableRowHeight)
    }

    private func detail(of row: CPURow) -> String? {
        switch row {
        case .process(let usage): usage.displayPath
        case .unlisted:
            String(localized: "시스템 계정 프로세스와 잠깐 돌고 끝난 프로세스 몫입니다. App Store 앱은 하나씩 읽을 수 없습니다.")
        }
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

private extension CPURow {
    var pidText: String {
        switch self {
        case .process(let usage): "\(usage.pid)"
        case .unlisted: "—"
        }
    }
}
