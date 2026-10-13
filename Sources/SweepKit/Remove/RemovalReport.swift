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
    case other

    /// 사유 아래에 붙일 다음 행동. 할 말이 없으면 nil — 빈 줄을 만들지 않는다.
    ///
    /// 앱을 대신 끄지 않는다. App Store 빌드에서는 남의 프로세스를 끝낼 수 없다(README CPU 절).
    public var advice: String? {
        switch self {
        case .applicationRunning: "앱을 종료한 뒤 다시 시도하세요"
        case .permissionDenied: "전체 디스크 접근을 켜면 옮길 수 있습니다"
        case .protected: "보호된 항목이라 이 앱으로는 지울 수 없습니다"
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

    public init(item: CleanupItem, failure: RemovalFailure?) {
        self.item = item
        self.failure = failure
    }

    /// 종류를 모르는 호출부(테스트·하니스)용. 종류는 `.other`로 둔다.
    public init(item: CleanupItem, failureReason: String?) {
        self.init(item: item,
                  failure: failureReason.map { RemovalFailure(reason: $0, kind: .other) })
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

    /// 완료 화면의 안내 한 줄. 휴지통으로 옮겼을 뿐이라 비우기 전까지 디스크 여유 공간은 그대로다.
    /// 옮긴 것이 없으면 nil — "0 B가 확보됩니다"는 알려줄 것이 아니다.
    public var trashNotice: String? {
        guard reclaimedBytes > 0 else { return nil }
        return "휴지통을 비우면 \(formattedReclaimed)가 실제로 확보됩니다"
    }
}
