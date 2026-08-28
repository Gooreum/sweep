import SwiftUI
import SweepKit

/// 안전도를 색으로 구분해 보여주는 작은 배지.
/// 위험한 항목이 목록에서 눈에 띄어야 실수로 지우지 않는다.
struct SafetyBadge: View {
    let level: SafetyLevel

    var body: some View {
        Text(level.displayName)
            .font(.caption2.weight(.semibold))
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

/// 정리 후보 한 줄. 체크박스 · 이름 · 설명 · 안전도 · 크기.
struct ItemRow: View {
    let item: CleanupItem
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayName)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    // 설명이 없는 항목까지 빈 줄을 만들면 목록 높이가 들쭉날쭉해진다
                    if !item.detail.isEmpty {
                        Text(item.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                SafetyBadge(level: item.safety)

                Text(item.formattedSize)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 88, alignment: .trailing)
            }
        }
        .toggleStyle(.checkbox)
        .help(item.url.path)
    }
}
