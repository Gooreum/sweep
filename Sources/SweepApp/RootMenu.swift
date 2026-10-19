import AppKit

/// 버튼 아래에 띄우는 일회성 NSMenu.
///
/// SwiftUI `Menu`(borderless)는 라벨 글자 위만 눌린다. 디스크 맵 시작 지점 상자는
/// 글자보다 훨씬 넓어서 상자 빈 곳·▼를 눌러도 아무 일이 없었다. 그래서 상자 전체를
/// 버튼으로 두고 메뉴는 AppKit으로 직접 띄운다.
@MainActor
enum RootMenu {
    struct Item {
        let title: String
        let isChecked: Bool
        let action: () -> Void
    }

    struct Section {
        let title: String?
        let items: [Item]
    }

    /// `rect`는 창 콘텐츠 기준 좌표(SwiftUI `.global`, 위가 0). 그 왼쪽 아래에 메뉴를 붙인다.
    static func show(_ sections: [Section], below rect: CGRect) {
        guard let view = NSApp.keyWindow?.contentView else { return }
        let menu = NSMenu()
        menu.autoenablesItems = false
        var targets: [Target] = []
        for (index, section) in sections.enumerated() {
            if index > 0 { menu.addItem(.separator()) }
            if let title = section.title { menu.addItem(.sectionHeader(title: title)) }
            for item in section.items {
                let target = Target(item.action)
                targets.append(target)
                let menuItem = NSMenuItem(title: item.title, action: #selector(Target.fire), keyEquivalent: "")
                menuItem.target = target
                menuItem.state = item.isChecked ? .on : .off
                menu.addItem(menuItem)
            }
        }
        // 콘텐츠 뷰는 보통 아래가 0이다. 위가 0인 SwiftUI 좌표를 뒤집는다.
        let y = view.isFlipped ? rect.maxY : view.bounds.height - rect.maxY
        menu.popUp(positioning: nil, at: NSPoint(x: rect.minX, y: y), in: view)
        // NSMenuItem.target은 약한 참조다. popUp은 메뉴가 닫힐 때까지 돌아오지 않으므로 여기까지 붙잡는다.
        withExtendedLifetime(targets) {}
    }

    private final class Target: NSObject {
        let action: () -> Void
        init(_ action: @escaping () -> Void) { self.action = action }
        @objc func fire() { action() }
    }
}
