import SwiftUI
import AppKit

/// 툴바 안의 검색창에 커서를 넣는다.
///
/// **SwiftUI의 `@FocusState`로는 안 된다.** 툴바 내용은 창의 타이틀바 쪽 뷰 계층에
/// 얹히는데, 거기 둔 `@FocusState`는 창의 응답자 사슬에 연결되지 않는다 —
/// 실측에서 ⌘F를 눌러도, 메뉴 항목을 직접 클릭해도 `focused`가 계속 false였다.
///
/// 그래서 창에서 텍스트 필드를 찾아 **직접 첫 응답자로 만든다.** 창에 편집 가능한
/// 텍스트 필드는 검색창 하나뿐이라 첫 번째를 집으면 된다.
enum SearchFocus {

    static func apply() {
        // 메뉴에서 부르면 `keyWindow`가 nil이다 — 메뉴가 열려 있는 동안은
        // 창이 key가 아니다. 실측에서 여기서 조용히 돌아 나가 아무 일도 안 했다.
        let candidate = NSApp.keyWindow ?? NSApp.mainWindow
            ?? NSApp.windows.first { $0.isVisible && $0.canBecomeKey }
        guard let window = candidate,
              let field = firstTextField(in: window.contentView?.superview ?? window.contentView)
        else { return }

        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(field)
    }

    /// 편집 가능한 첫 텍스트 필드. 툴바 제목(`_NSToolbarTitleField`)이나 라벨은
    /// `isEditable`이 false라 저절로 걸러진다.
    private static func firstTextField(in view: NSView?) -> NSTextField? {
        guard let view else { return nil }
        if let field = view as? NSTextField, field.isEditable { return field }
        for child in view.subviews {
            if let found = firstTextField(in: child) { return found }
        }
        return nil
    }
}

/// 목록을 좁히는 검색창.
///
/// **툴바에 하나만 있고, 무엇을 좁히는지는 바인딩이 정한다.** 스캔 화면은
/// `ScanModel.query`를, 디스크 맵은 `DiskMapModel.query`를 준다. 두 벌로 두면
/// 치수도 문구도 언젠가 갈라진다.
struct SearchField: View {
    @Binding var text: String
    var placeholder = "이름·경로로 찾기"

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(Theme.bodyText)
                .focused($isFocused)

            // 지운 뒤에도 커서를 남긴다. 다시 치려고 또 눌러야 하면
            // 지우개가 아니라 장애물이다.
            if !text.isEmpty {
                Button {
                    text = ""
                    isFocused = true
                    SearchFocus.apply()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .frame(width: 260, height: 26)
        .background(Color.white.opacity(0.07),
                    in: RoundedRectangle(cornerRadius: Theme.rowCornerRadius))
    }
}
