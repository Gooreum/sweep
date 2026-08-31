import SwiftUI
import SweepKit

/// 디스크 구성을 조각으로 보여주는 도넛.
///
/// 막대 하나로는 "얼마나 찼는가"밖에 못 말한다. 스캔 결과가 있으면
/// **회수 가능한 몫을 사용됨에서 떼어내** 따로 보여준다 —
/// "252GB 중 6.78GB는 지금 비울 수 있다"가 한눈에 읽힌다.
struct DiskDonut: View {
    struct Slice: Identifiable {
        let id: String
        let label: String
        let bytes: Int64
        let color: Color
    }

    let slices: [Slice]
    let centerValue: String
    let centerCaption: String
    var diameter: CGFloat = 176

    private var total: Int64 { slices.reduce(0) { $0 + $1.bytes } }

    var body: some View {
        HStack(spacing: 32) {
            donut
            legend
            Spacer(minLength: 0)
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

    private var legend: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(slices) { slice in
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(slice.color)
                        .frame(width: 10, height: 10)
                    Text(slice.label)
                        .font(Theme.bodyText)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer(minLength: 24)
                    Text(ByteCountFormatter.string(fromByteCount: slice.bytes, countStyle: .file))
                        .font(Theme.bodyMono)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .frame(maxWidth: 260)
    }

    /// 조각의 시작·끝 지점(0~1). 총합이 0이면 아무것도 그리지 않는다.
    private var offsets: [(slice: Slice, start: Double, end: Double)] {
        guard total > 0 else { return [] }
        var cursor = 0.0
        return slices.map { slice in
            let span = Double(slice.bytes) / Double(total)
            let start = cursor
            cursor += span
            return (slice, start, cursor)
        }
    }
}
