import SwiftUI
import AppKit
import SweepKit

/// 화면 전체가 공유하는 색·치수·서체.
///
/// 표면 색은 **다크·라이트 두 값을 모두** 들고 있다. 반투명 색을 배경 위에
/// 합성하면 모드에 따라 전혀 다른 색이 나온다 — 실측에서 밝은 파랑
/// `#D7E6F6`을 55%로 깔았더니 다크에서 `#878E97` 탁한 회색이 됐고,
/// 그 위 글자가 1.54~2.85:1로 WCAG AA에 한참 못 미쳤다.
enum Theme {

    /// 모드에 따라 값이 바뀌는 색. 합성이 아니라 **불투명 값**을 각각 고른다.
    private static func adaptive(dark: UInt32, light: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: Double((hex >> 16) & 0xFF) / 255,
                           green: Double((hex >> 8) & 0xFF) / 255,
                           blue: Double(hex & 0xFF) / 255,
                           alpha: 1)
        })
    }

    // MARK: - 표면

    /// 본문 배경.
    static let surface = adaptive(dark: 0x2A2C2E, light: 0xFFFFFF)
    /// 사이드바·패널처럼 한 단 들어간 면.
    static let surfaceSunken = adaptive(dark: 0x141414, light: 0xF2F2F4)
    /// 선택된 행·카드처럼 한 단 올라온 면.
    ///
    /// 예전 `selectionTint`(반투명 하늘색)를 대체한다. 불투명이라 배경과
    /// 합성되지 않는다.
    ///
    /// 세 면의 간격을 벌렸다 — 처음엔 사이드바 `#1A1A1A`와 본문 `#222424`가
    /// 차이 8이라 육안으로 구분이 안 됐고, 화면이 통째로 평평해 보였다.
    static let surfaceRaised = adaptive(dark: 0x34363A, light: 0xE8E8EA)
    static let border = adaptive(dark: 0x43454A, light: 0xD8D8DC)

    // MARK: - 텍스트

    static let textPrimary = adaptive(dark: 0xEDEEEF, light: 0x1D1D1F)

    /// 보조 텍스트는 **시스템 값을 그대로 쓴다.**
    /// 실측에서 다크 배경 위 5.67:1로 AA를 통과했다 — 통과하는 것을 건드리지 않는다.
    static let textSecondary = Color.secondary

    /// 시스템 `.tertiary`는 다크에서 2.25:1로 미달이었다. 자체 값으로 올린다.
    static let textTertiary = adaptive(dark: 0x8A8C8E, light: 0x6E6E73)

    // MARK: - 강조

    /// #0A5FFF. 흰 글씨와 5.23:1 (실측). 값은 두되 **쓰는 면적을 줄인다** —
    /// 버튼·진행 표시·선택 인디케이터에만.
    static let accent = Color(red: 0.0408, green: 0.3748, blue: 0.9984)
    static let accentPressed = Color(red: 0.0355, green: 0.3349, blue: 0.9492)

    /// **글씨·아이콘용 강조색.** 채움용(`accent`)과 다른 값이다.
    ///
    /// `#0A5FFF`는 흰 글씨를 얹을 때는 5.23:1로 통과하지만, 그 색으로
    /// **글씨를 쓰면** 어두운 표면 위에서 2.60:1로 무너진다 (실측).
    /// 같은 강조색이라도 배경으로 쓸 때와 전경으로 쓸 때 필요한 명도가 반대다.
    static let accentText = adaptive(dark: 0x6AA9FF, light: 0x0B52D9)

    /// 기능 고유 색. 값과 대비 검증은 `Feature.tintHex`(SweepKit)에 있다.
    /// 스마트 스캔처럼 고유색이 없는 기능은 강조 글씨색으로 떨어진다.
    static func tint(_ feature: Feature) -> Color {
        guard let hex = feature.tintHex else { return accentText }
        return adaptive(dark: hex.dark, light: hex.light)
    }

    /// 도넛의 중립 조각. 회색 두 개로 끝나면 히어로 요소가 죽는다 —
    /// 사용됨은 톤이 있는 청회색, 사용 가능은 한 단 낮은 면으로 둔다.
    static let usedSlice = adaptive(dark: 0x4A5563, light: 0xB6BEC9)
    static let freeSlice = adaptive(dark: 0x2F3339, light: 0xE2E4E8)

    /// 창 테두리와 톤이 맞아야 해서 시맨틱을 쓴다.
    static let separator = Color(nsColor: .separatorColor)

    // MARK: - 치수 (8px 그리드: 4/8/12/16/24/32)

    static let windowWidth: CGFloat = 1160
    static let windowHeight: CGFloat = 680
    static let sidebarWidth: CGFloat = 220

    /// macOS 사이드바는 포인터 조작이라 iOS의 44pt 터치타겟 규칙이 없다.
    /// Finder·Xcode·Raycast가 모두 28~32 구간이다.
    static let sidebarRowHeight: CGFloat = 32
    static let sidebarRowInset: CGFloat = 4
    static let sidebarIconSize: CGFloat = 16
    static let sidebarIconLeading: CGFloat = 12

    /// 버튼·행. 카드·패널은 `cardRadius`.
    static let rowCornerRadius: CGFloat = 6
    static let cardRadius: CGFloat = 10

    static let panelWidth: CGFloat = 400
    static let panelPadding: CGFloat = 16

    /// 아이콘 크기는 폰트 스케일과 분리한다.
    enum Icon {
        static let small: CGFloat = 16
        static let medium: CGFloat = 24
        static let large: CGFloat = 48
    }

    // MARK: - 서체 (6단계, weight 2종)

    static let display = Font.system(size: 32, weight: .medium)
    static let title = Font.system(size: 20)
    static let headline = Font.system(size: 16, weight: .medium)
    static let bodyText = Font.system(size: 13)
    static let caption = Font.system(size: 11)

    /// 숫자는 자릿수가 흔들리면 안 된다.
    static let displayMono = display.monospacedDigit()
    static let headlineMono = headline.monospacedDigit()
    static let bodyMono = bodyText.monospacedDigit()
    static let captionMono = caption.monospacedDigit()

    /// 표준 150~300ms.
    static let transition = Animation.easeInOut(duration: 0.15)
}

/// 화면의 주 동작 하나에만 쓴다.
///
/// 5개 상태를 모두 그린다. `.disabled()`는 `\.isEnabled` 환경값만 바꾸므로
/// 커스텀 스타일이 읽지 않으면 **누를 수 없는 버튼이 누를 수 있어 보인다.**
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.bodyText.weight(.medium))
            .foregroundStyle(isEnabled ? Color.white : Theme.textTertiary)
            .padding(.horizontal, 16)
            .frame(height: 28)
            .background(fill(configuration),
                        in: RoundedRectangle(cornerRadius: Theme.rowCornerRadius))
            .scaleEffect(configuration.isPressed && isEnabled ? 0.98 : 1)
            .animation(Theme.transition, value: configuration.isPressed)
            .animation(Theme.transition, value: isHovering)
            .onHover { isHovering = $0 }
    }

    private func fill(_ configuration: Configuration) -> Color {
        guard isEnabled else { return Theme.surfaceRaised }
        return configuration.isPressed || isHovering ? Theme.accentPressed : Theme.accent
    }
}

/// 보조 동작. 주 동작과 같은 치수를 쓰되 면을 채우지 않는다.
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.bodyText)
            .foregroundStyle(isEnabled ? Theme.textPrimary : Theme.textTertiary)
            .padding(.horizontal, 16)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: Theme.rowCornerRadius)
                    .fill(configuration.isPressed || isHovering
                          ? Theme.surfaceRaised : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.rowCornerRadius)
                    .strokeBorder(Theme.border, lineWidth: 1)
            )
            .animation(Theme.transition, value: configuration.isPressed)
            .animation(Theme.transition, value: isHovering)
            .onHover { isHovering = $0 }
    }
}
