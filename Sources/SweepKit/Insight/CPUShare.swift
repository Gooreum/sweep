import Foundation

/// 원형 그래프의 조각 하나.
///
/// 프로세스 하나이거나, 상위에 못 든 것을 묶은 "기타"이거나, 아무도 쓰지 않는 "유휴"다.
/// **색은 여기 없다** — SweepKit은 SwiftUI를 import하지 않는다(`DiskMapModel`과 같은 규칙).
/// 어떤 색으로 그릴지는 화면이 정한다.
public struct CPUShare: Sendable, Equatable, Identifiable {

    public enum Kind: Sendable, Equatable {
        /// 개별 프로세스. 목록의 행과 pid로 이어진다.
        case process(pid_t)
        /// 상위 N개에 못 든 프로세스를 전부 합친 것.
        case other
        /// 아무도 쓰지 않는 몫. **이걸 그려야 분모가 기계 전체라는 것이 보인다.**
        /// 빼고 그리면 조각이 원을 꽉 채워 "기계가 가득 찼다"로 읽힌다.
        case idle
    }

    public let kind: Kind
    public let name: String
    public let percent: Double

    public init(kind: Kind, name: String, percent: Double) {
        self.kind = kind
        self.name = name
        self.percent = percent
    }

    /// 같은 이름의 프로세스가 여럿이라 이름으로는 가를 수 없다. pid로 가른다.
    public var id: String {
        switch kind {
        case .process(let pid): "p\(pid)"
        case .other: "other"
        case .idle: "idle"
        }
    }

    public var formattedPercent: String { String(format: "%.1f%%", percent) }
}

extension CPUShare {

    /// 사용률 목록을 원형 그래프의 조각으로 자른다.
    ///
    /// **순수 함수다.** "조각의 합이 정확히 100"이라는 성질을 실제 프로세스 없이
    /// 검사할 수 있어야 한다 — 그 성질이 이 그래프가 성립하는 근거다.
    ///
    /// - Parameter top: 개별 조각으로 뗄 개수. 나머지는 "기타"로 묶는다 —
    ///   300개를 다 그리면 조각이 머리카락처럼 얇아져 아무것도 읽을 수 없다.
    public static func slices(from usage: [ProcessUsage], top: Int = 6) -> [CPUShare] {
        guard top > 0 else { return [] }

        // 들어온 목록이 정렬돼 있다고 믿지 않는다. 조각의 순서가 곧 범례의
        // 순서이고, 뒤섞이면 큰 조각이 아래에 온다.
        let sorted = usage.sorted {
            $0.percent == $1.percent ? $0.pid < $1.pid : $0.percent > $1.percent
        }

        var slices = sorted.prefix(top).map {
            CPUShare(kind: .process($0.pid), name: $0.name, percent: $0.percent)
        }

        // 0.05% 미만은 "0.0% 기타"로 찍혀 자리만 차지한다.
        // 반올림해서 보이는 값이 생길 때만 조각을 만든다.
        let rest = sorted.dropFirst(top).reduce(0) { $0 + $1.percent }
        if rest >= 0.05 {
            slices.append(CPUShare(kind: .other, name: "기타", percent: rest))
        }

        // 남는 몫. 측정 시차로 합이 100을 아주 조금 넘을 수 있어 0에서 막는다 —
        // 음수 조각은 그릴 수 없다.
        let used = slices.reduce(0) { $0 + $1.percent }
        let idle = max(0, 100 - used)
        if idle >= 0.05 {
            slices.append(CPUShare(kind: .idle, name: "유휴", percent: idle))
        }

        return slices
    }
}
