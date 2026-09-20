import Testing
import Foundation
@testable import SweepKit

/// CPU 탭의 주기 루프.
///
/// 실제 프로세스를 띄우지 않는다 — `sample`을 갈아끼워 주기·상한·취소만 본다.
/// 몇 번 쟀는지 세는 상자. detached 작업에서 올리므로 잠금이 필요하다.
private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func bump() -> Int {
        lock.lock(); defer { lock.unlock() }
        value += 1
        return value
    }

    var count: Int {
        lock.lock(); defer { lock.unlock() }
        return value
    }
}

private func tick(_ pid: pid_t, _ nanoseconds: UInt64) -> ProcessCPUTick {
    ProcessCPUTick(pid: pid, name: "p\(pid)", nanoseconds: nanoseconds)
}

/// 부를 때마다 누적값이 `step`만큼 오르는 가짜 수집기.
///
/// MainActor 스위트 밖에 둔다 — 이 클로저는 `Task.detached` 안에서 불린다.
private func climbing(pids: [pid_t], step: UInt64, counter: Counter)
    -> @Sendable () -> [ProcessCPUTick] {
    {
        let round = UInt64(counter.bump())
        return pids.map { tick($0, round * step * UInt64($0)) }
    }
}

@Suite("CPUModel")
@MainActor
struct CPUModelTests {

    /// `usage`가 채워질 때까지 기다린다. 고정 시간으로 자면 느린 기계에서 흔들린다.
    private func waitForUsage(_ model: CPUModel) async {
        for _ in 0..<200 where model.isWarmingUp {
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    // TC-1
    @Test("재기 전에는 '아직 모른다'는 상태다")
    func startsWarmingUp() {
        let model = CPUModel(sample: { [] })

        // 빈 목록과 구분돼야 한다 — 빈 목록은 "아무도 안 쓴다"는 뜻이다
        #expect(model.isWarmingUp)
        #expect(model.usage.isEmpty)
    }

    // TC-2
    @Test("한 바퀴 돌면 사용률이 채워진다")
    func fillsUsageAfterOneRound() async {
        let counter = Counter()
        let model = CPUModel(
            interval: .milliseconds(10),
            cores: 1,
            sample: climbing(pids: [1, 2, 3], step: 1_000_000, counter: counter))

        let task = Task { await model.run() }
        await waitForUsage(model)
        task.cancel()

        #expect(!model.isWarmingUp)
        #expect(model.usage.count == 3)
        // 누적값이 pid에 비례해 오르게 만들었으므로 큰 pid가 위에 온다
        #expect(model.usage.map(\.pid) == [3, 2, 1])
    }

    // TC-3
    @Test("상한을 넘는 만큼은 잘라 낸다")
    func respectsLimit() async {
        let counter = Counter()
        let model = CPUModel(
            interval: .milliseconds(10),
            limit: 2,
            cores: 1,
            sample: climbing(pids: [1, 2, 3, 4, 5], step: 1_000_000, counter: counter))

        let task = Task { await model.run() }
        await waitForUsage(model)
        task.cancel()

        #expect(model.usage.count == 2)
        #expect(model.usage.map(\.pid) == [5, 4])
    }

    // TC-4
    @Test("취소하면 더 이상 재지 않는다")
    func stopsSamplingAfterCancel() async {
        // CPU를 보는 화면이 안 보이는 동안 CPU를 쓰면 안 된다.
        let counter = Counter()
        let model = CPUModel(
            interval: .milliseconds(10),
            cores: 1,
            sample: climbing(pids: [1], step: 1_000_000, counter: counter))

        let task = Task { await model.run() }
        await waitForUsage(model)
        task.cancel()
        _ = await task.value

        let afterCancel = counter.count
        try? await Task.sleep(for: .milliseconds(80))

        // 취소 뒤로는 한 번도 더 부르지 않아야 한다
        #expect(counter.count == afterCancel)
    }

    // TC-5
    @Test("주입한 수집기만 쓰고 실제 syscall을 타지 않는다")
    func usesInjectedSampler() async {
        let counter = Counter()
        let model = CPUModel(
            interval: .milliseconds(10),
            cores: 1,
            sample: climbing(pids: [42], step: 2_000_000_000, counter: counter))

        let task = Task { await model.run() }
        await waitForUsage(model)
        task.cancel()

        // 실제 프로세스에는 없는 pid다. 진짜 수집기를 탔다면 나올 수 없다.
        #expect(model.usage.map(\.pid) == [42])
        #expect(counter.count >= 2)
    }

    // TC-2 (분모)
    @Test("코어 수가 많을수록 같은 일이 더 작은 비중으로 나온다")
    func coresDivideTheResult() async {
        // 같은 입력을 코어 1개·4개로 각각 돌려 분모가 실제로 먹는지 본다.
        func percent(cores: Int) async -> Double {
            let model = CPUModel(
                interval: .milliseconds(10), limit: 5, cores: cores,
                sample: climbing(pids: [1], step: 1_000_000, counter: Counter()))
            let task = Task { await model.run() }
            await waitForUsage(model)
            task.cancel()
            return model.usage.first?.percent ?? 0
        }

        let one = await percent(cores: 1)
        // 4가 아니라 **터무니없이 큰 수**를 쓴다. 모델은 약속한 구간이 아니라
        // 실제로 흐른 시간으로 나누는데, 테스트를 병렬로 돌리면 그 시간이 실행마다
        // 수십 배씩 달라진다 — 4배 차이는 그 잡음에 묻힌다(실측으로 그렇게 뒤집혔다).
        // 배율을 100만으로 두면 타이밍이 아무리 흔들려도 결론이 바뀌지 않는다.
        let many = await percent(cores: 1_000_000)

        #expect(one > 0)
        // 정확한 나눗셈은 순수 함수 쪽 TC("코어가 8개면 12.5%")가 본다.
        // 여기서 볼 것은 cores가 compute까지 **전달되는가**다.
        // 전달되지 않으면 두 값이 같은 수준이 되어 이 검사에 걸린다.
        #expect(many < one / 1_000, "코어 1개 \(one)% / 100만개 \(many)% — 분모가 안 먹는다")
    }

    // TC-3 (분모)
    @Test("모델이 분모를 밖에서 읽을 수 있다")
    func coresIsReadable() {
        // 화면이 "코어 N개 전체 기준"이라고 쓰려면 이 값을 읽어야 한다.
        // 뷰가 ProcessCPUSampler.coreCount를 따로 읽으면 주입한 테스트·데모에서
        // 화면 문구와 실제 분모가 어긋난다.
        #expect(CPUModel(cores: 3, sample: { [] }).cores == 3)
    }

    // TC-4 (분모)
    @Test("코어 수를 안 주면 이 기계의 코어 수를 쓴다")
    func coresDefaultsToMachine() {
        #expect(CPUModel(sample: { [] }).cores == ProcessCPUSampler.coreCount)
    }

    // TC-6
    @Test("아무도 CPU를 안 쓰면 빈 목록이지만 '모른다'는 아니다")
    func idleMachineIsEmptyButKnown() async {
        // 누적값이 늘지 않는 수집기 — 모든 프로세스가 놀고 있는 상황
        let model = CPUModel(
            interval: .milliseconds(10),
            cores: 1,
            sample: { [ProcessCPUTick(pid: 1, name: "idle", nanoseconds: 5_000)] })

        let task = Task { await model.run() }
        await waitForUsage(model)
        task.cancel()

        #expect(model.usage.isEmpty)
        // 쟀는데 없는 것과 아직 안 잰 것은 다르다
        #expect(!model.isWarmingUp)
    }
}
