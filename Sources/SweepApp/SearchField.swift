import SwiftUI

/// 목록을 좁히는 검색창.
///
/// **툴바에 하나만 있고, 무엇을 좁히는지는 바인딩이 정한다.** 스캔 화면은
/// `ScanModel.query`를, 디스크 맵은 `DiskMapModel.query`를 준다. 두 벌로 두면
/// 치수도 문구도 언젠가 갈라진다.
struct SearchField: View {
    @Binding var text: String
    var placeholder = "이름·경로로 찾기"

    /// ⌘F가 여기로 들어온다. 필드를 마우스로 정확히 눌러야만 칠 수 있었다.
    ///
    /// **숫자인 이유**는 두 번째 ⌘F도 먹어야 하기 때문이다 — Bool이면 이미 true일 때
    /// 값이 안 바뀌어 `onChange`가 돌지 않는다.
    let focusRequest: Int

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

            // 지운 뒤에도 커서를 남긴다. 다시 치려고 또 눌러야 하면 지우개가 아니라 장애물이다.
            if !text.isEmpty {
                Button {
                    text = ""
                    isFocused = true
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
        .onChange(of: focusRequest) { isFocused = true }
    }
}
