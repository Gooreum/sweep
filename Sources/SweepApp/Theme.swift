import SwiftUI
import SweepKit

/// 기존 화면도 고정 팔레트를 공유하도록 토큰 이름을 유지한다.
enum Theme {
    static let surface = R95.gray
    static let surfaceSunken = R95.white
    static let surfaceRaised = R95.light
    static let border = R95.shadow
    static let textPrimary = R95.black
    static let textSecondary = R95.deep
    static let textTertiary = R95.shadow
    static let accent = R95.navy
    static let accentPressed = R95.highlightBlue
    static let accentText = R95.navy
    /// 회색 면에서도 주의 문구를 읽을 수 있도록 노랑의 명도를 낮춘다.
    static let cautionText = Color(hex: 0x806000)
    static let dangerText = R95.danger
    static let rowSelected = R95.light
    static func tint(_ feature: Feature) -> Color { R95.navy }
    static func tintFill(_ feature: Feature) -> Color { R95.navy }
    static let usedSlice = R95.navy
    static let freeSlice = R95.light
    static let separator = R95.shadow

    // MARK: - 치수 (8px 그리드: 4/8/12/16/24/32)

    static let windowWidth: CGFloat = 1080
    static let windowHeight: CGFloat = 740
    static let sidebarWidth: CGFloat = R95.sidebarWidth

    /// macOS 사이드바는 포인터 조작이라 iOS의 44pt 터치타겟 규칙이 없다.
    /// Finder·Xcode·Raycast가 모두 28~32 구간이다.
    static let sidebarRowHeight: CGFloat = R95.sidebarRowHeight
    static let sidebarRowInset: CGFloat = 4
    static let sidebarIconSize: CGFloat = 16
    static let sidebarIconLeading: CGFloat = 12

    /// 버튼·행. 카드·패널은 `cardRadius`.
    static let rowCornerRadius: CGFloat = 0
    static let cardRadius: CGFloat = 0

    static let panelWidth: CGFloat = 400
    static let panelPadding: CGFloat = 16

    // MARK: - 검토 목록 (v3)

    /// 우측 선택 독. 하단 액션 바를 대신한다 — 선택 요약·안전도 분포·주 동작이 한곳에.
    static let dockWidth: CGFloat = 252

    /// 목록 행. 기본은 여유롭게, 촘촘하게는 설정으로 고를 수 있다.
    /// 목록 행 높이. 이름 · 설명 · 경로 세 줄이 들어간다.
    ///
    /// 예전에는 56(두 줄)이었다. 경로를 보여주려고 한 줄을 더했고, 그 대가로
    /// 한 화면에 보이는 항목이 13개에서 10개로 줄었다.
    static let rowHeightComfortable: CGFloat = 68
    /// 목록 행의 체크박스 크기. 시스템 체크박스와 비슷하게 보이는 값이다.
    static let checkboxSize: CGFloat = 14
    /// 행 안에서 글자가 차지하는 높이. 13pt + 11pt + 11pt와 줄 간격을 담는다.
    /// 좌우 열에 같은 값을 줘야 이름과 크기가 같은 선에 놓인다.
    static let rowTextBlockHeight: CGFloat = 48
    /// 설명 줄의 높이. 설명이 비어도 이만큼은 남겨 **경로가 셋째 줄에 그대로 있게** 한다.
    static let rowDetailLineHeight: CGFloat = 14
    /// 크기·날짜가 들어가는 우측 열 너비. "2026.05.18 만듦 · 4개월 전 사용"이 들어간다.
    static let rowMetaWidth: CGFloat = 178
    static let rowHeightCompact: CGFloat = 46

    /// 섹션 헤더. 스크롤해도 위에 붙어 있어 지금 어느 묶음인지 잃지 않는다.
    static let sectionHeaderHeight: CGFloat = 34

    /// 안전도 아이콘이 차지하는 칸. 등급마다 도형이 달라도 이름 열이 흔들리지 않게 고정한다.
    static let safetyIconSlot: CGFloat = 11

    /// 아이콘 크기는 폰트 스케일과 분리한다.
    enum Icon {
        static let small: CGFloat = 16
        static let medium: CGFloat = 24
        static let large: CGFloat = 48
    }

    // MARK: - 서체

    static let display = R95.ui(22, bold: true)
    static let title = R95.ui(15, bold: true)
    static let headline = R95.ui(13, bold: true)
    static let bodyText = R95.ui(12)
    static let caption = R95.ui(11)
    static let displayMono = display.monospacedDigit()
    static let headlineMono = headline.monospacedDigit()
    static let bodyMono = R95.mono(12)
    static let captionMono = R95.mono(11)
    static let transition = Animation.easeInOut(duration: 0.15)
}

/// 기본 동작의 강조를 공통 베벨 스타일에 맡겨 상태 표현을 통일한다.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Retro95ButtonStyle(isDefault: true).makeBody(configuration: configuration)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Retro95ButtonStyle().makeBody(configuration: configuration)
    }
}
