import Testing
import Foundation
@testable import SweepKit

@Suite("RemovalReport")
struct RemovalReportTests {

    private func item(_ name: String, size: Int64) -> CleanupItem {
        CleanupItem(url: URL(filePath: "/private/tmp/\(name)"),
                    size: size, category: .devCache, safety: .safe)
    }

    // TC-1
    @Test("failureReason이 nil이면 성공으로 판정된다")
    func nilReasonMeansSuccess() {
        let outcome = RemovalOutcome(item: item("a", size: 100), failureReason: nil)
        #expect(outcome.succeeded)
    }

    // TC-2
    @Test("failureReason이 있으면 실패이며 사유가 보존된다")
    func reasonMeansFailure() {
        let outcome = RemovalOutcome(item: item("b", size: 100),
                                     failureReason: "보호된 경로입니다: /etc/passwd")
        #expect(!outcome.succeeded)
        #expect(outcome.failureReason == "보호된 경로입니다: /etc/passwd")
    }

    // TC-3 · TC-4
    @Test("성공과 실패가 분리되고 회수량은 성공분만 합산된다")
    func separatesOutcomesAndSumsOnlySuccesses() {
        let report = RemovalReport(outcomes: [
            RemovalOutcome(item: item("ok-1", size: 1_000), failureReason: nil),
            RemovalOutcome(item: item("ok-2", size: 2_500), failureReason: nil),
            RemovalOutcome(item: item("nope", size: 9_999_999), failureReason: "권한 없음"),
        ])

        #expect(report.succeeded.count == 2)
        #expect(report.failed.count == 1)
        // 실패한 9,999,999바이트가 섞이면 안 된다
        #expect(report.reclaimedBytes == 3_500)
    }

    // TC-5
    @Test("빈 report는 회수량이 0이다")
    func emptyReportIsZero() {
        let report = RemovalReport(outcomes: [])

        #expect(report.reclaimedBytes == 0)
        #expect(report.succeeded.isEmpty)
        #expect(report.failed.isEmpty)
    }

    // TC-6
    @Test("전부 실패하면 회수량이 0이다")
    func allFailedReclaimsNothing() {
        let report = RemovalReport(outcomes: [
            RemovalOutcome(item: item("x", size: 500_000), failureReason: "실패"),
            RemovalOutcome(item: item("y", size: 700_000), failureReason: "실패"),
        ])

        #expect(report.reclaimedBytes == 0)
        #expect(report.failed.count == 2)
    }

    // TC-7
    @Test("회수량이 사람이 읽는 단위로 표시된다")
    func formatsReclaimedSize() {
        let report = RemovalReport(outcomes: [
            RemovalOutcome(item: item("big", size: 5_000_000_000), failureReason: nil),
        ])

        let text = report.formattedReclaimed
        #expect(!text.contains("5000000000"))
        #expect(text.contains("GB"))
    }

    // TC-8
    @Test("RemovalReport가 Sendable 경계를 넘어 전달된다")
    func reportCrossesSendableBoundary() async {
        let report = RemovalReport(outcomes: [
            RemovalOutcome(item: item("z", size: 42), failureReason: nil),
        ])

        // 액터 경계를 넘겨 Sendable 적합성을 실제로 행사한다
        let bytes = await Task.detached { report.reclaimedBytes }.value
        #expect(bytes == 42)
    }
}
