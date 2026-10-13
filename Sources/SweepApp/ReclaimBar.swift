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
                    Rectangle()
                        .fill(R95.reclaimColor(row.feature))
                        .frame(width: width(for: row, in: geo.size.width))
                }
            }
        }
        .frame(height: 16)
        .border(R95.black, width: 1)
    }

    private func width(for row: MenuBarSummary.Row, in total: CGFloat) -> CGFloat {
        let sum = rows.reduce(Int64(0)) { $0 + $1.bytes }
        guard sum > 0 else { return 0 }
        let gaps = CGFloat(max(0, rows.count - 1)) * 2
        let usable = max(0, total - gaps)
        // 하한을 적용한 뒤 정규화해 작은 조각 때문에 전체 폭을 넘지 않게 한다.
        let weights = rows.map { max(minimumFraction, Double($0.bytes) / Double(sum)) }
        let fraction = max(minimumFraction, Double(row.bytes) / Double(sum))
        return usable * fraction / weights.reduce(0, +)
    }
}

/// 막대 아래 범례. 색과 이름을 잇는 유일한 자리다.
struct ReclaimLegend: View {
    let rows: [MenuBarSummary.Row]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            legend
            legendRows
        }
    }

    private var legend: some View {
        HStack(spacing: 12) {
            ForEach(rows) { row in
                HStack(spacing: 6) {
                    Rectangle()
                        .fill(R95.reclaimColor(row.feature))
                        .frame(width: 8, height: 8)
                        .border(R95.black, width: 1)
                    Text("\(row.feature.displayName) \(row.formattedSize)")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
    }
    private var legendRows: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(rows) { row in
                HStack(spacing: 6) {
                    Rectangle().fill(R95.reclaimColor(row.feature))
                        .frame(width: 8, height: 8).border(R95.black, width: 1)
                    Text("\(row.feature.displayName) \(row.formattedSize)")
                        .font(R95.ui(11)).foregroundStyle(R95.deep)
                }
            }
        }
    }
}
