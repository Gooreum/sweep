import SwiftUI
import AppKit
import SweepKit

/// CPU 탭. 지금 무엇이 CPU를 쓰고 있는지만 보여준다.
///
/// **끝내는 버튼이 없다.** App Sandbox에서는 남의 프로세스에 시그널을 보낼 수 없고
/// (`application.sb`가 `(allow signal (target same-sandbox))`만 연다),
/// Automation entitlement를 붙여 Apple Event로 `quit`을 보내도 샌드박스가
/// 상대를 "실행 중이 아님"으로 감춘다 — 실측으로 세 갈래를 모두 확인했다.
/// 그래서 끝내는 일은 활성 상태 보기에 넘긴다.
struct CPUView: View {

    /// `@State`가 아니다. 탭을 옮기면 트리가 죽어 "측정 중…"을 2초 동안 다시 본다.
    /// `DiskMapView`가 모델을 주입받는 것과 같은 이유다.
    @Bindable var model: CPUModel

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider().overlay(Theme.border)

            content
        }
        // 화면이 살아 있는 동안만 잰다. 탭을 떠나면 SwiftUI가 이 작업을 취소한다 —
        // CPU를 보는 화면이 안 보이는 동안 CPU를 쓰면 안 된다.
        .task { await model.run() }
    }

    // MARK: - 머리글

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                // **분모를 먼저 말한다.** 이 화면의 숫자가 뜻하는 바가 그것이다.
                // 무엇이 빠져 있는지도 같이 말한다 — 활성 상태 보기와 목록이
                // 다른 이유를 화면에서 바로 알 수 있어야 한다.
                Text("코어 \(model.cores)개 전체를 100%로 본 비중입니다. 내 계정으로 실행된 프로세스만 보입니다.")
                    .font(Theme.bodyText)
                    .foregroundStyle(Theme.textSecondary)

                // 활성 상태 보기를 같이 켜 두면 같은 프로세스가 코어 수만큼 차이 난다.
                // 이유를 안 적으면 둘 중 하나가 틀린 것으로 읽힌다.
                Text("활성 상태 보기는 코어 하나를 100%로 세므로 같은 프로세스도 숫자가 다릅니다.")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 행이 아니라 여기에 하나만 둔다. 활성 상태 보기는 특정 프로세스를
            // 지정해 열 수 없어서, 행마다 두면 "이 프로세스로 데려다준다"는
            // 거짓 약속이 된다.
            Button("활성 상태 보기 열기") { openActivityMonitor() }
                .buttonStyle(SecondaryButtonStyle())
                .fixedSize()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    // MARK: - 본문

    @ViewBuilder
    private var content: some View {
        if model.isWarmingUp {
            // 빈 목록과 구분한다. 빈 목록은 "아무도 안 쓴다"이고 이건 "아직 모른다"이다.
            placeholder("측정 중…", detail: "두 번 재야 사용률이 나옵니다.")
        } else if model.usage.isEmpty {
            placeholder("지금 CPU를 쓰는 프로세스가 없습니다.",
                        detail: "직전 구간 동안 아무것도 계산하지 않았습니다.")
        } else {
            // `List`를 쓰지 않는다. 주기마다 목록이 통째로 갈리는데 `List`는
            // AppKit 표(NSTableView)로 그려져, 갱신이 표의 대리자 호출 안으로
            // 되돌아온다 — "reentrant operation in its NSTableView delegate"가
            // 실측으로 16초에 28회 찍혔고 애플은 "앞으로 assert가 된다"고 예고한다.
            //
            // 상한이 20행이라 표가 주는 것(행 재사용·큰 목록 스크롤)이 필요 없다.
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(model.usage) { usage in
                        row(usage)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 8)

                        // 마지막 줄 아래에는 긋지 않는다. 목록이 끝났는데
                        // 선이 남으면 더 있는 것처럼 보인다.
                        if usage.id != model.usage.last?.id {
                            Divider().overlay(Theme.border)
                        }
                    }
                }
            }
        }
    }

    private func row(_ usage: ProcessUsage) -> some View {
        HStack(spacing: 12) {
            // 이 화면에서 가장 중요한 숫자다. 폭을 고정하고 자릿수를 맞춰
            // 주기마다 값이 바뀌어도 소수점이 제자리에 있게 한다.
            Text(usage.formattedPercent)
                .font(Theme.bodyMono)
                .foregroundStyle(Theme.tint(.cpu))
                .frame(width: 72, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                Text(usage.name)
                    .font(Theme.bodyText)
                    .lineLimit(1)
                    .truncationMode(.middle)

                // 이름만으로는 어느 것인지 모르는 프로세스가 많다 — `node`·`ruby`가
                // 어느 작업인지는 경로를 봐야 안다. 못 읽었으면 줄 자체를 안 그린다.
                if let path = usage.displayPath {
                    Text(path)
                        .font(Theme.caption)
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 폭을 고정한다. 안 하면 경로가 긴 행에서 이 열이 밀려
            // 행마다 pid가 다른 자리에 찍힌다.
            Text(usage.formattedPID)
                .font(Theme.captionMono)
                .foregroundStyle(Theme.textTertiary)
                .frame(width: 88, alignment: .trailing)

            // 경로가 있는 것만 준다. 누를 곳이 없는 버튼을 두지 않는다.
            if let path = usage.executablePath {
                let url = URL(filePath: path)
                HStack(spacing: 2) {
                    iconButton("folder", "Finder에서 보기") { ItemActions.reveal(url) }
                    iconButton("doc.on.doc", "경로 복사") { ItemActions.copyPath(url) }
                }
            }
        }
    }

    // MARK: - 부속

    /// 활성 상태 보기를 연다. **샌드박스에서도 된다** — 실측으로 확인했다.
    /// 남의 프로세스를 다루는 것 중 이 앱이 할 수 있는 유일한 일이다.
    private func openActivityMonitor() {
        NSWorkspace.shared.open(
            URL(filePath: "/System/Applications/Utilities/Activity Monitor.app"))
    }

    private func iconButton(_ symbol: String, _ hint: String,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: Theme.Icon.small))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(hint)
    }

    private func placeholder(_ title: String, detail: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(Theme.headline)
                .foregroundStyle(Theme.textPrimary)
            Text(detail)
                .font(Theme.bodyText)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
