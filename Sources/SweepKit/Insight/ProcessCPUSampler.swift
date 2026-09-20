import Darwin
import Foundation

/// 지금 돌고 있는 프로세스의 누적 CPU 시간을 한 번 읽는다.
///
/// **샌드박스 안에서도 된다.** 서명한 번들로 실측해 확인한 경계다:
///
/// - `proc_listpids`는 막힌다(0개). `appsandbox-common.sb`가 `(deny process-info*)`
///   뒤에 `process-info-pidinfo`만 다시 열기 때문이다. 그래서 **목록을 여기서 얻지 않는다.**
/// - 목록은 `sysctl KERN_PROC_ALL`로 얻는다 — `system.sb`의 `(allow sysctl-read)`가
///   이름 제한 없이 열려 있다. 샌드박스 안에서도 523개가 그대로 나온다.
/// - `proc_pidinfo`는 남의 프로세스에도 열려 있어 누적 CPU 시간을 읽을 수 있다.
///
/// **내 계정 소유만 읽힌다** (실측 521개 중 322개). root 소유(WindowServer·mds)는
/// 샌드박스 **밖에서도** 못 읽는다 — `ps`·`top`이 보여 주는 것은 그 둘이
/// setuid root이기 때문이고, 일반 앱은 그 자리에 못 간다.
public enum ProcessCPUSampler {

    /// 읽을 수 있는 프로세스 전부의 누적 CPU 시간.
    ///
    /// 이 값만으로는 사용률을 알 수 없다. 두 번 불러
    /// `ProcessUsage.compute(from:to:over:)`에 넘겨야 한다.
    public static func tick() -> [ProcessCPUTick] {
        processIdentifiers().compactMap(tick(for:))
    }

    /// `proc_listpids`가 아니라 `sysctl`이다 — 위 주석의 이유. 바꾸면 샌드박스에서 0개가 된다.
    private static func processIdentifiers() -> [pid_t] {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]

        // 크기를 묻고 읽는 사이에 프로세스가 늘면 버퍼가 모자라 실패한다.
        // 한 번 더 묻는다 — 두 번째도 실패하면 이번 샘플은 거른다.
        // 다음 주기에 다시 재므로 한 번 빠지는 것은 화면에서 보이지 않는다.
        for _ in 0..<2 {
            var size = 0
            guard sysctl(&mib, 4, nil, &size, nil, 0) == 0, size > 0 else { return [] }

            let stride = MemoryLayout<kinfo_proc>.stride
            var buffer = [kinfo_proc](repeating: kinfo_proc(), count: size / stride)
            var read = size
            guard sysctl(&mib, 4, &buffer, &read, nil, 0) == 0 else { continue }

            // 두 번째 호출이 처음 물은 것보다 적게 채울 수 있다. 채워진 만큼만 읽는다 —
            // 남은 자리는 0으로 초기화된 껍데기라 pid 0으로 잡힌다.
            return buffer.prefix(read / stride)
                .map(\.kp_proc.p_pid)
                .filter { $0 > 0 }
        }
        return []
    }

    private static func tick(for pid: pid_t) -> ProcessCPUTick? {
        var info = proc_taskinfo()
        let size = Int32(MemoryLayout<proc_taskinfo>.size)
        // 내 계정 소유가 아니면 여기서 떨어지고 목록에서 빠진다.
        // 0으로 채워 넣으면 "CPU를 안 쓴다"는 거짓말이 된다 —
        // 값을 모른다는 것과 값이 0이라는 것은 다르다.
        guard proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, size) == size else { return nil }

        let path = executablePath(of: pid)
        return ProcessCPUTick(
            pid: pid,
            name: displayName(of: pid, path: path),
            executablePath: path,
            nanoseconds: nanoseconds(fromAbsolute: info.pti_total_user + info.pti_total_system)
        )
    }

    /// Mach 절대시간 → 나노초.
    ///
    /// **`proc_pidinfo`가 주는 누적 시간은 나노초가 아니다.** Mach 절대시간 단위이고,
    /// Apple Silicon에서 1틱은 41.666ns다(timebase 125/3). 환산하지 않으면 사용률이
    /// 41배 작게 나온다 — 실측으로 코어를 꽉 채운 `yes`가 **2.4%**로 찍혔다(`ps`는 99%).
    ///
    /// `proc_pid_rusage`는 처음부터 나노초를 주지만 쓸 수 없다. 샌드박스가
    /// `process-info-rusage`를 자기 자신에게만 열어 둬서 남의 프로세스는 못 읽는다.
    private static func nanoseconds(fromAbsolute ticks: UInt64) -> UInt64 {
        ticks * timebase.numer / timebase.denom
    }

    /// 기계마다 다르고 실행 중에 바뀌지 않는다. 한 번만 묻는다 —
    /// 샘플마다 물으면 프로세스 수만큼 syscall이 는다.
    private static let timebase: (numer: UInt64, denom: UInt64) = {
        var info = mach_timebase_info_data_t()
        // 못 읽으면 1:1로 둔다. 인텔에서는 실제로 1:1이라 그쪽에서는 이것이 정답이다.
        guard mach_timebase_info(&info) == KERN_SUCCESS, info.denom != 0 else { return (1, 1) }
        return (UInt64(info.numer), UInt64(info.denom))
    }()

    /// 이름은 세 단계로 물러선다. 어느 경우에도 빈 줄을 그리지 않는다.
    ///
    /// 1. 실행 파일 경로의 마지막 조각 — `qemu-system-aarch64`가 온전히 나온다
    /// 2. `proc_name` — 경로를 못 읽으면 이름만
    /// 3. `pid 1234` — 둘 다 실패해도 행은 그려야 한다
    ///
    /// `kinfo_proc`의 `p_comm`은 쓰지 않는다. 16자에서 잘려 `qemu-system-aar`가 된다.
    private static func displayName(of pid: pid_t, path: String?) -> String {
        if let path {
            let last = URL(filePath: path).lastPathComponent
            if !last.isEmpty { return last }
        }

        var buffer = [CChar](repeating: 0, count: 256)
        if proc_name(pid, &buffer, UInt32(buffer.count)) > 0 {
            let name = string(from: buffer)
            if !name.isEmpty { return name }
        }

        return "pid \(pid)"
    }

    private static func executablePath(of pid: pid_t) -> String? {
        // `PROC_PIDPATHINFO_MAXSIZE`는 매크로라 Swift에 넘어오지 않는다.
        // 정의가 `4 * MAXPATHLEN`이므로 그대로 풀어 쓴다 — 더 작게 잡으면
        // `proc_pidpath`가 ENOMEM으로 떨어져 긴 경로의 이름이 통째로 사라진다.
        var buffer = [CChar](repeating: 0, count: 4 * Int(PATH_MAX))
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        let path = string(from: buffer)
        return path.isEmpty ? nil : path
    }

    /// C가 채워 준 고정 길이 버퍼를 문자열로 읽는다.
    ///
    /// `String(cString:)`은 deprecated다. 널 앞까지만 잘라서 UTF-8로 읽으라는 것이
    /// 대체 방법인데, 자르지 않으면 뒤에 남은 0들이 그대로 따라 들어온다.
    private static func string(from buffer: [CChar]) -> String {
        String(decoding: buffer.prefix { $0 != 0 }.map(UInt8.init(bitPattern:)), as: UTF8.self)
    }
}
