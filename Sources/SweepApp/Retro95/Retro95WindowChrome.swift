import AppKit
import SwiftUI

/// 설정 Scene과 스테이지 모두, 실제로 부착된 창에만 적용한다.
struct WindowChromeConfigurator: NSViewRepresentable {
    /// 전체 화면 앱 위에 떠도 되는 보조 창(설정). 아니면 메인 창이 전체 화면일 때
    /// macOS가 이 창을 데스크탑 Space로 보내 앱 밖에서 열린 것처럼 보인다.
    var auxiliary = false

    func makeNSView(context: Context) -> ChromeView {
        let view = ChromeView()
        view.auxiliary = auxiliary
        return view
    }
    func updateNSView(_ nsView: ChromeView, context: Context) { nsView.applyChrome() }

    final class ChromeView: NSView {
        var auxiliary = false

        /// SwiftUI가 다시 그릴 때마다 불린다. Settings 창은 알림 없이 툴바·제목줄 그릇을 다시
        /// 붙여(버튼을 누르거나 열기 창을 닫은 뒤) Win95 제목줄이 사라졌다 — 여기서도 확인한다.
        override func layout() {
            super.layout()
            applyChrome()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            NotificationCenter.default.removeObserver(self)
            guard let window else { return }
            applyChrome()
            for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification,
                         NSWindow.didResizeNotification, NSWindow.didExitFullScreenNotification,
                         NSWindow.didDeminiaturizeNotification, NSWindow.didEnterFullScreenNotification,
                         NSWindow.didChangeScreenNotification] {
                NotificationCenter.default.addObserver(
                    self, selector: #selector(windowChromeChanged(_:)), name: name, object: window)
            }
        }

        /// 값이 다를 때만 바꾼다 — `layout()`에서 매번 불리므로 같은 값을 다시 넣으면 레이아웃이 다시 돈다.
        func applyChrome() {
            guard let window else { return }
            if window.titleVisibility != .hidden { window.titleVisibility = .hidden }
            if !window.titlebarAppearsTransparent { window.titlebarAppearsTransparent = true }
            if auxiliary, !window.collectionBehavior.contains(.fullScreenAuxiliary) {
                window.collectionBehavior.insert([.fullScreenAuxiliary, .moveToActiveSpace])
            }
            if !window.styleMask.contains(.fullSizeContentView) {
                window.styleMask.insert(.fullSizeContentView)
            }
            for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
                if let view = window.standardWindowButton(button), !view.isHidden { view.isHidden = true }
            }
            // 숨긴 제목줄 자리에도 제목줄 그릇(NSTitlebarContainerView)이 남아 그 영역의 클릭을 가로챈다.
            // 감춰야 Win95 제목줄의 [_][□][×]와 끌기가 마우스를 받는다.
            if window.titlebarSeparatorStyle != .none { window.titlebarSeparatorStyle = .none }
            // Settings 창은 SwiftUI가 툴바를 붙여 제목줄 자리를 반투명 회색으로 덮는다.
            if window.toolbar != nil { window.toolbar = nil }
            hideTitlebarContainers(in: window)
        }

        /// 테마 프레임 바로 아래의 제목줄 그릇을 전부 숨긴다. 전체 화면을 나오거나 크기가 바뀌면
        /// AppKit이 새 그릇을 붙이므로, 닫기 버튼 하나의 조상만 숨겨서는 놓친다.
        private func hideTitlebarContainers(in window: NSWindow) {
            guard let frame = window.contentView?.superview else { return }
            for view in frame.subviews
            where !view.isHidden && String(describing: type(of: view)) == "NSTitlebarContainerView" {
                view.isHidden = true
            }
        }

        /// 알림 직후에 한 번, 이번 레이아웃이 끝난 뒤에 한 번 더 숨긴다 — AppKit이 레이아웃 중에
        /// 제목줄 그릇을 다시 붙이면 첫 번째만으로는 회색 띠가 남는다.
        @objc private func windowChromeChanged(_ notification: Notification) {
            applyChrome()
            DispatchQueue.main.async { [weak self] in self?.applyChrome() }
        }
    }
}

/// 제목줄이 속한 창을 사용해 다른 keyWindow를 조작하지 않는다.
private struct TitleBarDragArea: NSViewRepresentable {
    let fullScreenable: Bool
    let didAttach: (NSWindow?) -> Void
    /// 전체 화면에 들어가고 나올 때. 모서리 여백을 바꾸는 데 쓴다.
    let fullScreenChanged: (Bool) -> Void

    func makeNSView(context: Context) -> DragView { DragView() }
    func updateNSView(_ view: DragView, context: Context) {
        view.fullScreenable = fullScreenable
        view.didAttach = didAttach
        view.fullScreenChanged = fullScreenChanged
    }

    final class DragView: NSView {
        var fullScreenable = false
        var didAttach: ((NSWindow?) -> Void)?
        var fullScreenChanged: ((Bool) -> Void)?
        override var mouseDownCanMoveWindow: Bool { true }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            NotificationCenter.default.removeObserver(self)
            if let window {
                for name in [NSWindow.didEnterFullScreenNotification, NSWindow.didExitFullScreenNotification] {
                    NotificationCenter.default.addObserver(
                        self, selector: #selector(fullScreenDidChange), name: name, object: window)
                }
            }
            // SwiftUI 업데이트 중 State를 바꾸지 않는다.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if fullScreenable { window?.collectionBehavior.insert(.fullScreenPrimary) }
                didAttach?(window)
                fullScreenDidChange()
            }
        }
        @objc private func fullScreenDidChange() {
            fullScreenChanged?(window?.styleMask.contains(.fullScreen) ?? false)
        }
        override func mouseDown(with event: NSEvent) {
            if event.clickCount == 2 {
                if fullScreenable { window?.toggleFullScreen(nil) }
            } else {
                window?.performDrag(with: event)
            }
        }
    }
}

struct Retro95WindowTitleBar: View {
    let title: String
    let icon: PixelArt
    /// [□]가 전체 화면(새 Space)으로 들어간다. 크기가 고정된 창(설정)은 false라 흐리게 그린다.
    var fullScreenable = false
    /// [_]. macOS 설정 창처럼 최소화하지 않는 창은 false라 흐리게 그린다.
    var minimizable = true
    @Environment(\.controlActiveState) private var activeState
    @State private var windowReference = WindowReference()
    @State private var isFullScreen = false

    /// 창 모드에서는 macOS 창 모서리가 둥글어 끝에 붙은 아이콘과 [×]가 잘린다. 전체 화면은 각지다.
    private var cornerInset: CGFloat { isFullScreen ? 0 : 8 }

    private var window: NSWindow? { windowReference.window }

    // 창 → hosting view → 제목줄 → 창의 소유 순환을 피한다.
    private final class WindowReference {
        weak var window: NSWindow?
    }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                PixelIcon(art: icon)
                Text(title).font(R95.ui(13, bold: true))
                    .foregroundStyle(R95.white).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.leading, 6 + cornerInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                TitleBarDragArea(fullScreenable: fullScreenable,
                                 didAttach: { windowReference.window = $0 },
                                 fullScreenChanged: { isFullScreen = $0 })
                    .accessibilityHidden(true)
            }
            HStack(spacing: 0) {
                // macOS 신호등과 같은 규칙: 전체 화면에서는 최소화할 수 없고, [□]는 나가는 버튼이 된다.
                caption(.minimize, label: String(localized: "최소화"),
                        enabled: minimizable && !isFullScreen) { window?.miniaturize(nil) }
                caption(isFullScreen ? .restore : .maximize,
                        label: isFullScreen ? String(localized: "전체 화면 끝내기")
                                            : String(localized: "전체 화면"),
                        enabled: fullScreenable) {
                    window?.toggleFullScreen(nil)
                }
                caption(.close, label: String(localized: "닫기")) { window?.performClose(nil) }
                    .padding(.leading, 2)
            }
            .padding(.trailing, 3 + cornerInset)
        }
        .frame(height: R95.titleStripHeight)
        .background(activeState == .key || activeState == .active ? R95.navy : R95.shadow)
    }

    private func caption(_ glyph: CaptionGlyph.Kind, label: String, enabled: Bool = true,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            CaptionGlyph(kind: glyph, enabled: enabled).frame(width: 16, height: 14)
                .frame(width: 20, height: 18)
        }
        .buttonStyle(CaptionButtonStyle())
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}

private struct CaptionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(x: configuration.isPressed ? 1 : 0, y: configuration.isPressed ? 1 : 0)
            .background(R95.gray)
            .retroBevel(configuration.isPressed ? .pressed : .raised)
    }
}

private struct CaptionGlyph: View {
    enum Kind { case minimize, maximize, restore, close }
    let kind: Kind
    let enabled: Bool

    var body: some View {
        Canvas { context, _ in
            var path = Path()
            switch kind {
            case .minimize:
                path.addRect(CGRect(x: 3, y: 10, width: 7, height: 2))
            case .maximize:
                for rect in [CGRect(x: 3, y: 3, width: 10, height: 2),
                             CGRect(x: 3, y: 5, width: 1, height: 7),
                             CGRect(x: 12, y: 5, width: 1, height: 7),
                             CGRect(x: 3, y: 11, width: 10, height: 1)] { path.addRect(rect) }
            case .restore:
                // Win95 "이전 크기로": 뒤 창은 윗변·오른쪽 변만, 앞 창은 굵은 윗변의 온전한 사각형.
                for rect in [CGRect(x: 5, y: 2, width: 8, height: 2),
                             CGRect(x: 12, y: 4, width: 1, height: 5),
                             CGRect(x: 10, y: 8, width: 2, height: 1),
                             CGRect(x: 2, y: 5, width: 8, height: 2),
                             CGRect(x: 2, y: 7, width: 1, height: 5),
                             CGRect(x: 9, y: 7, width: 1, height: 5),
                             CGRect(x: 2, y: 11, width: 8, height: 1),
                             CGRect(x: 5, y: 4, width: 1, height: 1)] { path.addRect(rect) }
            case .close:
                for row in 0..<8 {
                    path.addRect(CGRect(x: 4 + row, y: 3 + row, width: 2, height: 1))
                    path.addRect(CGRect(x: 11 - row, y: 3 + row, width: 2, height: 1))
                }
            }
            if !enabled {
                context.fill(path.offsetBy(dx: 1, dy: 1), with: .color(R95.white))
            }
            context.fill(path, with: .color(enabled ? R95.black : R95.shadow))
        }
        .accessibilityHidden(true)
    }
}

struct Retro95TabView<Content: View>: View {
    @Binding var selection: Int
    let titles: [String]
    @ViewBuilder let content: (Int) -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(titles.indices, id: \.self) { index in
                    Button { selection = index } label: {
                        Text(titles[index]).font(R95.ui(12))
                            .padding(.horizontal, 14)
                            .frame(height: selection == index ? 28 : 26)
                            .background(R95.gray)
                            .retroRaised()
                            .overlay(alignment: .bottom) {
                                if selection == index {
                                    R95.gray.frame(height: 3).padding(.horizontal, 2)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection == index ? .isSelected : [])
                    .zIndex(selection == index ? 1 : 0)
                }
            }
            .padding(.horizontal, 4)
            .zIndex(1)
            content(selection)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(8)
                .background(R95.gray)
                .retroRaised()
                .padding(.top, -2)
        }
    }
}
