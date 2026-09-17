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

    /// 경로를 붙임판에 넣는다. 사람이 터미널에 붙여 넣을 값이므로
    /// 퍼센트 인코딩이 아니라 파일 시스템 경로 원문을 준다.
    public static func copyPath(_ url: URL) { writeToPasteboard(url.path) }
}
