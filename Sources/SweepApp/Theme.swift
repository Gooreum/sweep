import SwiftUI

/// 화면 전체가 공유하는 색·치수·서체.
///
/// 값은 Cleaner One 6.5.3의 nib에서 뽑았다. 눈대중이 아니라 아카이브의
/// `NSRGB`와 frame 문자열이다. 치수와 강조색은 `ATMainWindowController.nib`,
/// 선택 틴트는 `MQWProMainWindowController.nib`에서 나왔다.
enum Theme {

    // MARK: - 색

    /// #0A5FFF. nib의 `0.04081478715 0.3748140335 0.998367548`.
    /// 브랜드 색이라 라이트·다크에서 같게 쓴다.
    static let accent = Color(red: 0.0408, green: 0.3748, blue: 0.9984)

    /// #0956F2. 눌린 상태. nib의 `0.03549256176 0.3348736167 0.9491817951`.
    static let accentPressed = Color(red: 0.0355, green: 0.3349, blue: 0.9492)

    /// #D7E6F6. 선택된 행의 옅은 배경.
    /// 메인 윈도우 nib에는 없고 `MQWProMainWindowController.nib`에 있다.
    static let selectionTint = Color(red: 0.8431, green: 0.9020, blue: 0.9647)

    /// 구분선과 배경은 실측값(#DFDFDF, 흰색)을 그대로 쓰지 않고 시맨틱 색을 쓴다.
    /// Cleaner One은 라이트 전용이지만 Sweep은 다크에서도 읽혀야 한다 —
    /// 고정 회색을 박으면 다크 모드에서 선이 보이지 않거나 배경이 흰 판으로 튄다.
    static let separator = Color(nsColor: .separatorColor)
    static let sidebarBackground = Color(nsColor: .controlBackgroundColor)
    static let contentBackground = Color(nsColor: .textBackgroundColor)

    // MARK: - 치수 (nib frame 실측)

    /// 콘텐츠 `{1160, 680}`.
    static let windowWidth: CGFloat = 1160
    static let windowHeight: CGFloat = 680

    /// 사이드바 `{220, 680}`, 오른쪽 끝 구분선 `{{219, 0}, {1, 680}}`.
    static let sidebarWidth: CGFloat = 220
    /// 선택 배경 `{{1, 1}, {217, 45}}`.
    static let sidebarRowHeight: CGFloat = 45
    /// 내부 콘텐츠 `{{4, 2}, {215, 40}}` — 좌우 4pt 들여쓰기.
    static let sidebarRowInset: CGFloat = 4
    /// 아이콘 `{{20, 9}, {28, 28}}`.
    static let sidebarIconSize: CGFloat = 28
    static let sidebarIconLeading: CGFloat = 20

    static let rowCornerRadius: CGFloat = 6

    /// 메뉴 막대 패널 폭. 퀵 윈도우 콘텐츠 `{400, 602}`의 폭만 따른다 —
    /// 높이는 담을 내용이 달라 고정하지 않는다.
    static let panelWidth: CGFloat = 400
    /// 퀵 윈도우 큰 버튼 `{{10, 45}, {380, 31}}` — 400에서 380을 빼면 좌우 10pt.
    /// 글자 줄에는 조금 넉넉하게 준다.
    static let panelPadding: CGFloat = 14

    // MARK: - 서체 (.AppleSystemUIFont 22 / 13 / 11)

    static let title = Font.system(size: 22)
    static let bodyText = Font.system(size: 13)
    static let caption = Font.system(size: 11)
}

/// 강조색 알약 버튼. 화면마다 주 동작이 하나씩 있고 그것만 이 모양을 쓴다.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.bodyText.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 28)
            .frame(height: 32)
            .background(configuration.isPressed ? Theme.accentPressed : Theme.accent,
                        in: Capsule())
    }
}
