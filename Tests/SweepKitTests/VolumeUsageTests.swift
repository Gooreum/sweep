import Testing
import Foundation
@testable import SweepKit

@Suite("VolumeUsage")
struct VolumeUsageTests {

    private static let gb: Int64 = 1_000_000_000

    // TC-1
    @Test("사용량과 사용 비율이 총량에서 여유량을 뺀 값이다")
    func usedIsTotalMinusAvailable() {
        let usage = VolumeUsage(total: 500 * Self.gb, available: 200 * Self.gb)

        #expect(usage.used == 300 * Self.gb)
        #expect(abs(usage.usedFraction - 0.6) < 0.0001)
    }

    // TC-2
    @Test("총량이 0이면 비율은 0이다")
    func zeroTotalDoesNotDivide() {
        let usage = VolumeUsage(total: 0, available: 0)

        // 0으로 나누면 NaN이 나와 막대 폭 계산이 통째로 깨진다
        #expect(usage.usedFraction == 0)
        #expect(usage.used == 0)
        #expect(!usage.usedFraction.isNaN)
    }

    // TC-3
    @Test("여유량이 총량보다 커도 사용량이 음수가 되지 않는다")
    func availableLargerThanTotalClampsToZero() {
        // APFS 컨테이너를 공유하면 여유량이 이 볼륨 총량을 넘어 보고될 수 있다
        let usage = VolumeUsage(total: 100 * Self.gb, available: 140 * Self.gb)

        #expect(usage.used == 0)
        #expect(usage.usedFraction == 0)
    }

    // TC-4
    @Test("디스크가 꽉 차면 비율이 정확히 1이고 1을 넘지 않는다")
    func fullDiskCapsAtOne() {
        let usage = VolumeUsage(total: 512 * Self.gb, available: 0)

        #expect(usage.usedFraction == 1.0)
        #expect(usage.used == 512 * Self.gb)
    }

    // TC-5
    @Test("표시 문자열에 원시 바이트 숫자가 노출되지 않는다")
    func formattedStringsAreHumanReadable() {
        let usage = VolumeUsage(total: 1_000 * Self.gb, available: 250 * Self.gb)

        for text in [usage.formattedTotal, usage.formattedAvailable, usage.formattedUsed] {
            #expect(!text.isEmpty)
            #expect(!text.contains("1000000000000"))
        }
        #expect(usage.formattedTotal.contains("TB") || usage.formattedTotal.contains("GB"))
    }

    // TC-6
    @Test("실제 홈 볼륨을 읽으면 총량이 있고 여유량이 그보다 크지 않다")
    func currentReadsRealVolume() throws {
        let usage = try #require(VolumeUsage.current(),
                                 "홈 볼륨 용량을 읽지 못했다")

        #expect(usage.total > 0)
        #expect(usage.available >= 0)
        #expect(usage.available <= usage.total)
        #expect(usage.usedFraction > 0 && usage.usedFraction <= 1)
    }

    // TC-7
    @Test("없는 경로를 물으면 0이 아니라 nil을 준다")
    func missingPathReturnsNil() {
        let missing = URL(filePath: "/nonexistent-volume-\(UUID().uuidString)/여기없음")

        // 0을 돌려주면 화면에 "0바이트 중 0바이트"가 뜬다.
        // 값을 모른다는 것과 값이 0이라는 것은 다르다.
        #expect(VolumeUsage.current(for: missing) == nil)
    }

    // TC-8
    @Test("같은 값이면 같은 것으로 비교된다")
    func equatableHolds() {
        let a = VolumeUsage(total: 100, available: 40)
        let b = VolumeUsage(total: 100, available: 40)
        let c = VolumeUsage(total: 100, available: 41)

        #expect(a == b)
        #expect(a != c)
    }
}
