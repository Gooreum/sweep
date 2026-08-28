import SwiftUI
import SweepKit

/// 안전도를 색으로 구분해 보여주는 작은 배지.
/// 위험한 항목이 목록에서 눈에 띄어야 실수로 지우지 않는다.
struct SafetyBadge: View {
    let level: SafetyLevel

    var body: some View {
        Text(level.displayName)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(level.tint.opacity(0.18), in: Capsule())
            .foregroundStyle(level.tint)
    }
}

extension SafetyLevel {
    /// 신호등과 같은 색 배치. 별도 학습 없이 위험도를 읽을 수 있다.
    var tint: Color {
        switch self {
        case .safe: .green
        case .caution: .orange
        case .danger: .red
        }
    }
}

/// 정리 후보 한 줄. 경고 바 · 체크박스 · (이름 + 배지) · 설명 · 크기.
struct ItemRow: View {
    let item: CleanupItem
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 10) {
            // 되돌릴 수 없는 항목은 훑어보다가도 걸리도록 좌측에 색 바를 둔다
            RoundedRectangle(cornerRadius: 1.5)
                .fill(item.safety.needsWarningBar ? item.safety.tint : .clear)
                .frame(width: 3)

            Toggle("", isOn: $isOn)
                .toggleStyle(.checkbox)
                .labelsHidden()

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.displayName)
                        .font(Theme.bodyText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    // 배지는 이름 옆에 둔다. 크기 옆에 두면 숫자 열 정렬을 방해한다.
                    SafetyBadge(level: item.safety)
                }
                // 설명이 없는 항목까지 빈 줄을 만들면 목록 높이가 들쭉날쭉해진다
                if !item.detail.isEmpty {
                    Text(item.detail)
                        .font(Theme.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            // 우측은 크기 열만 남겨 값끼리 비교할 수 있게 한다
            Text(item.formattedSize)
                .font(Theme.bodyText.monospacedDigit())
                .foregroundStyle(isOn ? .primary : .secondary)
                .frame(width: 88, alignment: .trailing)
        }
        .padding(.vertical, 2)
        // #D7E6F6. 선택이 능동적으로 보여야 한다 —
        // 미선택 행이 비활성처럼 읽히면 뭘 지우는지 헷갈린다.
        .listRowBackground(isOn ? Theme.selectionTint.opacity(0.55) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { isOn.toggle() }
        .help(item.url.path)
    }
}
