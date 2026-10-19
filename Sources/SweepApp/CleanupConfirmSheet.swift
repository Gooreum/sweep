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
    /// 휴지통으로 옮기지 않고 바로 지우는가(`Feature.removesPermanently`).
    /// 그렇다면 "복원할 수 있습니다"는 거짓말이다 — 문구와 기본 버튼이 다 바뀐다.
    var permanent = false
    let onConfirm: () -> Void
    let onCancel: () -> Void

    /// **고른 것 중** 되돌릴 수 없는 항목 수. 목록 전체가 아니라 선택분을 센다.
    private var riskyCount: Int {
        model.selectedItems.filter { $0.safety == .danger }.count
    }

    /// 고른 것 중 iCloud Drive 휴지통 항목 수. 이것은 이 Mac만이 아니라 다른 기기에서도 지워진다.
    private var iCloudCount: Int {
        model.selectedItems.filter { TrashScanner.isInICloudTrash($0.url) }.count
    }

    var body: some View {
        Retro95Dialog(title: permanent
                        ? String(localized: "\(model.selectedItems.count)개 항목을 영구 삭제합니다")
                        : String(localized: "\(model.selectedItems.count)개 항목을 휴지통으로 옮깁니다"),
                      icon: .warning) {
            VStack(alignment: .leading, spacing: 12) {
                Text(bodyText)
                    .foregroundStyle(R95.deep)
                    .fixedSize(horizontal: false, vertical: true)
                summaryBlock
            }
        } buttons: {
            if permanent {
                // 되돌릴 수 없는 동작이다. Return 한 번에 지워지지 않도록 기본 버튼은 취소다.
                Button("취소", action: onCancel)
                    .buttonStyle(Retro95ButtonStyle(isDefault: true))
                    .keyboardShortcut(.defaultAction)
                Button("영구 삭제", action: onConfirm)
                    .buttonStyle(Retro95ButtonStyle())
            } else {
                Button("취소", action: onCancel)
                    .buttonStyle(Retro95ButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button("휴지통으로 옮기기", action: onConfirm)
                    .buttonStyle(Retro95ButtonStyle(isDefault: true))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .frame(width: 440)
        .background(R95.gray)
    }

    /// 위험한 것이 섞였을 때만 그것을 먼저 말한다. 없으면 군더더기가 된다.
    private var bodyText: String {
        if permanent {
            let base = String(localized: "휴지통에서 바로 지워져 되돌릴 수 없습니다. 지운 만큼 공간이 바로 확보됩니다.")
            return iCloudCount > 0
                ? base + " " + String(localized: "이 중 \(iCloudCount)개는 iCloud Drive 항목이라 다른 기기에서도 지워집니다.")
                : base
        }
        return riskyCount > 0
            ? String(localized: "이 중 \(riskyCount)개는 다시 만들 수 없습니다 — 휴지통을 비우면 처음부터 받아야 합니다. 휴지통을 비우기 전까지는 모두 복원할 수 있습니다. 휴지통을 비워야 공간이 확보됩니다.")
            : String(localized: "휴지통을 비우기 전까지 복원할 수 있습니다. 휴지통을 비워야 공간이 확보됩니다.")
    }

    private var summaryBlock: some View {
        VStack(spacing: 0) {
            row(permanent ? String(localized: "지울 항목") : String(localized: "옮길 항목"),
                String(localized: "\(model.selectedItems.count)개"), tint: R95.black)
            row(permanent ? String(localized: "지울 용량") : String(localized: "옮길 용량"),
                model.formattedSelectedSize, tint: R95.navy)
            if riskyCount > 0 {
                row(String(localized: "다시 만들 수 없음"), String(localized: "\(riskyCount)개"), tint: R95.danger, isRisky: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(R95.white)
        .retroSunken()
    }

    private func row(_ label: String, _ value: String, tint: Color, isRisky: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(R95.ui(11))
                .foregroundStyle(R95.deep)
            Spacer(minLength: 12)
            if isRisky { SafetyChip(level: .danger) }
            Text(value)
                .font(R95.mono())
                .foregroundStyle(tint)
        }
        .frame(height: 30)
    }
}
