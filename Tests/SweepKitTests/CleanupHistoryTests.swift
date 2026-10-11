import Testing
import Foundation
@testable import SweepKit

@Suite("CleanupHistory")
struct CleanupHistoryTests {

    private func item(_ name: String, size: Int64, category: ScanCategory = .devCache) -> CleanupItem {
        CleanupItem(url: URL(filePath: "/private/tmp/\(name)"),
                    size: size, category: category, safety: .safe)
    }

    /// 성공 2건(1_000 + 2_500) · 실패 1건(9_999_999).
    private var mixed: RemovalReport {
        RemovalReport(outcomes: [
            RemovalOutcome(item: item("ok-1", size: 1_000), failureReason: nil),
            RemovalOutcome(item: item("ok-2", size: 2_500, category: .xcode), failureReason: nil),
            RemovalOutcome(item: item("nope", size: 9_999_999), failureReason: "권한 없음"),
        ])
    }

    /// 격리된 저장소. 실제 `.standard`를 건드리지 않는다.
    private func isolated() throws -> (UserDefaults, () -> Void) {
        let suite = "sweep-test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        return (defaults, { defaults.removePersistentDomain(forName: suite) })
    }

    private func day(_ n: Int, from now: Date) -> Date { now.addingTimeInterval(-Double(n) * 86_400) }

    // TC-1
    @Test("회차 하나를 기록하면 성공분만 합산되고 카테고리별로 나뉜다")
    func recordsOneRound() throws {
        let (defaults, cleanup) = try isolated()
        defer { cleanup() }
        let history = CleanupHistory(defaults: defaults)

        let record = history.record(mixed, at: Date(timeIntervalSince1970: 1_000))

        #expect(history.records.count == 1)
        #expect(record?.reclaimedBytes == 3_500)
        #expect(record?.succeededCount == 2)
        #expect(record?.failedCount == 1)
        #expect(record?.bytesByCategory == ["devCache": 1_000, "xcode": 2_500])
    }

    // TC-2
    @Test("두 번 기록하면 누적 합과 마지막 날짜가 요약에 담긴다")
    func accumulatesAcrossRounds() throws {
        let (defaults, cleanup) = try isolated()
        defer { cleanup() }
        let history = CleanupHistory(defaults: defaults)
        let first = Date(timeIntervalSince1970: 1_000)
        let second = Date(timeIntervalSince1970: 2_000)

        history.record(mixed, at: first)
        history.record(mixed, at: second)

        #expect(history.summary.totalReclaimedBytes == 7_000)
        #expect(history.summary.lastCleanup == second)
    }

    // TC-3
    @Test("같은 저장소로 다시 만들면 기록이 복원된다")
    func restoresFromDefaults() throws {
        let (defaults, cleanup) = try isolated()
        defer { cleanup() }
        let date = Date(timeIntervalSince1970: 1_000)
        CleanupHistory(defaults: defaults).record(mixed, at: date)

        // 앱을 다시 켠 상황
        let reopened = CleanupHistory(defaults: defaults)

        #expect(reopened.records.count == 1)
        #expect(reopened.summary == CleanupSummary(totalReclaimedBytes: 3_500, lastCleanup: date))
    }

    // TC-4
    @Test("전부 실패한 회차는 기록하지 않는다")
    func skipsRoundsWithNoSuccess() throws {
        let (defaults, cleanup) = try isolated()
        defer { cleanup() }
        let history = CleanupHistory(defaults: defaults)
        let allFailed = RemovalReport(outcomes: [
            RemovalOutcome(item: item("a", size: 1_000), failureReason: "보호된 경로입니다"),
        ])

        let record = history.record(allFailed)

        // 지운 것이 없는데 "마지막 정리 오늘"이 되면 거짓이다
        #expect(record == nil)
        #expect(history.records.isEmpty)
        #expect(history.summary == .empty)
    }

    // TC-5
    @Test("기록이 없으면 상태 줄이 nil이다")
    func emptySummaryHasNoLine() {
        #expect(CleanupSummary.empty.statusLine() == nil)
    }

    // TC-6
    @Test("상태 줄은 누적 용량과 마지막 정리 시점을 한 줄에 쓴다")
    func statusLineFormat() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let summary = CleanupSummary(totalReclaimedBytes: 12_400_000_000,
                                     lastCleanup: day(3, from: now))

        #expect(summary.statusLine(now: now) == "지금까지 12.4 GB 확보 · 마지막 정리 3일 전")
    }

    // TC-7
    @Test("상대 시점 계단이 FileDates와 같다")
    func relativeSteps() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        // 시계가 어긋나 미래에 찍힌 기록. 한 시간 뒤는 0일로 잘려 "오늘"이고, 하루 이상이면 "방금".
        #expect(CleanupSummary.relative(now.addingTimeInterval(3_600), now: now) == "오늘")
        #expect(CleanupSummary.relative(day(-2, from: now), now: now) == "방금")
        #expect(CleanupSummary.relative(day(0, from: now), now: now) == "오늘")
        #expect(CleanupSummary.relative(day(29, from: now), now: now) == "29일 전")
        #expect(CleanupSummary.relative(day(30, from: now), now: now) == "1개월 전")
        #expect(CleanupSummary.relative(day(45, from: now), now: now) == "1개월 전")
        #expect(CleanupSummary.relative(day(365, from: now), now: now) == "1년 전")
    }

    // TC-8
    @Test("재방문 문구는 2주 이상 지났고 지울 safe 항목이 있을 때만 나온다")
    func nudgeOnlyWhenStaleAndWorthwhile() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let gb: Int64 = 1_000_000_000

        let recent = CleanupSummary(totalReclaimedBytes: 1, lastCleanup: day(13, from: now))
        #expect(recent.nudgeLine(now: now, safeBytes: gb) == nil)

        let stale = CleanupSummary(totalReclaimedBytes: 1, lastCleanup: day(14, from: now))
        #expect(stale.nudgeLine(now: now, safeBytes: 0) == nil)
        let line = stale.nudgeLine(now: now, safeBytes: gb)
        #expect(line?.contains("14일") == true)
        #expect(line?.contains("1 GB") == true)

        #expect(CleanupSummary.empty.nudgeLine(now: now, safeBytes: gb) == nil)
    }

    // TC-9
    @Test("저장된 기록에 파일 경로가 들어 있지 않다")
    func storesNoPaths() throws {
        let (defaults, cleanup) = try isolated()
        defer { cleanup() }
        CleanupHistory(defaults: defaults).record(mixed)

        let data = try #require(defaults.data(forKey: CleanupHistory.key))
        let json = try #require(String(data: data, encoding: .utf8))

        // 숫자만 남긴다. 무엇을 지웠는지는 저장하지 않는다.
        #expect(!json.contains("/private/tmp"))
        #expect(!json.contains("ok-1"))
    }
}
