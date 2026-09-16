import SwiftUI
import SweepKit

/// 회수 가능한 몫의 구성을 가로 막대 하나로 그린다.
///
/// **도넛을 대신한다.** 조각이 셋뿐이고 비율이 1:1:0.01인 경우가 흔한데,
/// 링에서는 가장 작은 조각이 실처럼 사라져 색만 있고 읽히지 않는다.
/// 막대는 같은 비율이 길이로 그대로 읽힌다.
struct ReclaimBar: View {
    let rows: [MenuBarSummary.Row]

    /// 아주 작은 조각도 보이게 하는 하한.
    ///
    /// 276MB가 52GB의 0.5%면 막대에서 2픽셀이 된다 — 있으나 마나다.
    /// 비율을 왜곡하지 않는 선에서 최소 두께를 준다.
    private let minimumFraction: Double = 0.02

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(rows) { row in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.tint(row.feature))
                        .frame(width: width(for: row, in: geo.size.width))
                }
            }
        }
        .frame(height: 8)
    }

    private func width(for row: MenuBarSummary.Row, in total: CGFloat) -> CGFloat {
        let sum = rows.reduce(Int64(0)) { $0 + $1.bytes }
        guard sum > 0 else { return 0 }
        let gaps = CGFloat(max(0, rows.count - 1)) * 2
        let usable = max(0, total - gaps)
        let fraction = max(minimumFraction, Double(row.bytes) / Double(sum))
        return usable * fraction
    }
}

/// 막대 아래 범례. 색과 이름을 잇는 유일한 자리다.
struct ReclaimLegend: View {
    let rows: [MenuBarSummary.Row]

    var body: some View {
        HStack(spacing: 16) {
            ForEach(rows) { row in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.tint(row.feature))
                        .frame(width: 7, height: 7)
                    Text("\(row.feature.displayName) \(row.formattedSize)")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
    }
}
