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
                }
                HStack(spacing: 6) {
                    Spacer(minLength: 0)
                    buttons
                }
            }
            .padding(12)
        }
        .padding(3)
        .background(R95.gray)
        .retroRaised()
    }
}
