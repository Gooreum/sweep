import SwiftUI

/// 고정 팔레트를 공유해 모드와 화면에 따라 레트로 색이 달라지지 않게 한다.
enum R95 {
    static let gray = Color(hex: 0xC0C0C0)
    static let light = Color(hex: 0xDFDFDF)
    static let white = Color(hex: 0xFFFFFF)
    static let shadow = Color(hex: 0x808080)
    static let deep = Color(hex: 0x404040)
    static let black = Color(hex: 0x000000)
    static let navy = Color(hex: 0x000080)
    static let highlightBlue = Color(hex: 0x0000AA)
    static let teal = Color(hex: 0x008080)
    static let review = Color(hex: 0xFFFF00)
    static let danger = Color(hex: 0x800000)
    static let safe = Color(hex: 0x008000)

    static func ui(_ size: CGFloat = 12, bold: Bool = false) -> Font {
        .custom("Geneva", size: size).weight(bold ? .bold : .regular)
    }

    static func mono(_ size: CGFloat = 12) -> Font {
        .custom("Monaco", size: size).monospacedDigit()
    }

    static let sidebarWidth: CGFloat = 172
    static let sidebarRowHeight: CGFloat = 36
    static let tableRowHeight: CGFloat = 40
    static let tableHeaderHeight: CGFloat = 24
    static let titleStripHeight: CGFloat = 24
    static let statusBarHeight: CGFloat = 22
    static let buttonHeight: CGFloat = 24
    static let checkboxSize: CGFloat = 13
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: 1)
    }
}
