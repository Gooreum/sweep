import Foundation
import Testing
@testable import SweepKit

/// 항목에 붙는 날짜 표시.
///
/// 값이 없을 때 **빈 문자열을 지어내지 않는 것**이 이 스위트의 핵심이다.
/// "만듦"만 덩그러니 찍히면 사용자는 날짜를 못 읽은 것이 아니라 날짜가 없는 줄 안다.
@Suite("FileDates 날짜 표시")
struct FileDatesTests {

    /// 자정 근처 경계에서 날짜 계산이 흔들리지 않도록 고정 시각을 쓴다.
    private let now = Date(timeIntervalSince1970: 1_780_000_000)  // 2026-06-08 무렵

    private func daysAgo(_ days: Int) -> Date {
        now.addingTimeInterval(-Double(days) * 86_400)
    }

    // TC-1
    @Test("만든 날은 실제 날짜로 찍힌다")
    func createdLabelFormats() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let created = try #require(calendar.date(from: DateComponents(
            year: 2026, month: 5, day: 18, hour: 12)))

        let dates = FileDates(created: created)

        #expect(dates.createdLabel(calendar: calendar) == "2026.05.18 만듦")
    }

    // TC-2
    @Test("만든 날이 없으면 문구를 만들지 않는다")
    func createdLabelNil() {
        // "만듦"만 남은 줄은 정보가 아니라 잡음이다.
        #expect(FileDates(created: nil).createdLabel() == nil)
        #expect(FileDates.unknown.createdLabel() == nil)
    }

    // TC-3
    @Test("오늘 쓴 것은 '오늘 사용'이다")
    func lastUsedToday() {
        #expect(FileDates(lastUsed: now).lastUsedLabel(now: now) == "오늘 사용")
        #expect(FileDates(lastUsed: daysAgo(0)).lastUsedLabel(now: now) == "오늘 사용")
    }

    // TC-4
    @Test("29일과 30일 사이에서 일→개월로 넘어간다")
    func lastUsedMonthBoundary() {
        #expect(FileDates(lastUsed: daysAgo(29)).lastUsedLabel(now: now) == "29일 전 사용")
        #expect(FileDates(lastUsed: daysAgo(30)).lastUsedLabel(now: now) == "1개월 전 사용")
    }

    // TC-5
    @Test("364일과 365일 사이에서 개월→년으로 넘어간다")
    func lastUsedYearBoundary() {
        #expect(FileDates(lastUsed: daysAgo(364)).lastUsedLabel(now: now) == "12개월 전 사용")
        #expect(FileDates(lastUsed: daysAgo(365)).lastUsedLabel(now: now) == "1년 전 사용")
    }

    // TC-6
    @Test("미래 시각이어도 음수를 찍지 않는다")
    func lastUsedInFuture() {
        // 시계가 어긋났거나 스캔 도중에 쓰인 경우다. "-1일 전 사용"은 버그로 보인다.
        let future = now.addingTimeInterval(3 * 86_400)

        #expect(FileDates(lastUsed: future).lastUsedLabel(now: now) == "방금 사용")
    }

    // TC-7
    @Test("마지막 사용이 없으면 문구를 만들지 않는다")
    func lastUsedNil() {
        #expect(FileDates(lastUsed: nil).lastUsedLabel(now: now) == nil)
    }

    // TC-8
    @Test("툴팁은 두 날짜를 한 줄로 잇는다")
    func tooltipJoinsBoth() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let created = try #require(calendar.date(from: DateComponents(
            year: 2026, month: 5, day: 18, hour: 12)))
        let used = try #require(calendar.date(from: DateComponents(
            year: 2026, month: 5, day: 19, hour: 12)))

        let line = FileDates(created: created, lastUsed: used).tooltipLine(calendar: calendar)

        #expect(line == "만든 날 2026.05.18 · 마지막 사용 2026.05.19")
    }

    // TC-8b
    @Test("한쪽만 있으면 있는 쪽만 나온다")
    func tooltipPartial() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let used = try #require(calendar.date(from: DateComponents(
            year: 2026, month: 5, day: 19, hour: 12)))

        let line = FileDates(lastUsed: used).tooltipLine(calendar: calendar)

        // 없는 쪽을 "만든 날 —"처럼 채우지 않는다.
        #expect(line == "마지막 사용 2026.05.19")
    }

    // TC-9
    @Test("둘 다 없으면 툴팁 줄 자체가 없다")
    func tooltipNil() {
        #expect(FileDates.unknown.tooltipLine() == nil)
    }

    // TC-10
    @Test("같은 값은 같은 것으로 센다")
    func hashable() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let set: Set<FileDates> = [
            FileDates(created: date, lastUsed: date),
            FileDates(created: date, lastUsed: date),
        ]

        #expect(set.count == 1)
        #expect(FileDates(created: date) != FileDates(lastUsed: date))
    }
}
