import Testing
import Foundation
@testable import SweepKit

private let gb: Int64 = 1_000_000_000

private func usage(free: Int64) -> VolumeUsage {
    VolumeUsage(total: 500 * gb, available: free * gb)
}

/// 격리된 저장소. 실제 `.standard`를 건드리지 않는다.
private func isolated() throws -> (DiskWatchSettings, UserDefaults, () -> Void) {
    let suite = "sweep-test-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    return (DiskWatchSettings(defaults: defaults), defaults,
            { defaults.removePersistentDomain(forName: suite) })
}

@Suite("DiskAlertPolicy")
struct DiskAlertPolicyTests {

    private let policy = DiskAlertPolicy(threshold: 10 * gb, rearmMargin: 2 * gb)

    // TC-1
    @Test("기준보다 적어지면 한 번 알리고, 계속 적어도 다시 알리지 않는다")
    func notifiesOnceWhileLow() {
        var armed = true
        var count = 0
        for free: Int64 in [30, 9, 8, 5, 9] {
            let result = policy.evaluate(usage(free: free), armed: armed)
            armed = result.armed
            if result.notify { count += 1 }
        }
        #expect(count == 1)
        #expect(armed == false)
    }

    // TC-2
    @Test("기준과 기준+여유분 사이를 오르내리면 다시 알리지 않고, 여유분 위로 회복한 뒤 떨어지면 다시 알린다")
    func rearmsOnlyAboveMargin() {
        var armed = true
        var notified: [Int64] = []
        for free: Int64 in [9, 11, 9, 11, 12, 9] {
            let result = policy.evaluate(usage(free: free), armed: armed)
            armed = result.armed
            if result.notify { notified.append(free) }
        }
        // 첫 9에서 한 번, 12(= 10 + 2)로 회복한 뒤의 9에서 한 번
        #expect(notified == [9, 9])
        #expect(notified.count == 2)
    }

    // TC-3
    @Test("기준과 같으면 부족이 아니다")
    func thresholdItselfIsNotLow() {
        #expect(policy.evaluate(usage(free: 10), armed: true) == (false, true))
    }

    // TC-4
    @Test("사용량을 읽지 못하면 알리지도 않고 상태도 바꾸지 않는다")
    func unknownUsageChangesNothing() {
        #expect(policy.evaluate(nil, armed: true) == (false, true))
        #expect(policy.evaluate(nil, armed: false) == (false, false))
    }
}

@Suite("DiskWatchSettings")
struct DiskWatchSettingsTests {

    // TC-5
    @Test("처음에는 꺼져 있고 기준 10GB, 묻지 않았고, 장전돼 있다")
    func defaults() throws {
        let (settings, _, cleanup) = try isolated()
        defer { cleanup() }

        #expect(settings.enabled == false)
        #expect(settings.thresholdGB == 10)
        #expect(settings.consentAsked == false)
        #expect(settings.armed == true)
    }

    // TC-6
    @Test("저장한 값을 다시 만든 저장소에서 그대로 읽는다")
    func persists() throws {
        let (settings, defaults, cleanup) = try isolated()
        defer { cleanup() }

        settings.enabled = true
        settings.thresholdGB = 20
        settings.consentAsked = true
        settings.armed = false

        let reread = DiskWatchSettings(defaults: defaults)
        #expect(reread.enabled == true)
        #expect(reread.thresholdGB == 20)
        #expect(reread.consentAsked == true)
        #expect(reread.armed == false)
    }
}

@Suite("DiskWatcher")
@MainActor
struct DiskWatcherTests {

    /// 주기를 길게 둔다. 자동 회차가 끼어들면 `tick()` 횟수를 셀 수 없다.
    private func watcher(
        _ settings: DiskWatchSettings,
        free: @escaping @MainActor () -> Int64?,
        interval: Duration = .seconds(3600),
        onNotify: @escaping @MainActor (VolumeUsage) -> Void
    ) -> DiskWatcher {
        DiskWatcher(settings: settings, interval: interval,
                    readVolumeUsage: { free().map { usage(free: $0) } },
                    notify: onNotify)
    }

    // TC-7
    @Test("꺼져 있으면 tick이 알림을 부르지 않는다")
    func disabledDoesNotNotify() throws {
        let (settings, _, cleanup) = try isolated()
        defer { cleanup() }
        var count = 0
        let sut = watcher(settings, free: { 1 }) { _ in count += 1 }
        sut.isAuthorized = true

        sut.tick()

        #expect(count == 0)
        #expect(sut.isRunning == false)
    }

    // TC-8
    @Test("권한이 없으면 켜져 있어도 돌지 않는다")
    func unauthorizedDoesNotRun() throws {
        let (settings, _, cleanup) = try isolated()
        defer { cleanup() }
        var count = 0
        let sut = watcher(settings, free: { 1 }) { _ in count += 1 }
        sut.isEnabled = true

        sut.tick()

        #expect(count == 0)
        #expect(sut.isRunning == false)
    }

    // TC-9
    @Test("켜고 권한이 있으면 부족할 때 한 번만 알리고, 끄면 멈춘다")
    func notifiesOnceThenStops() throws {
        let (settings, _, cleanup) = try isolated()
        defer { cleanup() }
        var count = 0
        let sut = watcher(settings, free: { 3 }) { _ in count += 1 }
        sut.isEnabled = true
        sut.isAuthorized = true
        #expect(sut.isRunning)

        sut.tick()
        sut.tick()
        sut.tick()
        #expect(count == 1)

        sut.isEnabled = false
        #expect(sut.isRunning == false)
        #expect(settings.enabled == false)
    }

    // TC-10
    @Test("장전 상태가 저장돼 다시 만든 감시기에서도 같은 상황에 알리지 않는다")
    func armedSurvivesRelaunch() throws {
        let (settings, defaults, cleanup) = try isolated()
        defer { cleanup() }
        var count = 0
        let first = watcher(settings, free: { 3 }) { _ in count += 1 }
        first.isEnabled = true
        first.isAuthorized = true
        first.tick()
        first.stop()

        let second = watcher(DiskWatchSettings(defaults: defaults), free: { 3 }) { _ in count += 1 }
        second.isAuthorized = true
        #expect(second.isEnabled)
        second.tick()
        second.stop()

        #expect(count == 1)
    }

    // TC-11
    @Test("기준을 바꾸면 다시 장전된다")
    func changingThresholdRearms() throws {
        let (settings, _, cleanup) = try isolated()
        defer { cleanup() }
        var count = 0
        let sut = watcher(settings, free: { 15 }) { _ in count += 1 }
        sut.isEnabled = true
        sut.isAuthorized = true
        sut.thresholdGB = 20
        sut.tick()
        sut.tick()
        sut.thresholdGB = 50
        sut.tick()
        sut.stop()

        #expect(count == 2)
        #expect(settings.thresholdGB == 50)
    }

    // TC-12
    @Test("읽지 못한 회차는 건너뛴다")
    func skipsUnknownUsage() throws {
        let (settings, _, cleanup) = try isolated()
        defer { cleanup() }
        var count = 0
        let sut = watcher(settings, free: { nil }) { _ in count += 1 }
        sut.isEnabled = true
        sut.isAuthorized = true

        #expect(sut.tick() == false)
        sut.stop()
        #expect(count == 0)
        #expect(settings.armed == true)
    }

    // TC-13
    @Test("주기마다 저절로 돌고, stop 뒤에는 더 읽지 않는다")
    func loopRunsAndStops() async throws {
        let (settings, _, cleanup) = try isolated()
        defer { cleanup() }
        var reads = 0
        let sut = watcher(settings, free: { reads += 1; return 100 },
                          interval: .milliseconds(10)) { _ in }
        sut.isEnabled = true
        sut.isAuthorized = true

        try await Task.sleep(for: .milliseconds(100))
        sut.stop()
        let afterStop = reads
        try await Task.sleep(for: .milliseconds(50))

        #expect(afterStop >= 1)
        #expect(reads == afterStop)
    }
}
