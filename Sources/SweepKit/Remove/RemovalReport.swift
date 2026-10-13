import Foundation

/// 실패 사유의 종류. 화면이 "다음에 무엇을 하면 되는지"를 고르는 기준이다.
///
/// 문장만 남기면 종류가 사라져, 화면이 문자열을 뒤져 조치를 고르게 된다.
public enum RemovalFailureKind: Sendable, Hashable {
    /// 실행 중인 앱. 끄고 다시 시도하면 된다.
    case applicationRunning
    /// 권한 거부. 전체 디스크 접근을 켜면 풀리는 경우가 많다.
    case permissionDenied
    /// 관문(`ProtectedPaths`)이 막았다. 다시 시도해도 같다.
    case protected
    /// 되돌리려는데 원래 자리가 이미 차 있거나 원래 폴더가 사라졌다.
    case destinationOccupied
    /// 되돌리려는데 휴지통에 없다. 비웠거나 누가 옮겼다.
    case missingFromTrash
    case other

    /// 사유 아래에 붙일 다음 행동. 할 말이 없으면 nil — 빈 줄을 만들지 않는다.
    ///
    /// 앱을 대신 끄지 않는다. App Store 빌드에서는 남의 프로세스를 끝낼 수 없다(README CPU 절).
    public var advice: String? {
        switch self {
        case .applicationRunning: String(localized: "앱을 종료한 뒤 다시 시도하세요")
        case .permissionDenied: String(localized: "전체 디스크 접근을 켜면 옮길 수 있습니다")
        case .protected: String(localized: "보호된 항목이라 이 앱으로는 지울 수 없습니다")
        case .destinationOccupied: String(localized: "원래 자리의 항목을 치운 뒤 Finder 휴지통에서 되돌려 놓으세요")
        case .missingFromTrash: String(localized: "휴지통을 비웠거나 이미 옮겨져 되돌릴 수 없습니다")
        case .other: nil
        }
    }
}

/// 실패 하나. 사용자에게 보여줄 문장과 그 종류를 같이 든다.
///
/// `Error`를 담지 않는 이유는 `Error`가 `Sendable`이 아니어서
/// `@MainActor` 뷰 모델로 넘길 수 없기 때문이다.
public struct RemovalFailure: Sendable, Hashable {
    public let reason: String
    public let kind: RemovalFailureKind

    public init(reason: String, kind: RemovalFailureKind) {
        self.reason = reason
        self.kind = kind
    }
}

/// 삭제 시도 하나의 결과.
public struct RemovalOutcome: Sendable, Hashable {
    public let item: CleanupItem

    /// nil이면 성공.
    public let failure: RemovalFailure?

    /// 실패면 사용자에게 그대로 보여줄 수 있는 문장이다.
    public var failureReason: String? { failure?.reason }

    public var succeeded: Bool { failure == nil }

    /// 휴지통 안의 새 위치. 휴지통으로 옮긴 성공 항목에만 있다 — 되돌리기가 여기서 꺼낸다.
    /// **메모리에만 둔다.** 기록(`CleanupRecord`)에는 경로를 남기지 않는다.
    public let trashedURL: URL?

    public init(item: CleanupItem, failure: RemovalFailure?, trashedURL: URL? = nil) {
        self.item = item
        self.failure = failure
        self.trashedURL = trashedURL
    }

    /// 종류를 모르는 호출부(테스트·하니스)용. 종류는 `.other`로 둔다.
    public init(item: CleanupItem, failureReason: String?, trashedURL: URL? = nil) {
        self.init(item: item,
                  failure: failureReason.map { RemovalFailure(reason: $0, kind: .other) },
                  trashedURL: trashedURL)
    }
}

/// 삭제 한 회차 전체의 결과.
public struct RemovalReport: Sendable, Hashable {
    public let outcomes: [RemovalOutcome]

    public init(outcomes: [RemovalOutcome]) { self.outcomes = outcomes }

    public var succeeded: [RemovalOutcome] { outcomes.filter(\.succeeded) }
    public var failed: [RemovalOutcome] { outcomes.filter { !$0.succeeded } }

    /// 앱 안에서 되돌릴 수 있는 것. 휴지통 위치를 아는 성공분뿐이다.
    public var restorable: [RemovalOutcome] { succeeded.filter { $0.trashedURL != nil } }

    /// 실제로 회수된 바이트. 실패한 항목은 세지 않는다 —
    /// 실패 용량까지 합치면 "50GB 확보"라고 표시해 놓고 아무것도 안 지워질 수 있다.
    public var reclaimedBytes: Int64 { succeeded.reduce(0) { $0 + $1.item.size } }

    public var formattedReclaimed: String {
        ByteCountFormatter.string(fromByteCount: reclaimedBytes, countStyle: .file)
    }

    /// 정리 직후 한 줄. 휴지통으로 **옮겼을 뿐** 공간은 비워야 생긴다 —
    /// 이걸 말하지 않으면 "정리했는데 왜 디스크가 그대로지?"가 된다.
    /// 옮긴 것이 없으면 nil. "0 바이트가 확보됩니다"는 알려줄 것이 아니다.
    public var trashNotice: String? {
        reclaimedBytes > 0 ? String(localized: "휴지통을 비우면 \(formattedReclaimed)가 실제로 확보됩니다") : nil
    }
}
