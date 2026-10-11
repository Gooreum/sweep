import Foundation

/// 정리 한 회차의 기록. **경로는 담지 않는다** — 숫자만 남겨 개인정보 부담을 피한다.
public struct CleanupRecord: Codable, Sendable, Hashable {
    public let date: Date
    public let reclaimedBytes: Int64
    public let succeededCount: Int
    public let failedCount: Int
    /// 카테고리 rawValue → 회수 바이트.
    /// enum을 직접 저장하면 case 이름이 바뀔 때 지난 기록 전체가 복원되지 않는다.
    public let bytesByCategory: [String: Int64]

    public init(report: RemovalReport, date: Date) {
        self.date = date
        reclaimedBytes = report.reclaimedBytes
        succeededCount = report.succeeded.count
        failedCount = report.failed.count
        var byCategory: [String: Int64] = [:]
        for outcome in report.succeeded {
            byCategory[outcome.item.category.rawValue, default: 0] += outcome.item.size
        }
        bytesByCategory = byCategory
    }
}

/// 지금까지의 합. 뷰가 아니라 여기서 문장을 만든다 — 숫자가 맞는지 뷰 없이 확인할 수 있어야 한다.
public struct CleanupSummary: Sendable, Hashable {
    public let totalReclaimedBytes: Int64
    /// 마지막으로 무언가를 실제로 지운 시각. 기록이 없으면 nil.
    public let lastCleanup: Date?

    public static let empty = CleanupSummary(totalReclaimedBytes: 0, lastCleanup: nil)

    public init(totalReclaimedBytes: Int64, lastCleanup: Date?) {
        self.totalReclaimedBytes = totalReclaimedBytes
        self.lastCleanup = lastCleanup
    }

    /// "지금까지 12.4 GB 확보 · 마지막 정리 3일 전". 기록이 없으면 nil — 빈 줄을 만들지 않는다.
    /// "0 B 확보"는 알려줄 것이 아니라 자리만 차지한다.
    public func statusLine(now: Date = Date()) -> String? {
        guard let lastCleanup else { return nil }
        let bytes = ByteCountFormatter.string(fromByteCount: totalReclaimedBytes, countStyle: .file)
        return "지금까지 \(bytes) 확보 · 마지막 정리 \(Self.relative(lastCleanup, now: now))"
    }

    /// 오래 안 했고 지울 만한 safe 항목이 있을 때만. 재방문 유도 문구.
    ///
    /// 둘 다 있어야 한다 — 지울 것이 없는데 "정리해 보세요"는 빈말이고,
    /// 어제 정리했는데 또 권하면 잔소리다.
    public func nudgeLine(now: Date = Date(), safeBytes: Int64) -> String? {
        guard let lastCleanup, safeBytes > 0 else { return nil }
        let days = Int(now.timeIntervalSince(lastCleanup) / 86_400)
        guard days >= 14 else { return nil }
        let bytes = ByteCountFormatter.string(fromByteCount: safeBytes, countStyle: .file)
        return "마지막 정리 후 \(days)일이 지났습니다. 다시 만들 수 있는 \(bytes)를 정리해 보세요"
    }

    /// 문구 계단은 `FileDates.lastUsedLabel`과 맞춘다 — 한 화면에 두 말투가 섞이지 않게.
    static func relative(_ date: Date, now: Date) -> String {
        let days = Int(now.timeIntervalSince(date) / 86_400)
        switch days {
        // 시계가 어긋난 경우다. "-3일 전"이라고 쓰지 않는다.
        case ..<0: return "방금"
        case 0: return "오늘"
        case ..<30: return "\(days)일 전"
        case ..<365: return "\(days / 30)개월 전"
        default: return "\(days / 365)년 전"
        }
    }
}

/// 정리 기록 저장소.
///
/// `FolderAccess.Registry`와 같은 모양이다 — 저장소를 주입하고 `.shared`를 둔다.
/// 테스트는 `UserDefaults(suiteName:)`를 넘겨 실제 기록을 건드리지 않는다.
public final class CleanupHistory: @unchecked Sendable {
    public static let shared = CleanupHistory()

    /// JSON 배열 하나를 키 하나에 둔다. 회차마다 키를 나누면 순서와 개수를 따로 관리해야 한다.
    static let key = "cleanupHistory.records"

    private let defaults: UserDefaults
    private let lock = NSLock()
    private var cached: [CleanupRecord]

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode([CleanupRecord].self, from: data) {
            cached = decoded
        } else {
            cached = []
        }
    }

    /// 오래된 것부터.
    public var records: [CleanupRecord] {
        lock.lock(); defer { lock.unlock() }
        return cached
    }

    public var summary: CleanupSummary {
        let all = records
        return CleanupSummary(totalReclaimedBytes: all.reduce(0) { $0 + $1.reclaimedBytes },
                              lastCleanup: all.last?.date)
    }

    /// 한 회차를 남긴다. 성공이 하나도 없으면 기록하지 않는다 —
    /// 지운 것이 없는데 "마지막 정리 오늘"이 되면 거짓이다.
    @discardableResult
    public func record(_ report: RemovalReport, at date: Date = Date()) -> CleanupRecord? {
        guard !report.succeeded.isEmpty else { return nil }
        let record = CleanupRecord(report: report, date: date)

        lock.lock(); defer { lock.unlock() }
        cached.append(record)
        if let data = try? JSONEncoder().encode(cached) {
            defaults.set(data, forKey: Self.key)
        }
        return record
    }
}
