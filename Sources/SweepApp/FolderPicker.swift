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
        panel.prompt = String(localized: "허용")
        panel.message = String(localized: "\(grantable.label) 폴더에서 \(grantable.purpose)을 찾아볼게요. 이 폴더를 선택하고 허용을 눌러 주세요.")

        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    /// 스마트 스캔에 더할 폴더를 아무 곳에서나 고른다. 취소하면 nil.
    ///
    /// `ask(for:)`와 달리 정해진 폴더가 없다. 홈 아래는 이미 다 보므로
    /// 홈 밖(외장 디스크)이 흔한 답이라 `/Volumes`에서 연다.
    static func askAnyFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(filePath: "/Volumes")
        panel.prompt = String(localized: "추가")
        panel.message = String(localized: "어디에서 더 찾아볼까요? 큰 파일과 중복 파일이 있을 만한 폴더를 선택해 주세요.")

        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    /// 개발 프로젝트를 모아 둔 폴더를 고른다. 취소하면 nil. 코드는 대개 홈 아래라 홈에서 연다.
    static func askProjectFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = Sandbox.userHome
        panel.prompt = String(localized: "추가")
        panel.message = String(localized: "프로젝트를 어디에 보관하나요? ~/Code처럼 프로젝트가 모인 폴더를 골라 주세요.")

        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
}
