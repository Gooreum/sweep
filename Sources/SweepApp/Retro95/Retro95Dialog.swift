import SwiftUI

/// 시작·확인·실패에 같은 틀을 써서 상태가 바뀌어도 조작 위치를 유지한다.
struct Retro95Dialog<Content: View, Buttons: View>: View {
    let title: String
    let icon: PixelArt
    private let content: Content
    private let buttons: Buttons

    init(title: String, icon: PixelArt,
         @ViewBuilder content: () -> Content, @ViewBuilder buttons: () -> Buttons) {
        self.title = title
        self.icon = icon
        self.content = content()
        self.buttons = buttons()
    }

    var body: some View {
        VStack(spacing: 0) {
            Retro95TitleStrip(title: title, icon: icon)
            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    PixelIcon(art: icon, size: 32)
                    content
                        .font(R95.ui(12))
                        .foregroundStyle(R95.black)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        // 세로로 늘어나게 둔다. 영어 설명은 한국어보다 길어 한 줄에서 잘렸다.
                        .fixedSize(horizontal: false, vertical: true)
                }
                // 버튼이 없는 대화상자에 빈 줄을 남기면 아래 여백만 12pt 넘게 커진다.
                if Buttons.self != EmptyView.self {
                    HStack(spacing: 6) {
                        Spacer(minLength: 0)
                        buttons
                    }
                }
            }
            .padding(12)
        }
        .padding(3)
        .background(R95.gray)
        .retroRaised()
    }
}

extension Retro95Dialog where Buttons == EmptyView {
    /// 안내만 하고 닫을 일이 없는 대화상자.
    init(title: String, icon: PixelArt, @ViewBuilder content: () -> Content) {
        self.init(title: title, icon: icon, content: content, buttons: { EmptyView() })
    }
}
