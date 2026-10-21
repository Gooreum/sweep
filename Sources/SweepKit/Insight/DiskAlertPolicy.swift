import Foundation

/// 여유 공간이 부족해졌을 때 알릴지 정한다.
///
/// 기준 하나로만 가르면 기준 근처에서 몇 MB씩 오르내릴 때마다 알림이 다시 뜬다.
/// 그래서 "장전" 상태를 둔다 — 한 번 알리면 풀리고, 기준보다 여유분만큼 더
/// 회복해야 다시 장전된다. 한 번 겪는 부족 상황에 알림은 한 번이다.
public struct DiskAlertPolicy: Sendable, Equatable {
    public let threshold: Int64
    public let rearmMargin: Int64

    public init(threshold: Int64, rearmMargin: Int64) {
        self.threshold = threshold
        self.rearmMargin = rearmMargin
    }

    /// 사용량을 읽지 못하면 아무것도 바꾸지 않는다 — 모르는 값과 0은 다르다.
    /// 0으로 보면 읽기가 한 번 실패할 때마다 "공간 부족" 알림이 뜬다.
    public func evaluate(_ usage: VolumeUsage?, armed: Bool) -> (notify: Bool, armed: Bool) {
        guard let usage else { return (false, armed) }
        if armed {
            return usage.available < threshold ? (true, false) : (false, true)
        }
        return (false, usage.available >= threshold + rearmMargin)
    }
}
