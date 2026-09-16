import AppKit
import SweepKit

/// 폴더 허락을 받는 열기 대화상자.
///
/// 허락 화면(`FolderAccessView`)과 "보는 곳" 카드가 함께 쓴다. 두 벌로 두면
/// 한쪽 문구만 고쳐져 같은 동작이 화면마다 달라진다.
enum FolderPicker {

    /// 고른 폴더를 돌려준다. 취소하면 nil.
    static func ask(for grantable: FolderAccess.Grantable) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        // 그 폴더 안에서 연다. 사용자는 아무것도 고르지 않고 "허용"만 누르면 된다.
        // `~/Library`처럼 Finder에서 숨겨진 곳도 이렇게 지정하면 그대로 열린다.
        panel.directoryURL = grantable.folder
        panel.prompt = "허용"
        panel.message = "Sweep이 \(grantable.purpose)을(를) 찾을 수 있게 "
            + "\(grantable.label) 폴더를 허용하세요."

        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
}
