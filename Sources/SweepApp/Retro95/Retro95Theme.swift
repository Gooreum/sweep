import SwiftUI
import SweepKit

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

    static let dialogWidth: CGFloat = 460

    /// 184. 172에서는 "스마트 스캔" 옆에 "52.88 GB" 배지가 붙으면 이름이 잘렸다.
    static let sidebarWidth: CGFloat = 184
    static let sidebarRowHeight: CGFloat = 36
    static let tableRowHeight: CGFloat = 40
    /// 한 줄짜리 상세 보기 행. 두 줄(이름+경로)이 없는 표는 이 높이로 촘촘하게 둔다.
    static let compactRowHeight: CGFloat = 26
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

/// 행과 헤더가 같은 폭을 사용해야 크기·안전도를 세로로 비교할 수 있다.
enum ItemTableColumns {
    static let check: CGFloat = 28
    static let icon: CGFloat = 24
    static let padding: CGFloat = 6
    static let sectionHeight: CGFloat = 26
    static let actionHeight: CGFloat = 76
    static let actionButtonWidth: CGFloat = 220
    static let actionButtonHeight: CGFloat = 44

    /// 날짜가 하나도 없는 결과에서 빈 날짜 열을 두면 그 폭만큼 위험 설명이 잘린다.
    static func visible(showsDates: Bool) -> [ItemColumnLayout.Column] {
        showsDates ? [.detail, .dates, .size, .safety] : [.detail, .size, .safety]
    }

    /// 폭은 `layout`에서 받는다. 경계를 끌면 `onDrag`가 어느 열의 왼쪽 경계인지와 거리를 받는다.
    /// 칸을 누르면 `onSort`가 그 열의 정렬 키를 받는다. 지금 정렬 열에는 ▲/▼가 붙는다.
    static func headers(layout: ItemColumnLayout, showsDates: Bool,
                        sort: ItemSort,
                        onSort: @escaping @MainActor (ItemSort.Key) -> Void,
                        onDrag: @escaping @MainActor (ItemColumnLayout.Column, CGFloat) -> Void)
        -> [Retro95TableHeader.Column] {
        func width(_ column: ItemColumnLayout.Column) -> CGFloat { CGFloat(layout.width(column)) }
        func arrow(_ key: ItemSort.Key) -> Bool? { sort.key == key ? sort.ascending : nil }
        return [.init(title: "", width: check),
                .init(title: "", width: icon),
                .init(title: String(localized: "이름"),
                      onSort: { onSort(.name) }, sortAscending: arrow(.name)),
                .init(title: String(localized: "설명"), width: width(.detail),
                      onResizeLeadingEdge: { onDrag(.detail, $0) },
                      onSort: { onSort(.detail) }, sortAscending: arrow(.detail))]
        + (showsDates ? [.init(title: String(localized: "날짜"), width: width(.dates),
                               onResizeLeadingEdge: { onDrag(.dates, $0) },
                               onSort: { onSort(.dates) }, sortAscending: arrow(.dates))] : [])
        + [.init(title: String(localized: "크기"), width: width(.size), alignment: .trailing,
                 onResizeLeadingEdge: { onDrag(.size, $0) },
                 onSort: { onSort(.size) }, sortAscending: arrow(.size)),
           .init(title: String(localized: "안전도"), width: width(.safety), alignment: .center,
                 onResizeLeadingEdge: { onDrag(.safety, $0) },
                 onSort: { onSort(.safety) }, sortAscending: arrow(.safety))]
    }
}

/// 스마트 요약의 헤더와 행이 같은 열 폭과 팔레트를 쓴다.
enum SmartSummaryColumns {
    static let count: CGFloat = 64
    static let size: CGFloat = 96
    static let bar: CGFloat = 120
    static let headers: [Retro95TableHeader.Column] = [
        .init(title: String(localized: "column.feature", defaultValue: "기능")),
        .init(title: String(localized: "항목"), width: count, alignment: .trailing),
        .init(title: String(localized: "크기"), width: size, alignment: .trailing),
        .init(title: String(localized: "비율 막대"), width: bar)
    ]
}

extension R95 {
    static let olive = Color(hex: 0x808000)
    static let purple = Color(hex: 0x800080)

    static func reclaimColor(_ feature: Feature) -> Color {
        switch feature {
        case .smartScan: navy
        case .junk: teal
        case .largeFile: olive
        case .duplicate: purple
        case .diskMap: navy
        }
    }
}

/// 작은 창에서도 동작 열을 유지하도록 비율 막대 열이 남은 폭을 채운다.
enum DiskMapColumns {
    static let name: CGFloat = 180
    static let size: CGFloat = 90
    static let location: CGFloat = 168
    static let status: CGFloat = 92
    // 영어 "Open…"이 60pt에서 두 줄로 꺾였다.
    static let open: CGFloat = 72
    static let iconButton: CGFloat = 40
    static let disclosure: CGFloat = 16
    static let actionSpacing: CGFloat = 4
    static let actions = status + open + iconButton * 3 + disclosure + actionSpacing * 5
    static let headers: [Retro95TableHeader.Column] = [
        .init(title: String(localized: "이름"), width: name),
        .init(title: String(localized: "크기"), width: size, alignment: .trailing),
        .init(title: String(localized: "비율 막대")),
        .init(title: String(localized: "상태/동작"), width: actions)
    ]
}
