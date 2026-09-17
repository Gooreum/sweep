import Foundation
import SweepKit

/// **임시 계측기. 원인을 찾은 뒤 반드시 걷어낸다.**
///
/// 63줄짜리 목록이 버벅이는 이유를 추측으로 고르지 않으려고 둔다.
/// 어디가 비싼지는 숫자로만 알 수 있다.
enum RenderProbe {
    nonisolated(unsafe) static var rowBodies = 0
    nonisolated(unsafe) static var groupSeconds = 0.0
    nonisolated(unsafe) static var groupCalls = 0
    nonisolated(unsafe) static var sizeSeconds = 0.0
    nonisolated(unsafe) static var sizeCalls = 0
    nonisolated(unsafe) private static var started = false

    /// 잰 구간의 시간을 누적한다.
    static func time<T>(_ body: () -> T, into seconds: inout Double, calls: inout Int) -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let value = body()
        seconds += CFAbsoluteTimeGetCurrent() - start
        calls += 1
        return value
    }

    static func startReporting() {
        guard !started else { return }
        started = true
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            fputs("PROBE rows=\(rowBodies)"
                  + " groups=\(String(format: "%.4f", groupSeconds))s/\(groupCalls)"
                  + " size=\(String(format: "%.4f", SizeProbe.seconds))s/\(SizeProbe.calls)\n", stderr)
        }
    }
}
