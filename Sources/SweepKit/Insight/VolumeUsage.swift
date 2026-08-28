import Foundation

/// 볼륨 하나의 사용량.
///
/// 사이드바 아래에 늘 띄워 둔다 — 정리를 시작하기 전에
/// "지금 얼마나 남았는지"가 보여야 회수량이 의미를 갖는다.
public struct VolumeUsage: Sendable, Equatable {
    public let total: Int64
    public let available: Int64

    public init(total: Int64, available: Int64) {
        self.total = total
        self.available = available
    }

    /// 여유량이 총량보다 큰 값이 들어와도 음수로 내려가지 않는다.
    /// 막대 폭이 음수가 되면 그리지 못한다.
    public var used: Int64 { max(0, total - available) }

    /// 0~1. 총량이 0이면 0 — 나눌 수 없는 것을 나누지 않는다.
    public var usedFraction: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(used) / Double(total)))
    }

    public var formattedTotal: String { Self.format(total) }
    public var formattedAvailable: String { Self.format(available) }
    public var formattedUsed: String { Self.format(used) }

    /// 홈이 놓인 볼륨의 사용량.
    ///
    /// 읽지 못하면 nil이다. 0을 지어내면 화면에 "0바이트 중 0바이트"가 뜬다 —
    /// 값을 모른다는 것과 값이 0이라는 것은 다르다.
    public static func current(
        for url: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> VolumeUsage? {
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey,
            // "중요한 용도"로 실제 확보 가능한 양. 순수 여유 공간은 삭제 가능한
            // 캐시를 빼고 세어서 Finder가 보여주는 숫자와 어긋난다.
            .volumeAvailableCapacityForImportantUsageKey,
        ]
        guard let values = try? url.resourceValues(forKeys: keys),
              let total = values.volumeTotalCapacity,
              let available = values.volumeAvailableCapacityForImportantUsage
        else { return nil }

        return VolumeUsage(total: Int64(total), available: available)
    }

    private static func format(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
