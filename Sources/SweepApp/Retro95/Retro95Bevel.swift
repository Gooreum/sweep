import SwiftUI

/// 선 대신 픽셀에 맞춘 면을 그려 레티나에서도 베벨 가장자리가 흐려지지 않게 한다.
struct BevelBorder: ViewModifier {
    enum Style { case raised, sunken, pressed, field, groove }
    let style: Style
    @Environment(\.displayScale) private var displayScale

    func body(content: Content) -> some View {
        content.overlay {
            Canvas { context, size in
                let pixel = 1 / displayScale
                let width = floor(size.width * displayScale) / displayScale
                let height = floor(size.height * displayScale) / displayScale
                func edge(_ inset: CGFloat, _ top: Color, _ bottom: Color) {
                    let w = max(0, width - 2 * inset)
                    let h = max(0, height - 2 * inset)
                    let rects: [(CGRect, Color)] = [
                        (CGRect(x: inset, y: inset, width: w, height: pixel), top),
                        (CGRect(x: inset, y: inset, width: pixel, height: h), top),
                        (CGRect(x: inset, y: height - inset - pixel, width: w, height: pixel), bottom),
                        (CGRect(x: width - inset - pixel, y: inset, width: pixel, height: h), bottom),
                    ]
                    for (rect, color) in rects {
                        context.fill(Path(rect), with: .color(color))
                    }
                }
                switch style {
                case .raised:
                    edge(0, R95.white, R95.deep)
                    edge(pixel, R95.light, R95.shadow)
                case .sunken, .pressed:
                    edge(0, R95.shadow, R95.white)
                    edge(pixel, R95.deep, R95.light)
                case .field:
                    edge(0, R95.shadow, R95.white)
                case .groove:
                    edge(0, R95.shadow, R95.white)
                    edge(pixel, R95.white, R95.shadow)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

extension View {
    func retroBevel(_ style: BevelBorder.Style) -> some View { modifier(BevelBorder(style: style)) }
    func retroRaised() -> some View { retroBevel(.raised) }
    func retroSunken() -> some View { retroBevel(.sunken) }
}
