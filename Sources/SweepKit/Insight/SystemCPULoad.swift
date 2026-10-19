import Darwin
import Foundation

/// 커널이 세는 CPU 시간 누적값(틱). 기계의 **모든** 코어·모든 계정을 합친 값이다.
///
/// 활성 상태 보기 아래쪽 "사용자 / 시스템 / 유휴"가 이 값에서 나온다.
/// 프로세스 목록(`ProcessCPUSampler`)은 내 계정 것만 읽혀서 더해도 기계 전체가 되지 않는다 —
/// root 소유인 WindowServer·kernel_task가 빠진다. 그 합으로 유휴를 셈하면 기계가
/// 버벅일 때도 유휴가 넉넉하게 나왔다(실측: load avg 112에서 유휴 32.5%).
public struct CPULoadTicks: Sendable, Equatable {
    public let user: UInt32
    public let system: UInt32
    public let idle: UInt32
    public let nice: UInt32

    public init(user: UInt32, system: UInt32, idle: UInt32, nice: UInt32) {
        self.user = user
        self.system = system
        self.idle = idle
        self.nice = nice
    }
}

/// 두 시점 사이에 기계 전체를 100으로 본 몫. 셋을 더하면 100이다.
public struct SystemCPULoad: Sendable, Equatable {
    /// nice로 낮춘 프로세스도 포함한다 — 활성 상태 보기도 사용자에 합친다.
    public let user: Double
    public let system: Double
    public let idle: Double

    public init(user: Double, system: Double, idle: Double) {
        self.user = user
        self.system = system
        self.idle = idle
    }

    /// 사용자 + 시스템. 화면의 큰 숫자다.
    public var used: Double { user + system }
}

extension SystemCPULoad {

    /// 두 누적값의 차이를 몫으로 환산한다.
    ///
    /// **순수 함수다.** `ProcessUsage.compute`와 같은 이유로 수집과 갈라 뒀다.
    /// 틱이 하나도 늘지 않았으면 nil — 0으로 나눠 "nan%"를 띄우지 않는다.
    public static func compute(from before: CPULoadTicks, to after: CPULoadTicks) -> SystemCPULoad? {
        // 틱은 UInt32라 오래 켜 둔 기계에서는 한 바퀴 돈다. `&-`로 감싸 빼면
        // 한 바퀴 돈 뒤에도 차이가 맞다 — 한 구간에 한 바퀴 이상 돌 일은 없다.
        let user = Double(after.user &- before.user) + Double(after.nice &- before.nice)
        let system = Double(after.system &- before.system)
        let idle = Double(after.idle &- before.idle)
        let total = user + system + idle
        guard total > 0 else { return nil }

        return SystemCPULoad(
            user: user / total * 100,
            system: system / total * 100,
            idle: idle / total * 100)
    }

    /// 지금까지의 누적 틱. 읽지 못하면 nil.
    ///
    /// `host_statistics(HOST_CPU_LOAD_INFO)`는 프로세스를 하나씩 들여다보지 않고
    /// 커널의 합계만 묻는다 — root 프로세스를 못 읽는 제약과 상관없다.
    public static func tick() -> CPULoadTicks? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        let ticks = info.cpu_ticks
        return CPULoadTicks(
            user: ticks.0,     // CPU_STATE_USER
            system: ticks.1,   // CPU_STATE_SYSTEM
            idle: ticks.2,     // CPU_STATE_IDLE
            nice: ticks.3)     // CPU_STATE_NICE
    }

    /// `mach_host_self()`는 부를 때마다 포트 참조를 하나씩 늘린다. 2초마다
    /// 부르는 화면이라 한 번만 얻어 둔다.
    private static let host = mach_host_self()
}
