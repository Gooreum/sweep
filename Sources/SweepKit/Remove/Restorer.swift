import Foundation

/// 휴지통으로 옮긴 것을 원래 자리로 되돌린다.
///
/// 되돌리기도 파일을 **쓰는** 동작이라 지울 때와 같은 관문을 다시 지난다.
/// 정리한 사이에 원래 부모 폴더가 허용 범위 밖을 가리키는 링크로 바뀌었거나
/// 폴더 허락이 철회됐다면, 그 자리에 다시 쓰면 안 된다.
public struct Restorer: Sendable {

    public init() {}

    /// 결과는 `RemovalOutcome` 모양을 그대로 쓴다 — 실패 시트와 합계(`RemovalReport`)를
    /// 다시 만들 필요가 없다. `succeeded`는 "되돌림 성공"을 뜻하고, 실패면 `trashedURL`을
    /// 남겨 시트의 "Finder에서 보기"가 휴지통 안의 항목을 가리키게 한다.
    public func restoreOne(_ outcome: RemovalOutcome) -> RemovalOutcome {
        let target = outcome.item.url

        func fail(_ reason: String, _ kind: RemovalFailureKind) -> RemovalOutcome {
            RemovalOutcome(item: outcome.item,
                           failure: RemovalFailure(reason: reason, kind: kind),
                           trashedURL: outcome.trashedURL)
        }

        // 확인 순서가 곧 사유의 우선순위다. 하나라도 걸리면 아무것도 옮기지 않는다.
        guard let trashed = outcome.trashedURL, Self.exists(trashed) else {
            return fail(String(localized: "휴지통에서 찾을 수 없습니다"), .missingFromTrash)
        }
        // 덮어쓰지 않는다. 그 사이 새로 생긴 것은 사용자의 것이다.
        if Self.exists(target) {
            return fail(String(localized: "원래 자리에 같은 이름이 있습니다"), .destinationOccupied)
        }
        // 사라진 폴더를 다시 만들지 않는다. 없는 자리를 지어내지 않는다.
        guard Self.exists(target.deletingLastPathComponent()) else {
            return fail(String(localized: "원래 폴더가 사라졌습니다"), .destinationOccupied)
        }

        do {
            // 관문 재통과. 예외 없음.
            try ProtectedPaths.validate(target)
            try FileManager.default.moveItem(at: trashed, to: target)
            return RemovalOutcome(item: outcome.item, failure: nil)
        } catch let veto as RemovalVeto {
            return fail(veto.message, Remover.kind(of: veto))
        } catch {
            return fail(error.localizedDescription, Remover.kind(of: error))
        }
    }

    /// `lstat`으로 본다. 끊긴 심볼릭 링크도 "있음"이다 — `fileExists`는 링크를 따라가
    /// 대상이 없으면 false를 줘서, 그 자리를 덮어쓰게 된다.
    static func exists(_ url: URL) -> Bool {
        var info = stat()
        return lstat(url.path, &info) == 0
    }
}
