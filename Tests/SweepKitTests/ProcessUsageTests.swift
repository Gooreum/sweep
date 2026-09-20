import Testing
import Foundation
@testable import SweepKit

/// 누적 CPU 시간 두 개를 사용률로 바꾸는 규칙.
///
/// 실제 프로세스를 띄우지 않는다 — 환산이 순수 함수라 여기서 전부 검사할 수 있다.
@Suite("ProcessUsage")
struct ProcessUsageTests {

    private func tick(_ pid: pid_t, _ nanoseconds: UInt64, name: String = "테스트") -> ProcessCPUTick {
        ProcessCPUTick(pid: pid, name: name, nanoseconds: nanoseconds)
    }

    // TC-1
    @Test("1초 동안 1초치를 쓰면 100%다")
    func fullCoreIsHundredPercent() {
        let usage = ProcessUsage.compute(
            from: [tick(1, 0)],
            to: [tick(1, 1_000_000_000)],
            over: .seconds(1))

        #expect(usage.count == 1)
        #expect(usage[0].percent == 100)
    }

    // TC-2
    @Test("구간이 0이면 빈 배열이다")
    func zeroIntervalYieldsNothing() {
        // 0으로 나누면 inf가 나오고 화면에 "inf%"가 뜬다.
        // 모르는 것을 지어내느니 아무것도 주지 않는다.
        let usage = ProcessUsage.compute(
            from: [tick(1, 0)],
            to: [tick(1, 5_000_000_000)],
            over: .zero)

        #expect(usage.isEmpty)
    }

    // TC-3
    @Test("두 샘플 사이에 새로 뜬 프로세스는 빠진다")
    func newProcessWithoutBaselineIsExcluded() {
        // 기준선이 없는데 누적값 전체를 구간에 밀어 넣으면 수백 %로 튄다.
        let usage = ProcessUsage.compute(
            from: [tick(1, 0)],
            to: [tick(1, 500_000_000), tick(99, 30_000_000_000)],
            over: .seconds(1))

        #expect(usage.map(\.pid) == [1])
    }

    // TC-4
    @Test("누적값이 줄었으면 pid 재사용이므로 빠진다")
    func shrunkCounterIsExcluded() {
        // 누적 CPU 시간은 줄어들 수 없다. 줄었다면 같은 pid를 다른 프로세스가 받은 것이다.
        let usage = ProcessUsage.compute(
            from: [tick(1, 9_000_000_000)],
            to: [tick(1, 100)],
            over: .seconds(1))

        #expect(usage.isEmpty)
    }

    // TC-5
    @Test("코어를 여럿 쓰면 100%를 넘는다")
    func multiCoreExceedsHundred() {
        // 2초 구간에 4초치를 썼다 = 코어 두 개를 꽉 채웠다.
        // 100으로 깎으면 한 코어만 쓰는 프로세스와 구분이 안 된다.
        let usage = ProcessUsage.compute(
            from: [tick(1, 0)],
            to: [tick(1, 4_000_000_000)],
            over: .seconds(2))

        #expect(usage[0].percent == 200)
    }

    // TC-6
    @Test("사용률 내림차순, 동률은 pid 오름차순으로 고정된다")
    func sortedByPercentThenPid() {
        // 순서가 흔들리면 주기마다 같은 행이 자리를 바꿔 읽을 수 없다.
        let before = [tick(10, 0), tick(20, 0), tick(30, 0), tick(40, 0), tick(50, 0)]
        let after = [
            tick(10, 1_000_000_000),   // 100%
            tick(20, 3_000_000_000),   // 300%
            tick(30, 2_000_000_000),   // 200%
            tick(40, 1_000_000_000),   // 100% — 10과 동률
            tick(50, 500_000_000),     // 50%
        ]

        let usage = ProcessUsage.compute(from: before, to: after, over: .seconds(1))

        #expect(usage.map(\.pid) == [20, 30, 10, 40, 50])
    }

    // TC-7
    @Test("증가분이 없으면 목록에 올리지 않는다")
    func idleProcessIsExcluded() {
        // "지금 CPU를 쓰는 프로세스" 목록이다. 0은 답이 아니다.
        let usage = ProcessUsage.compute(
            from: [tick(1, 7_000_000_000)],
            to: [tick(1, 7_000_000_000)],
            over: .seconds(2))

        #expect(usage.isEmpty)
    }

    // TC-8
    @Test("사용률은 소수 한 자리로 보인다")
    func percentIsFormattedToOneDecimal() {
        // 초 단위 샘플에서 그 아래는 흔들리는 잡음이다.
        let usage = ProcessUsage(pid: 1, name: "qemu", percent: 327.14159)

        #expect(usage.formattedPercent == "327.1%")
    }

    // TC-9
    @Test("밀리초 구간도 초로 환산된다")
    func subSecondIntervalIsNotTruncated() {
        // Duration을 초 단위로 자르면 0이 되어 위 TC-2와 구분이 안 된다.
        let usage = ProcessUsage.compute(
            from: [tick(1, 0)],
            to: [tick(1, 500_000_000)],
            over: .milliseconds(500))

        #expect(usage.count == 1)
        #expect(usage[0].percent == 100)
    }

    // TC-10
    @Test("이름과 경로가 환산 뒤에도 그대로 실린다")
    func identitySurvivesComputation() {
        let before = [ProcessCPUTick(pid: 7, name: "claude", executablePath: "/opt/bin/claude", nanoseconds: 0)]
        let after = [ProcessCPUTick(pid: 7, name: "claude", executablePath: "/opt/bin/claude", nanoseconds: 1_000_000_000)]

        let usage = ProcessUsage.compute(from: before, to: after, over: .seconds(1))

        #expect(usage[0].name == "claude")
        #expect(usage[0].executablePath == "/opt/bin/claude")
        // 행을 pid로 갈라야 같은 이름의 프로세스 두 개가 한 줄로 합쳐지지 않는다
        #expect(usage[0].id == 7)
    }
}
