import SwiftUI
import SweepKit

/// 전체를 100으로 두고 구성을 조각으로 보여주는 도넛.
///
/// 막대 하나로는 "얼마나 찼는가"밖에 못 말한다. 조각으로 나누면 **무엇이
/// 얼마를 차지하는지**가 한눈에 읽힌다 — 디스크는 "252GB 중 6.78GB는 지금
/// 비울 수 있다", CPU는 "15.3%는 Chrome이 쓰고 58.9%는 놀고 있다".
///
/// 디스크(바이트)와 CPU(비중) 양쪽이 쓰므로 **값의 단위를 모른다.**
/// 범례에 찍을 문자열은 부르는 쪽이 만들어 넘긴다.
struct ShareDonut: View {
    struct Slice: Identifiable {
        let id: String
        let label: String
        let value: Double
        /// 범례에 찍을 문자열. "6.78 GB"이거나 "15.3%"다.
        let detail: String
        let color: Color
    }

    let slices: [Slice]
    let centerValue: String
    let centerCaption: String
    var diameter: CGFloat = 176

    /// 도넛과 범례를 나란히 둘지 위아래로 쌓을지.
    ///
    /// 좁은 칸(CPU 탭의 왼쪽 260pt)에서 나란히 두면 도넛도 범례도 찌그러진다.
    var stacked: Bool = false

    private var total: Double { slices.reduce(0) { $0 + $1.value } }

    var body: some View {
        if stacked {
            VStack(alignment: .leading, spacing: 20) {
                donut
                    .frame(maxWidth: .infinity)
                legend
            }
        } else {
            HStack(spacing: 32) {
                donut
                legend
                Spacer(minLength: 0)
            }
        }
    }

    private var donut: some View {
        ZStack {
            // 조각을 12시부터 시계방향으로 쌓는다.
            ForEach(Array(offsets.enumerated()), id: \.element.slice.id) { _, item in
                Circle()
                    .trim(from: item.start, to: item.end)
                    .stroke(item.slice.color,
                            style: StrokeStyle(lineWidth: 22, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }

            VStack(spacing: 2) {
                Text(centerValue)
                    .font(Theme.headlineMono)
                    .foregroundStyle(Theme.textPrimary)
                Text(centerCaption)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(width: diameter, height: diameter)
        .animation(Theme.transition, value: total)
    }

    /// 색칩 · 이름 · 용량 세 열.
    ///
    /// `Spacer`로 밀지 않는다. 남는 폭을 전부 먹어 **레이블이 짧을수록 간격이
    /// 벌어졌다** — 고정 폭 260pt 안에서 "사용됨"과 값 사이가 150pt였다.
    ///
    /// `Grid`는 열을 맞추면서 **콘텐츠 크기로** 잡히므로 간격이
    /// `horizontalSpacing` 그대로다. 값은 열 안에서 오른쪽 정렬해 자릿수를
    /// 맞춘다 — 원래 `Spacer`를 쓴 이유가 그것이었고, 그 목적은 유지한다.
    private var legend: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
            ForEach(slices) { slice in
                GridRow {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(slice.color)
                        .frame(width: 10, height: 10)

                    Text(slice.label)
                        .font(Theme.bodyText)
                        .foregroundStyle(Theme.textPrimary)

                    Text(slice.detail)
                        .font(Theme.bodyMono)
                        .foregroundStyle(Theme.textSecondary)
                        .gridColumnAlignment(.trailing)
                }
            }
        }
    }

    /// 조각의 시작·끝 지점(0~1). 총합이 0이면 아무것도 그리지 않는다.
    private var offsets: [(slice: Slice, start: Double, end: Double)] {
        guard total > 0 else { return [] }
        var cursor = 0.0
        return slices.map { slice in
            let span = slice.value / total
            let start = cursor
            cursor += span
            return (slice, start, cursor)
        }
    }
}
