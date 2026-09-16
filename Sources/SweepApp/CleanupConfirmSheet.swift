import SwiftUI
import SweepKit

/// 정리 직전 확인 시트.
///
/// `.confirmationDialog`을 쓰지 않는다 — 세 줄 요약 블록이 필요하기 때문이다.
/// 시스템 다이얼로그는 제목과 버튼만 받는다.
///
/// **되돌릴 수 없는 것이 섞였는지를 여기서 말한다.** 한때 그런 항목은 아예 고를 수
/// 없게 막아 뒀는데, 그러면 진짜로 지우려는 사람이 앱에서 할 방법이 없어진다.
/// 막는 대신 **지우기 직전에 몇 개가 섞였는지 세어 보여준다** — 여기가 마지막 자리다.
struct CleanupConfirmSheet: View {
    @Bindable var model: ScanModel
    let onConfirm: () -> Void
    let onCancel: () -> Void

    /// **고른 것 중** 되돌릴 수 없는 항목 수. 목록 전체가 아니라 선택분을 센다.
    private var riskyCount: Int {
        model.selectedItems.filter { $0.safety == .danger }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(model.selectedItems.count)개 항목을 휴지통으로 옮깁니다")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            Text(bodyText)
                .font(Theme.bodyText)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            summaryBlock
                .padding(.top, 20)

            HStack(spacing: 10) {
                Spacer()
                Button("취소", action: onCancel)
                    .buttonStyle(SecondaryButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button("휴지통으로 옮기기", action: onConfirm)
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 22)
        }
        .padding(26)
        .frame(width: 440)
        .background(Theme.surfaceRaised)
    }

    /// 위험한 것이 섞였을 때만 그것을 먼저 말한다. 없으면 군더더기가 된다.
    private var bodyText: String {
        riskyCount > 0
            ? "이 중 \(riskyCount)개는 되돌릴 수 없습니다 — 다시 만들려면 처음부터 받아야 합니다. "
                + "나머지는 휴지통에서 30일간 복구할 수 있습니다."
            : "휴지통에서 30일간 복구할 수 있습니다."
    }

    private var summaryBlock: some View {
        VStack(spacing: 0) {
            row("옮길 항목", "\(model.selectedItems.count)개", tint: Theme.textPrimary)
            row("확보 용량", model.formattedSelectedSize, tint: Theme.accentText)
            if riskyCount > 0 {
                row("되돌릴 수 없음", "\(riskyCount)개", tint: Theme.dangerText)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.24),
                    in: RoundedRectangle(cornerRadius: 8))
    }

    private func row(_ label: String, _ value: String, tint: Color) -> some View {
        HStack {
            Text(label)
                .font(Theme.caption)
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 12)
            Text(value)
                .font(Theme.bodyMono)
                .foregroundStyle(tint)
        }
        .frame(height: 30)
    }
}
