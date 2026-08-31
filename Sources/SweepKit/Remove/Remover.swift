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
        RemovalOutcome(item: item, failureReason: removeFile(at: item.url))
    }

    /// 경로 하나를 검증하고 지운다. 성공이면 nil, 실패면 사유를 돌려준다.
    ///
    /// `CleanupItem`이 없는 곳(디스크 맵)도 **같은 관문**을 지나야 한다.
    /// 가짜 `CleanupItem`을 만들어 넘기면 `ScanCategory` 여섯 종 중 아무거나
    /// 골라 붙이게 되고 — 어디에도 "디스크 맵에서 고른 임의 폴더"는 없다 —
    /// 목록·요약 통계가 오염된다.
    public func removeFile(at url: URL) -> String? {
        do {
            // 관문이 먼저다. 예외 없음.
            try ProtectedPaths.validate(url)

            if movesToTrash {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            } else {
                try FileManager.default.removeItem(at: url)
            }
            return nil

        } catch let veto as RemovalVeto {
            return veto.message
        } catch {
            return error.localizedDescription
        }
    }
}
