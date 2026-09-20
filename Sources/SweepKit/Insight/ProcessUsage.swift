import Foundation

/// 한 프로세스가 켜진 뒤로 쓴 **누적** CPU 시간.
///
/// 이 값 하나로는 "지금 얼마나 쓰고 있는지"를 알 수 없다. 누적값은 커지기만 하므로
/// 두 번 재서 **차이**를 봐야 사용률이 나온다 — 커지고 있는 임시 파일을 두 번 재서
/// 분당 증가분을 내는 `RunawayTempScanner`와 같은 수법이다.
public struct ProcessCPUTick: Sendable, Equatable {
    public let pid: pid_t
    public let name: String
    public let executablePath: String?
    public let nanoseconds: UInt64

    public init(
        pid: pid_t,
        name: String,
        executablePath: String? = nil,
        nanoseconds: UInt64
    ) {
        self.pid = pid
        self.name = name
        self.executablePath = executablePath
        self.nanoseconds = nanoseconds
    }
}

/// 한 프로세스의 CPU 사용률. 두 시점의 `ProcessCPUTick` 차이에서 나온다.
public struct ProcessUsage: Sendable, Equatable, Identifiable {
    public let pid: pid_t
    public let name: String
    public let executablePath: String?

    /// 코어 하나를 꽉 채우면 100. **상한을 두지 않는다** — 코어가 여럿이라 327%가
    /// 나올 수 있고 그게 사실이다. 100으로 깎으면 여덟 코어를 다 쓰는 프로세스와
    /// 한 코어만 쓰는 프로세스가 같아 보인다.
    public let percent: Double

    public var id: pid_t { pid }

    public init(pid: pid_t, name: String, executablePath: String? = nil, percent: Double) {
        self.pid = pid
        self.name = name
        self.executablePath = executablePath
        self.percent = percent
    }

    /// "327.1%". 소수 한 자리 — 초 단위 샘플에서 그 아래는 흔들리는 잡음이다.
    public var formattedPercent: String { String(format: "%.1f%%", percent) }
}

extension ProcessUsage {

    /// 두 시점의 누적 CPU 시간 차이를 사용률로 환산한다.
    ///
    /// **순수 함수다.** 실제 프로세스를 띄우지 않고 규칙을 검사할 수 있어야 해서
    /// 수집(`ProcessCPUSampler`)과 환산을 갈라 뒀다 — `RunawayTempScanner`가
    /// 측정과 `detail(growth:over:)`을 가른 것과 같은 이유다.
    public static func compute(
        from before: [ProcessCPUTick],
        to after: [ProcessCPUTick],
        over interval: Duration
    ) -> [ProcessUsage] {
        let seconds = interval.asSeconds
        // 구간이 없으면 사용률도 없다. 0으로 나누면 화면에 "inf%"가 뜬다 —
        // `VolumeUsage.usedFraction`이 총량 0에서 0을 주는 것과 같은 태도다.
        guard seconds > 0 else { return [] }

        var baseline: [pid_t: UInt64] = [:]
        baseline.reserveCapacity(before.count)
        for tick in before { baseline[tick.pid] = tick.nanoseconds }

        var result: [ProcessUsage] = []
        for tick in after {
            // 기준선이 없다 = 두 샘플 사이에 새로 떴다. 켜진 뒤의 누적값 전체를
            // 이 구간에 밀어 넣으면 수백 %로 튄다.
            guard let start = baseline[tick.pid] else { continue }
            // 누적값이 줄었다 = pid가 재사용됐다. 남의 값이므로 버린다.
            // 늘지 않았으면 이 구간에 CPU를 쓰지 않은 것이라 목록에 올릴 이유가 없다.
            guard tick.nanoseconds > start else { continue }

            let used = Double(tick.nanoseconds - start)
            result.append(ProcessUsage(
                pid: tick.pid,
                name: tick.name,
                executablePath: tick.executablePath,
                percent: used / (seconds * 1_000_000_000) * 100
            ))
        }

        // 큰 것부터. 동률은 pid로 갈라 순서를 고정한다 — 흔들리면 주기마다
        // 같은 행이 자리를 바꿔 읽을 수 없다.
        return result.sorted {
            $0.percent == $1.percent ? $0.pid < $1.pid : $0.percent > $1.percent
        }
    }
}

private extension Duration {
    /// `Duration`은 초를 바로 주지 않는다. attosecond까지 살려서 환산한다 —
    /// 초 단위로 자르면 밀리초 구간이 0이 되어 사용률을 못 낸다.
    var asSeconds: Double {
        let parts = components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
    }
}
