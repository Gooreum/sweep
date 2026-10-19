import Foundation

/// 정리 항목을 실제로 지운다.
///
/// 지우기 전 모든 항목이 `ProtectedPaths`를 통과해야 한다. 통과하지 못한 항목은
/// 조용히 건너뛰지 않고 **실패로 기록**한다 — 빠진 것을 사용자가 알아야 한다.
public struct Remover: Sendable {

    /// 기본은 휴지통. 되돌릴 수 있어야 한다.
    public let movesToTrash: Bool

    /// 어느 관문 범위로 검사할지. 기본은 스캐너용 화이트리스트다 —
    /// 디스크 맵만 `.diskMap`을 넘긴다.
    public let scope: RemovalScope

    /// 휴지통. 이 안의 항목은 휴지통으로 옮길 곳이 없어 바로 지운다.
    let trashFolder: URL

    public init(movesToTrash: Bool = true, scope: RemovalScope = .cleanup) {
        self.init(movesToTrash: movesToTrash, scope: scope, trashFolder: ProtectedPaths.trashFolder)
    }

    /// 휴지통 위치를 갈아끼운다 — 테스트가 진짜 휴지통을 비우면 안 된다.
    init(movesToTrash: Bool, scope: RemovalScope, trashFolder: URL) {
        self.movesToTrash = movesToTrash
        self.scope = scope
        self.trashFolder = trashFolder
    }

    public func remove(_ items: [CleanupItem]) -> RemovalReport {
        RemovalReport(outcomes: items.map(removeOne))
    }

    /// 한 항목만 처리한다. UI가 항목 단위 진행률을 그리려면 이 입구가 필요하다.
    ///
    /// 정리 범위로 만든 Remover는 **항목의 분류**가 정하는 범위로 검사한다 —
    /// 큰 파일·중복 파일은 사용자 폴더에 있다(`ScanCategory.removalScope`).
    public func removeOne(_ item: CleanupItem) -> RemovalOutcome {
        let itemScope = scope == .cleanup ? item.category.removalScope : scope
        let (trashed, failure) = perform(at: item.url, scope: itemScope)
        return RemovalOutcome(item: item, failure: failure, trashedURL: trashed)
    }

    /// 경로 하나를 검증하고 지운다. 성공이면 nil, 실패면 사유를 돌려준다.
    ///
    /// `CleanupItem`이 없는 곳(디스크 맵)도 **같은 관문**을 지나야 한다.
    /// 가짜 `CleanupItem`을 만들어 넘기면 `ScanCategory` 여섯 종 중 아무거나
    /// 골라 붙이게 되고 — 어디에도 "디스크 맵에서 고른 임의 폴더"는 없다 —
    /// 목록·요약 통계가 오염된다.
    public func removeFile(at url: URL) -> String? {
        attempt(at: url)?.reason
    }

    /// `removeFile(at:)`과 같은 관문·같은 삭제. 실패하면 문장과 함께 **종류**를 돌려준다 —
    /// 화면이 사유마다 다른 다음 행동을 보여주려면 종류가 필요하다.
    public func attempt(at url: URL) -> RemovalFailure? {
        perform(at: url, scope: scope).failure
    }

    /// 관문 → 삭제. 휴지통으로 옮겼으면 **휴지통 안의 새 위치**도 돌려준다 —
    /// 예전엔 버렸는데, 그러면 앱이 되돌릴 길이 없어 사용자가 Finder 휴지통을 뒤져야 했다.
    private func perform(at url: URL,
                         scope: RemovalScope) -> (trashed: URL?, failure: RemovalFailure?) {
        do {
            // 관문이 먼저다. 예외 없음.
            try ProtectedPaths.validate(url, scope: scope)

            // 휴지통 안의 항목은 휴지통으로 다시 옮길 곳이 없다. 비우는 것만 뜻이 있다 —
            // `trashItem`에 맡기면 휴지통 안에서 이름만 바뀐 채 용량이 그대로 남는다.
            // 되돌릴 위치(`trashed`)가 없으니 되돌리기 목록에서도 자연히 빠진다.
            if movesToTrash, !ProtectedPaths.canonical(url).isDescendant(of: ProtectedPaths.canonical(trashFolder)) {
                var resulting: NSURL?
                try FileManager.default.trashItem(at: url, resultingItemURL: &resulting)
                return (resulting as URL?, nil)
            } else {
                try FileManager.default.removeItem(at: url)
                return (nil, nil)
            }

        } catch let veto as RemovalVeto {
            return (nil, RemovalFailure(reason: veto.message, kind: Self.kind(of: veto)))
        } catch {
            return (nil, RemovalFailure(reason: error.localizedDescription, kind: Self.kind(of: error)))
        }
    }

    /// 실패를 종류로 나눈다.
    ///
    /// 파일 시스템 오류 중에서는 권한 거부만 가려낸다. 전체 디스크 접근으로 풀리는 것이
    /// 이쪽이다. Cocoa 오류가 POSIX 오류를 안에 감싸 오는 경우도 있어 한 겹 더 본다.
    static func kind(of error: Error) -> RemovalFailureKind {
        if let veto = error as? RemovalVeto {
            if case .applicationRunning = veto { return .applicationRunning }
            return .protected
        }
        let ns = error as NSError
        if Self.isPermissionDenied(ns) { return .permissionDenied }
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError,
           Self.isPermissionDenied(underlying) {
            return .permissionDenied
        }
        return .other
    }

    private static func isPermissionDenied(_ error: NSError) -> Bool {
        switch error.domain {
        case NSCocoaErrorDomain:
            return error.code == NSFileWriteNoPermissionError || error.code == NSFileReadNoPermissionError
        case NSPOSIXErrorDomain:
            return error.code == Int(EACCES) || error.code == Int(EPERM)
        default:
            return false
        }
    }
}
