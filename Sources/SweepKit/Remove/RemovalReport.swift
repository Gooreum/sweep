import Foundation

/// 삭제 시도 하나의 결과.
public struct RemovalOutcome: Sendable, Hashable {
    public let item: CleanupItem

    /// nil이면 성공. 실패면 사용자에게 그대로 보여줄 수 있는 문장이다.
    ///
    /// `Error`를 담지 않는 이유는 `Error`가 `Sendable`이 아니어서
    /// `@MainActor` 뷰 모델로 넘길 수 없기 때문이며, UI 표시에도 문자열이 낫다.
    public let failureReason: String?

    public var succeeded: Bool { failureReason == nil }

    public init(item: CleanupItem, failureReason: String?) {
        self.item = item
        self.failureReason = failureReason
    }
}

/// 삭제 한 회차 전체의 결과.
public struct RemovalReport: Sendable, Hashable {
    public let outcomes: [RemovalOutcome]

    public init(outcomes: [RemovalOutcome]) { self.outcomes = outcomes }

    public var succeeded: [RemovalOutcome] { outcomes.filter(\.succeeded) }
    public var failed: [RemovalOutcome] { outcomes.filter { !$0.succeeded } }

    /// 실제로 회수된 바이트. 실패한 항목은 세지 않는다 —
    /// 실패 용량까지 합치면 "50GB 확보"라고 표시해 놓고 아무것도 안 지워질 수 있다.
    public var reclaimedBytes: Int64 { succeeded.reduce(0) { $0 + $1.item.size } }

    public var formattedReclaimed: String {
        ByteCountFormatter.string(fromByteCount: reclaimedBytes, countStyle: .file)
    }
}
