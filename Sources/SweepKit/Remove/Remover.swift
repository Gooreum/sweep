import Foundation

/// 정리 항목을 실제로 지운다.
///
/// 지우기 전 모든 항목이 `ProtectedPaths`를 통과해야 한다. 통과하지 못한 항목은
/// 조용히 건너뛰지 않고 **실패로 기록**한다 — 빠진 것을 사용자가 알아야 한다.
public struct Remover: Sendable {

    /// 기본은 휴지통. 되돌릴 수 있어야 한다.
    public let movesToTrash: Bool

    public init(movesToTrash: Bool = true) { self.movesToTrash = movesToTrash }

    public func remove(_ items: [CleanupItem]) -> RemovalReport {
        RemovalReport(outcomes: items.map(removeOne))
    }

    /// 한 항목만 처리한다. UI가 항목 단위 진행률을 그리려면 이 입구가 필요하다.
    public func removeOne(_ item: CleanupItem) -> RemovalOutcome {
        do {
            // 관문이 먼저다. 예외 없음.
            try ProtectedPaths.validate(item.url)

            if movesToTrash {
                try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
            } else {
                try FileManager.default.removeItem(at: item.url)
            }
            return RemovalOutcome(item: item, failureReason: nil)

        } catch let veto as RemovalVeto {
            return RemovalOutcome(item: item, failureReason: veto.message)
        } catch {
            return RemovalOutcome(item: item, failureReason: error.localizedDescription)
        }
    }
}
