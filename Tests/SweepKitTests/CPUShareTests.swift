import Testing
import Foundation
@testable import SweepKit

/// 사용률 목록을 원형 그래프 조각으로 자르는 규칙.
///
/// 이 스위트가 지키는 것은 하나다 — **조각의 합이 정확히 100**.
/// 그 성질이 깨지면 원형 그래프 자체가 성립하지 않는다.
@Suite("CPUShare")
struct CPUShareTests {

    private func usage(_ pid: pid_t, _ percent: Double, name: String? = nil) -> ProcessUsage {
        ProcessUsage(pid: pid, name: name ?? "p\(pid)", percent: percent)
    }

    private func total(_ slices: [CPUShare]) -> Double {
        slices.reduce(0) { $0 + $1.percent }
    }

    // TC-1
    @Test("남는 몫이 유휴 조각으로 붙는다")
    func idleFillsTheRemainder() {
        let slices = CPUShare.slices(from: [usage(1, 10), usage(2, 20), usage(3, 30)])

        #expect(slices.count == 4)
        #expect(slices.last?.kind == .idle)
        #expect(slices.last?.percent == 40)
        #expect(slices.last?.name == "유휴")
    }

    // TC-2
    @Test("입력 합이 100 이하면 조각 합은 정확히 100이다")
    func slicesAlwaysSumToHundred() {
        // 이 그래프가 성립하는 근거다. 깨지면 원에 빈틈이 생기거나 넘친다.
        //
        // 분모가 기계 전체이므로 입력 합은 100을 넘을 수 없다(`ProcessUsage.compute`가
        // 코어 수로 나눈다). 측정 시차로 아주 조금 넘는 경우는 TC-5가 따로 본다.
        let cases: [[ProcessUsage]] = [
            [],
            [usage(1, 0.4)],
            [usage(1, 10), usage(2, 20), usage(3, 30)],
            // 20개가 84%를 나눠 쓰는 흔한 모양 — 상위 6개 + 기타 + 유휴
            (1...20).map { usage(pid_t($0), Double($0) * 0.4) },
            [usage(1, 99.9)],
        ]

        for input in cases {
            let sum = total(CPUShare.slices(from: input))
            #expect(abs(sum - 100) < 0.000_001, "합이 \(sum) — 입력 \(input.count)개")
        }
    }

    // TC-3
    @Test("상위 개수보다 적으면 기타 조각이 없다")
    func noOtherSliceWhenEverythingFits() {
        let slices = CPUShare.slices(from: [usage(1, 10), usage(2, 20)], top: 6)

        #expect(!slices.contains { $0.kind == .other })
        // 20%짜리가 먼저다 — 들어온 순서가 아니라 크기 순으로 나온다
        #expect(slices.map(\.kind) == [.process(2), .process(1), .idle])
    }

    // TC-4
    @Test("아무도 안 쓰면 유휴 하나뿐이다")
    func emptyInputIsAllIdle() {
        let slices = CPUShare.slices(from: [])

        #expect(slices.count == 1)
        #expect(slices[0].kind == .idle)
        #expect(slices[0].percent == 100)
    }

    // TC-5
    @Test("합이 100을 조금 넘어도 음수 조각을 만들지 않는다")
    func overHundredNeverGoesNegative() {
        // 프로세스를 하나씩 읽는 동안 시간이 흘러 합이 100을 살짝 넘을 수 있다.
        // 그때 유휴를 `100 - 합`으로 그대로 두면 음수가 되어 그릴 수 없다.
        let slices = CPUShare.slices(from: [usage(1, 60), usage(2, 40.3)])

        #expect(!slices.contains { $0.kind == .idle })
        #expect(slices.allSatisfy { $0.percent >= 0 })
    }

    // TC-6
    @Test("상위 개수를 넘는 것은 기타로 묶인다")
    func extrasCollapseIntoOther() {
        let input = (1...7).map { usage(pid_t($0), Double($0)) }  // 1~7%

        let slices = CPUShare.slices(from: input, top: 6)
        let other = slices.first { $0.kind == .other }

        // 가장 작은 1%짜리 하나만 남아 기타가 된다
        #expect(other?.percent == 1)
        #expect(other?.name == "기타")
        #expect(slices.filter { if case .process = $0.kind { true } else { false } }.count == 6)
    }

    // TC-7
    @Test("뒤섞어 넣어도 큰 것부터 나온다")
    func slicesAreSortedRegardlessOfInput() {
        // 조각 순서가 곧 범례 순서다. 들어온 순서를 믿지 않는다.
        let slices = CPUShare.slices(from: [usage(3, 5), usage(1, 30), usage(2, 12)])

        #expect(slices.prefix(3).map(\.percent) == [30, 12, 5])
    }

    // TC-8
    @Test("눈에 안 보일 만큼 작은 기타는 만들지 않는다")
    func tinyRemainderIsDropped() {
        // 0.04%는 "0.0% 기타"로 찍혀 범례에서 자리만 차지한다.
        let input = (1...7).map { usage(pid_t($0), $0 == 7 ? 0.04 : 5) }

        let slices = CPUShare.slices(from: input, top: 6)

        #expect(!slices.contains { $0.kind == .other })
        // 그래도 합은 100이어야 한다 — 버린 몫이 유휴로 넘어간다
        #expect(abs(total(slices) - 100) < 0.000_001)
    }

    // TC-9
    @Test("상위 개수가 0이면 빈 배열이다")
    func zeroTopYieldsNothing() {
        #expect(CPUShare.slices(from: [usage(1, 50)], top: 0).isEmpty)
    }

    // TC-10
    @Test("같은 이름이어도 조각 id가 겹치지 않는다")
    func identifiersAreUnique() {
        // Chrome Helper처럼 같은 이름이 여럿인 것이 흔하다. pid로 갈라야 한다.
        let input = [usage(1, 10, name: "Chrome Helper"),
                     usage(2, 9, name: "Chrome Helper"),
                     usage(3, 8, name: "Chrome Helper")]

        let ids = CPUShare.slices(from: input).map(\.id)

        #expect(ids.count == Set(ids).count)
        #expect(ids == ["p1", "p2", "p3", "idle"])
    }
}
