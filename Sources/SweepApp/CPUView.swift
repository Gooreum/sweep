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
            .init(title: String(localized: "사용률 ▼"), width: percent),
            .init(title: String(localized: "프로그램과 위치")),
            .init(title: String(localized: "번호"), width: pid),
            .init(title: String(localized: "파일 위치"), width: actions)
        ]
    }

    var body: some View {
        VStack(spacing: 12) {
            header
            HStack(alignment: .top, spacing: 10) {
                chart.frame(width: 272)
                VStack(spacing: 10) {
                    processTable
                    detailPanel
                }
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
                Text("프로그램별 숫자는 코어 하나를 모두 쓰면 100%예요. 여러 코어를 함께 쓰면 이 Mac에서는 최대 \(model.cores * 100)%까지 나와요.")
                    .font(R95.ui(11))
                    .foregroundStyle(R95.deep)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Mac이 느리다면 오른쪽 표에서 숫자가 큰 프로그램을 눌러 보세요. 종료가 필요하면 활성 상태 보기를 열면 돼요.")
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
            String(localized: "Mac을 바쁘게 하는 프로그램을 찾아보세요. 이 Mac은 코어가 \(model.cores)개예요. 빠른 코어 \(performance)개, 절전 코어 \(efficiency)개예요.")
        } else {
            String(localized: "Mac을 바쁘게 하는 프로그램을 찾아보세요. 이 Mac은 코어가 \(model.cores)개예요.")
        }
    }

    private var chart: some View {
        VStack(spacing: 10) {
            Retro95GroupBox(title: String(localized: "CPU 사용량")) {
                loadBox
            }
            Retro95GroupBox(title: String(localized: "많이 쓰는 프로그램")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("코어 하나를 모두 쓰면 막대가 꽉 차요. 더 많이 쓰는 프로그램은 옆의 숫자로 비교해 주세요.")
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
                    PixelIcon(art: .chip, size: 32)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(verbatim: String(format: "%.0f%%", load.used))
                            .font(R95.mono(30))
                            .foregroundStyle(R95.navy)
                        Text("사용 중").font(R95.ui(13, bold: true))
                    }
                }
                loadRow(String(localized: "프로그램"), load.user, fill: R95.navy)
                loadRow(String(localized: "시스템"), load.system, fill: R95.navy)
                // 유휴는 쓰이지 않은 몫이라 회색으로 물러나게 한다.
                loadRow(String(localized: "여유"), load.idle, fill: R95.shadow)
            }
        } else {
            // 준비 중이거나 커널 값을 못 읽었다. 프로세스 합으로 지어내지 않는다 —
            // root 프로세스 몫이 유휴로 둔갑한다.
            VStack(alignment: .leading, spacing: 8) {
                PixelIcon(art: .chip, size: 32)
                Text(model.isWarmingUp ? String(localized: "측정 중…")
                                       : String(localized: "Mac 전체의 CPU 사용량을 읽지 못했어요. 잠시 뒤 숫자가 나오는지 확인해 주세요."))
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
        case .unlisted: String(localized: "kernel_task, WindowServer 등 나머지 합계")
        }
    }

    private var processTable: some View {
        Retro95GroupBox(title: String(localized: "프로그램 사용률순")) {
            VStack(spacing: 0) {
                Retro95TableHeader(columns: Columns.headers)
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(R95.white)
            .retroSunken()
            // 마우스가 표 위에 있는 동안은 순서를 붙잡는다. 값만 갱신된다.
            .onHover { model.holdOrder($0) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var content: some View {
        if model.isWarmingUp {
            placeholder(String(localized: "측정 중…"),
                        detail: String(localized: "CPU 사용량을 재고 있어요. 잠시 뒤 많이 쓰는 순서로 보여드려요."))
        } else if model.rows.isEmpty {
            placeholder(String(localized: "지금은 표시할 프로그램이 없어요."),
                        detail: String(localized: "프로그램이 CPU를 쓰기 시작하면 여기에 나타나요."))
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
        let selected = item.pid != nil && item.pid == model.selectedPID
        return HStack(spacing: 0) {
            Text(item.formattedPercent)
                .font(R95.mono(12)).foregroundStyle(selected ? R95.white : R95.navy)
                .padding(.horizontal, 6)
                .frame(width: Columns.percent, alignment: .trailing)
            VStack(alignment: .leading, spacing: 2) {
                Text(name(of: item)).font(R95.ui(12, bold: true))
                    .foregroundStyle(selected ? R95.white : R95.black)
                    .lineLimit(1).truncationMode(.middle)
                if let detail = detail(of: item) {
                    Text(detail).font(R95.ui(10))
                        .foregroundStyle(selected ? R95.white : R95.deep)
                        .lineLimit(1).truncationMode(.middle)
                }
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            // 열 머리가 이미 PID라 "pid " 접두어를 빼야 좁은 칸에서 줄이 꺾이지 않는다.
            // 합계 행은 여러 프로세스라 pid가 없다.
            Text(verbatim: item.pidText).font(R95.mono(10))
                .foregroundStyle(selected ? R95.white : R95.deep)
                .padding(.horizontal, 6)
                .frame(width: Columns.pid, alignment: .trailing)
            HStack(spacing: 4) {
                if case .process(let usage) = item, let path = usage.executablePath {
                    let url = URL(filePath: path)
                    iconButton(.folder, String(localized: "Finder에서 보기")) { ItemActions.reveal(url) }
                    iconButton(.documents, String(localized: "위치 복사")) { ItemActions.copyPath(url) }
                }
            }
            .frame(width: Columns.actions)
        }
        .frame(minHeight: R95.tableRowHeight)
        .background(selected ? R95.navy : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { if let pid = item.pid { model.select(pid) } }
    }

    private func detail(of row: CPURow) -> String? {
        switch row {
        case .process(let usage): usage.displayPath
        case .unlisted:
            String(localized: "macOS 자체와, 짧게 켜졌다 꺼져서 따로 못 잰 프로그램이 쓴 몫이에요.")
        }
    }


    // MARK: - 자세히

    private var detailPanel: some View {
        Retro95GroupBox(title: String(localized: "자세히")) {
            Group {
                if let details = model.details {
                    detailContent(details)
                } else if model.selectedPID != nil {
                    Text("이 프로그램은 이미 끝났어요. 다른 프로그램을 눌러 보세요.")
                        .font(R95.ui(12)).foregroundStyle(R95.deep)
                } else {
                    Text("표에서 프로그램을 골라 보세요. 알려진 프로그램은 하는 일과 종료해도 되는지 설명해 드려요.")
                        .font(R95.ui(12)).foregroundStyle(R95.deep)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity)
    }

    private func detailContent(_ details: ProcessDetails) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if let app = details.app {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                        .resizable().frame(width: 24, height: 24)
                }
                Text(details.name).font(R95.ui(13, bold: true)).foregroundStyle(R95.black)
                if let app = details.app {
                    Text(appLine(app)).font(R95.ui(11)).foregroundStyle(R95.deep)
                } else if !details.isMine {
                    Text("macOS나 다른 계정이 켠 프로그램이에요").font(R95.ui(11)).foregroundStyle(R95.deep)
                }
            }
            if let known = details.known {
                Text(known.summary).font(R95.ui(12)).foregroundStyle(R95.black)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(known.whenBusy) \(adviceText(known.advice))")
                    .font(R95.ui(12)).foregroundStyle(R95.deep)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Rectangle().fill(R95.light).frame(height: 1)
            fact(String(localized: "누가 켰나요"), details.launchedByText
                ?? (details.launchedBy.isEmpty ? String(localized: "macOS가 직접 켰어요") : nil))
            fact(String(localized: "켜진 지"), details.runningText())
            fact(String(localized: "메모리"), details.memoryText)
            fact(String(localized: "실행한 명령"), details.commandLineText, copy: details.arguments)
            fact(String(localized: "파일 위치"), details.executablePath.map(displayPath), reveal: details.executablePath)
        }
    }

    /// 한 줄. 값이 없으면(못 읽었으면) 줄을 그리지 않는다 — "알 수 없음"으로 채우지 않는다.
    @ViewBuilder
    private func fact(_ label: String, _ value: String?, copy: [String]? = nil, reveal: String? = nil) -> some View {
        if let value {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(label).font(R95.ui(11, bold: true)).foregroundStyle(R95.deep)
                    .frame(width: 92, alignment: .leading)
                Text(verbatim: value).font(R95.ui(11)).foregroundStyle(R95.black)
                    .lineLimit(2).truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if copy != nil {
                    Button("복사") { ItemActions.copyText(value) }
                        .buttonStyle(Retro95ButtonStyle()).fixedSize()
                }
                if let reveal {
                    iconButton(.folder, String(localized: "Finder에서 보기")) {
                        ItemActions.reveal(URL(filePath: reveal))
                    }
                    iconButton(.documents, String(localized: "위치 복사")) {
                        ItemActions.copyPath(URL(filePath: reveal))
                    }
                }
            }
        }
    }

    private func appLine(_ app: AppIdentity) -> String {
        if let version = app.version {
            String(localized: "\(app.name) \(version)의 일부로 실행 중이에요")
        } else {
            String(localized: "\(app.name)의 일부로 실행 중이에요")
        }
    }

    private func adviceText(_ advice: KnownProcess.Advice) -> String {
        switch advice {
        case .leaveIt: String(localized: "Mac 작동에 필요한 프로그램이에요. 그대로 켜 두세요.")
        case .safeToQuit: String(localized: "필요 없는 작업이면 종료해도 괜찮아요. 진행 중인 작업은 멈춰요.")
        case .quitInApp: String(localized: "종료하려면 이 프로그램을 켠 앱이나 터미널에서 작업을 먼저 멈춰 주세요.")
        }
    }

    private func displayPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
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
            PixelIcon(art: .chip, size: 32)
            Text(title).font(R95.ui(13, bold: true)).foregroundStyle(R95.black)
            Text(detail).font(R95.ui(12)).foregroundStyle(R95.deep)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private extension CPURow {
    /// 합계 행은 프로세스 하나가 아니라 고를 수 없다.
    var pid: pid_t? {
        if case .process(let usage) = self { usage.pid } else { nil }
    }

    var pidText: String {
        switch self {
        case .process(let usage): "\(usage.pid)"
        case .unlisted: "—"
        }
    }
}
