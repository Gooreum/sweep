import SwiftUI

/// 가운데에 퍼센트를 담는 원형 진행 표시.
///
/// 막대는 화면 한구석에서 얇게 지나가지만 이건 화면의 중심을 차지한다 —
/// 스캔이 오래 걸리는 동안 사용자가 볼 것이 이것뿐이다.
struct RingGauge: View {
    let percent: Int
    let caption: String
    var diameter: CGFloat = 180

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.separator, lineWidth: 10)

            Circle()
                .trim(from: 0, to: Double(percent) / 100)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                // 기본은 3시에서 시작한다. 12시에서 시작해야 진행으로 읽힌다.
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.25), value: percent)

            VStack(spacing: 4) {
                Text("\(percent)%")
                    .font(.system(size: 34, weight: .medium).monospacedDigit())
                Text(caption)
                    .font(Theme.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: diameter, height: diameter)
    }
}
