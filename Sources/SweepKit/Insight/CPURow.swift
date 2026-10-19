import Foundation

/// CPU 목록의 한 줄. 읽은 프로세스이거나, 샌드박스가 못 읽는 시스템 프로세스의 합계다.
///
/// 샌드박스 앱은 root 소유 프로세스(kernel_task, WindowServer, launchd)의 CPU 시간을
/// 하나씩 읽을 수 없다 — `proc_pidinfo`·`proc_pid_rusage`가 EPERM이고, setuid인
/// `top` 실행도 막힌다(실측). 그 몫을 문장으로만 적으면 목록에서 kernel_task가 "없는
/// 것"으로 읽혀서, 활성 상태 보기와 같은 단위의 한 줄로 목록에 넣는다.
public enum CPURow: Sendable, Equatable, Identifiable {
    case process(ProcessUsage)
    /// root·다른 계정 프로세스 합계. 프로세스 행과 같이 코어 하나 = 100 단위다.
    case unlisted(percent: Double)

    public var id: String {
        switch self {
        case .process(let usage): "p\(usage.pid)"
        case .unlisted: "unlisted"
        }
    }

    public var percent: Double {
        switch self {
        case .process(let usage): usage.percent
        case .unlisted(let percent): percent
        }
    }

    public var formattedPercent: String { String(format: "%.1f%%", percent) }
}

extension CPURow {

    /// 합계 행을 점유율 순서대로 끼워 넣는다.
    ///
    /// **순수 함수다.** 들어온 `usage`는 이미 내림차순이라고 믿는다 —
    /// `ProcessUsage.compute`가 그렇게 돌려준다. 합계가 0.5 미만이면 반올림해
    /// "0.4%"짜리 줄이 자리만 차지하므로 만들지 않는다.
    public static func rows(usage: [ProcessUsage], unlisted: Double?) -> [CPURow] {
        var rows = usage.map(CPURow.process)
        guard let unlisted, unlisted >= 0.5 else { return rows }
        // 동률이면 읽은 프로세스를 앞에 둔다 — 실제 이름이 있는 줄이 먼저 보이게.
        let index = rows.firstIndex { $0.percent < unlisted } ?? rows.endIndex
        rows.insert(.unlisted(percent: unlisted), at: index)
        return rows
    }
}
