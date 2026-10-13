import AppKit
import Foundation

/// 항목 하나를 앱 **밖에서** 다루는 동작. Finder에서 보기 · 경로 복사.
///
/// 지우는 것과 달리 되돌릴 것이 없어 관문(`ProtectedPaths`)을 지나지 않는다.
/// 보호된 경로라도 열어 보는 것은 막을 이유가 없다 — 오히려 "이게 뭐길래 못 지우지"를
/// 확인하는 유일한 길이다.
///
/// 실제 동작은 Finder·붙임판과 붙어 있어 테스트에서 부를 수 없다. 그래서 **무엇을
/// 넘겼는지**를 검사할 수 있게 함수 자체를 바꿔 끼울 수 있게 뒀다 —
/// `ProtectedPaths.runningApplicationURLs`와 같은 방식이다.
public enum ItemActions {

    nonisolated(unsafe) public static var revealInFinder: @Sendable ([URL]) -> Void = {
        NSWorkspace.shared.activateFileViewerSelecting($0)
    }

    nonisolated(unsafe) public static var writeToPasteboard: @Sendable (String) -> Void = {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString($0, forType: .string)
    }

    /// Finder를 열어 이 항목을 고른 상태로 보여준다.
    ///
    /// 경로가 실제로 있는지 우리가 먼저 보지 않는다. 그 판단은 Finder가 하고,
    /// 스캔 직후 사라진 항목을 우리가 조용히 삼키면 아무 일도 안 일어난 것처럼 보인다.
    public static func reveal(_ url: URL) { revealInFinder([url]) }

    /// 폴더를 Finder 창으로 연다. 열었으면 true — 샌드박스가 막으면 false가 오고,
    /// 그때 화면은 조용히 넘어가지 않고 대신 할 일을 알려야 한다.
    nonisolated(unsafe) public static var openFolder: @Sendable (URL) -> Bool = {
        NSWorkspace.shared.open($0)
    }

    /// 사용자의 휴지통. 샌드박스에서 `homeDirectoryForCurrentUser`는 컨테이너를 가리켜
    /// 엉뚱한 곳을 열게 된다 — 실제 홈을 쓴다.
    public static var trashURL: URL {
        Sandbox.userHome.appending(path: ".Trash", directoryHint: .isDirectory)
    }

    /// Finder에서 휴지통을 연다. **비우지는 않는다** — 영구 삭제는 사용자가 직접 한다.
    @discardableResult
    public static func openTrash() -> Bool { openFolder(trashURL) }

    /// 경로를 붙임판에 넣는다. 사람이 터미널에 붙여 넣을 값이므로
    /// 퍼센트 인코딩이 아니라 파일 시스템 경로 원문을 준다.
    public static func copyPath(_ url: URL) { writeToPasteboard(url.path) }
}
