import Testing
import Foundation
@testable import SweepKit

@Suite("ProgressDisplay")
struct ProgressDisplayTests {

    // TC-1
    @Test("남은 시간이 1분 경계에서 표기가 바뀐다")
    func readableSwitchesAtMinuteBoundary() {
        #expect(ProgressDisplay.readable(seconds: 0) == "0초")
        #expect(ProgressDisplay.readable(seconds: 59) == "59초")
        // 60을 넘겨도 초만 보여주면 "125초 남음"처럼 읽기 나빠진다
        #expect(ProgressDisplay.readable(seconds: 60) == "1분 0초")
        #expect(ProgressDisplay.readable(seconds: 61) == "1분 1초")
        #expect(ProgressDisplay.readable(seconds: 125) == "2분 5초")
        #expect(ProgressDisplay.readable(seconds: 3_600) == "60분 0초")
    }

    @Test("남은 시간이 음수여도 음수로 표기되지 않는다")
    func readableClampsNegative() {
        // 추정이 튀어 음수가 나올 수 있다. "-3초 남음"은 뜻이 없다.
        #expect(ProgressDisplay.readable(seconds: -3) == "0초")
        #expect(!ProgressDisplay.readable(seconds: -120).contains("-"))
    }

    // TC-2
    @Test("링 비율이 0~1을 벗어나지 않는다")
    func ringFractionStaysInRange() {
        #expect(ProgressDisplay.ringFraction(percent: 0) == 0)
        #expect(ProgressDisplay.ringFraction(percent: 50) == 0.5)
        #expect(ProgressDisplay.ringFraction(percent: 100) == 1)

        // 자르지 않으면 링이 두 바퀴를 돌아 겹쳐 그려진다
        #expect(ProgressDisplay.ringFraction(percent: 120) == 1)
        // 음수면 trim이 아무것도 그리지 않아 링이 사라진다
        #expect(ProgressDisplay.ringFraction(percent: -10) == 0)

        for percent in stride(from: -50, through: 200, by: 7) {
            let value = ProgressDisplay.ringFraction(percent: percent)
            #expect(value >= 0 && value <= 1, "percent \(percent) → \(value)")
        }
    }

    @Test("링 비율이 퍼센트에 따라 단조 증가한다")
    func ringFractionIsMonotonic() {
        var previous = -1.0
        for percent in 0...100 {
            let value = ProgressDisplay.ringFraction(percent: percent)
            #expect(value >= previous)
            previous = value
        }
    }
}
