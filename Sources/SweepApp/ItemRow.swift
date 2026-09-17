import SwiftUI
import SweepKit

extension SafetyLevel {

    /// 안전도를 나타내는 아이콘.
    ///
    /// **안전에는 색을 쓰지 않는다.** 안전이 기본값이라 목록 대부분이 안전인데,
    /// 거기에 초록 알약을 붙이면 화면이 통째로 색으로 덮여 정작 위험한 것이 묻힌다.
    /// 예전 `SafetyBadge`가 그랬다.
    var symbolName: String {
        switch self {
        case .safe: "circle"
        case .caution: "exclamationmark.triangle"
        case .danger: "lock.fill"
        }
    }

    /// 아이콘과 설명글에 쓰는 색. 안전은 무채색이다.
    ///
    /// 값은 `Theme`에 있다 — 화면에서 hex를 직접 쓰지 않는다.
    var tint: Color {
        switch self {
        case .safe: Theme.textTertiary
        case .caution: Theme.cautionText
        case .danger: Theme.dangerText
        }
    }
}

/// 정리 후보 한 줄. 체크박스 · 안전도 아이콘 · (이름 + 설명) · 크기.
///
/// 높이 56. 예전에는 이름 옆에 색 배지가, 왼쪽에 3pt 경고 바가 있었다.
/// 배지를 아이콘 한 칸으로 바꾸고 경고 바를 없애 이름이 시작하는 x가 모든 행에서 같아졌다.
struct ItemRow: View {
    let item: CleanupItem
    @Binding var isOn: Bool


    var body: some View {
        HStack(spacing: 14) {
            // 되돌릴 수 없는 항목도 **고를 수는 있다.**
            //
            // 한때 아예 막아 뒀는데, 그러면 진짜로 지우려는 사람이 앱에서 할 방법이
            // 없어진다 — 심사 제출본을 정리하는 것도 정당한 작업이다.
            // 실수 방지는 기본 미선택 · 자물쇠 아이콘 · 확인 시트가 맡는다.
            Toggle("", isOn: $isOn)
                .toggleStyle(.checkbox)
                .labelsHidden()

            // 등급마다 도형이 달라도 이름 열이 흔들리지 않게 칸을 고정한다.
            Image(systemName: item.safety.symbolName)
                .font(.system(size: Theme.safetyIconSlot))
                .foregroundStyle(item.safety.tint)
                .frame(width: Theme.safetyIconSlot + 4)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayName)
                    .font(Theme.bodyText)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                // 설명이 없는 항목까지 빈 줄을 만들면 목록 높이가 들쭉날쭉해진다.
                if !item.detail.isEmpty {
                    Text(item.detail)
                        .font(Theme.caption)
                        // 위험도가 여기서 한 번 더 읽힌다 — 아이콘만으로는 작다.
                        .foregroundStyle(item.safety == .safe
                                         ? Theme.textSecondary : item.safety.tint)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 12)

            // 우측은 크기 열만 남겨 값끼리 비교할 수 있게 한다.
            // 고른 것만 또렷하게 — 훑을 때 무엇을 담았는지가 숫자로 보인다.
            Text(item.formattedSize)
                .font(Theme.bodyMono)
                .foregroundStyle(isOn ? Theme.textPrimary : Theme.textTertiary)
                .frame(width: 88, alignment: .trailing)
        }
        .padding(.horizontal, 24)
        .frame(height: Theme.rowHeightComfortable)
        // 면을 통째로 칠하지 않고 9%만 얹는다. 예전에는 불투명 `surfaceRaised`였는데,
        // 목록의 절반이 선택된 상태에서 화면이 두 덩어리로 갈려 보였다.
        .background(isOn ? Theme.rowSelected : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { isOn.toggle() }
        .help(item.safety == .danger
              ? "되돌릴 수 없습니다 — \(item.url.path)" : item.url.path)
    }
}
