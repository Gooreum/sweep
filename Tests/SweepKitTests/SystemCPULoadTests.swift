import Testing
import Foundation
@testable import SweepKit

/// 기계 전체 사용자·시스템·유휴. 활성 상태 보기 아래쪽 요약과 같은 출처다.
///
/// 환산은 순수 함수라 틱을 손으로 넣어 검사하고, 실제 커널 호출은 한 번만 확인한다.
@Suite("SystemCPULoad")
struct SystemCPULoadTests {

    private func ticks(_ user: UInt32, _ system: UInt32, _ idle: UInt32, nice: UInt32 = 0)
        -> CPULoadTicks {
        CPULoadTicks(user: user, system: system, idle: idle, nice: nice)
    }

    @Test("틱 차이를 기계 전체 100 기준으로 나눈다")
    func splitsIntoShares() throws {
        let load = try #require(SystemCPULoad.compute(
            from: ticks(100, 100, 100), to: ticks(130, 120, 150)))

        #expect(load.user == 30)
        #expect(load.system == 20)
        #expect(load.idle == 50)
        #expect(load.used == 50)
        // 셋을 더하면 기계 전체다 — 이 성질이 "유휴"를 믿을 근거다
        #expect(load.user + load.system + load.idle == 100)
    }

    @Test("틱이 하나도 늘지 않았으면 nil이다")
    func noProgressYieldsNil() {
        // 0으로 나누면 "nan%"가 뜬다. 모르는 것을 지어내지 않는다.
        #expect(SystemCPULoad.compute(from: ticks(5, 5, 5), to: ticks(5, 5, 5)) == nil)
    }

    @Test("UInt32가 한 바퀴 돌아도 차이가 맞다")
    func wrapAroundIsHandled() throws {
        // 오래 켜 둔 기계에서 누적 틱이 최댓값을 넘어 0부터 다시 센다.
        // 그냥 빼면 음수가 되어 트랩이 나거나 터무니없는 값이 된다.
        let max = UInt32.max
        let load = try #require(SystemCPULoad.compute(
            from: ticks(max - 9, 0, 0), to: ticks(10, 0, 20)))

        // 사용자 20틱(max-9 → 10), 유휴 20틱
        #expect(load.user == 50)
        #expect(load.idle == 50)
    }

    @Test("nice로 낮춘 프로세스는 사용자 몫에 합친다")
    func niceCountsAsUser() throws {
        // 활성 상태 보기도 nice를 따로 보여주지 않고 사용자에 넣는다
        let load = try #require(SystemCPULoad.compute(
            from: ticks(0, 0, 0), to: ticks(10, 0, 80, nice: 10)))

        #expect(load.user == 20)
        #expect(load.idle == 80)
    }

    @Test("실제 커널에서 누적 틱을 읽는다")
    func readsRealTicks() throws {
        // 프로세스를 하나씩 들여다보지 않는 호출이라 root 프로세스 제약과 상관없다.
        let first = try #require(SystemCPULoad.tick(), "host_statistics를 못 읽었다")
        Thread.sleep(forTimeInterval: 0.2)
        let second = try #require(SystemCPULoad.tick())
        let load = try #require(SystemCPULoad.compute(from: first, to: second))

        #expect(abs(load.user + load.system + load.idle - 100) < 0.001)
    }

    @Test("성능·효율 코어 수를 더하면 전체 코어 수다")
    func coreKindsAddUp() {
        // 인텔 맥은 코어 종류가 하나라 값이 없다 — 있을 때만 검사한다.
        guard let performance = ProcessCPUSampler.performanceCores,
              let efficiency = ProcessCPUSampler.efficiencyCores else { return }

        #expect(performance + efficiency == ProcessCPUSampler.coreCount)
    }
}
