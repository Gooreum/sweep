import SwiftUI
import SweepKit

/// 메뉴 막대에 올릴 Sweep의 명령들.
///
/// 아무것도 주지 않으면 SwiftUI가 표준 메뉴만 붙인다 —
/// 텍스트 편집기든 디스크 정리 앱이든 똑같이.
struct SweepCommands: Commands {
    @Bindable var app: AppModel

    var body: some Commands {
        // 이 앱에는 입력란이 하나도 없다. Undo/Cut/Copy/Paste와
        // Writing Tools·받아쓰기가 전부 눌러도 아무 일이 없는 항목이다.
        //
        // 특히 **파일을 지우는 앱의 Edit 메뉴에 죽은 "Delete"가 있는 것**은
        // 헷갈리는 정도가 아니라 위험하다.
        CommandGroup(replacing: .undoRedo) {}
        CommandGroup(replacing: .pasteboard) {}
        CommandGroup(replacing: .textEditing) {}

        // 창을 하나만 만드므로 남겨둘 이유가 없다
        CommandGroup(replacing: .newItem) {}

        // 도움말이 없는데 "Sweep Help"만 있으면 눌렀을 때 아무 일도 안 난다.
        //
        // 이것만으로는 **항목만 지워지고 빈 Help 메뉴가 남는다** — 열면
        // 아무것도 없는 메뉴가 더 나쁘다. 메뉴 자체는 AppKit이 만들므로
        // `MenuTrimmer`가 기동 후에 떼어낸다.
        CommandGroup(replacing: .help) {}

        // 사이드바를 마우스로만 옮길 수 있으면 키보드 사용자는 갇힌다.
        // 항목을 손으로 나열하지 않는다 — 기능이 늘면 메뉴도 따라온다.
        CommandMenu("기능") {
            ForEach(Array(Feature.allCases.enumerated()), id: \.element) { index, feature in
                Button(feature.displayName) { app.selected = feature }
                    .keyboardShortcut(
                        KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
            }
        }

        CommandMenu("검색") {
            // 43초짜리 스캔을 돌리는 앱인데 ⌘R이 없었다
            Button("검색") {
                guard let model = app.currentModel else { return }
                Task { await model.scan() }
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(!app.canScan)

            // 되돌릴 수 없는 동작이라 ⌘⌫ — 하단 바 버튼과 같은 무게로 둔다
            Button("정리") {
                guard let model = app.currentModel else { return }
                Task { await model.removeSelected() }
            }
            .keyboardShortcut(.delete, modifiers: .command)
            .disabled(!app.canClean)

            Divider()

            // 고를 것이 없으면 프리셋도 뜻이 없다
            ForEach(ScanModel.SelectionPreset.allCases, id: \.self) { preset in
                Button(preset.rawValue) { app.currentModel?.apply(preset) }
                    .disabled(app.currentModel?.items.isEmpty ?? true)
            }
        }
    }
}

/// AppKit이 자동으로 붙이는 메뉴 중 이 앱에 뜻이 없는 것을 떼어낸다.
///
/// SwiftUI의 `CommandGroup(replacing:)`은 메뉴 **안의 항목**만 다룬다.
/// Help 메뉴처럼 AppKit이 직접 만드는 것은 기동 후에 손대야 한다.
final class MenuTrimmer: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let main = NSApp.mainMenu else { return }
        // 제목으로 찾지 않는다 — 시스템 언어에 따라 "Help"가 "도움말"이 된다.
        if let help = NSApp.helpMenu ?? main.items.first(where: {
            $0.submenu?.items.isEmpty == true && $0.submenu != NSApp.windowsMenu
        })?.submenu {
            main.items.removeAll { $0.submenu === help }
        }
    }
}
