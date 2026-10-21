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

/// 부를 때마다 사용자 30·시스템 20·유휴 50틱씩 오르는 가짜 커널.
private func climbingLoad(counter: Counter) -> @Sendable () -> CPULoadTicks? {
    {
        let round = UInt32(counter.bump())
        return CPULoadTicks(user: round * 30, system: round * 20, idle: round * 50, nice: 0)
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

    @Test("기계 전체 부하를 같은 주기에 커널 값으로 채운다")
    func loadComesFromKernelTicks() async {
        let model = CPUModel(
            interval: .milliseconds(10), cores: 1,
            sample: climbing(pids: [1], step: 1_000_000, counter: Counter()),
            loadSample: climbingLoad(counter: Counter()))

        let task = Task { await model.run() }
        await waitForUsage(model)
        task.cancel()

        // 프로세스 합에서 셈하지 않는다 — 주입한 틱 그대로의 비율이어야 한다
        #expect(model.load == SystemCPULoad(user: 30, system: 20, idle: 50))
    }

    @Test("커널 값을 못 읽으면 부하는 nil이다")
    func missingKernelLoadStaysNil() async {
        // 프로세스 합으로 지어내면 root 프로세스 몫이 유휴로 둔갑한다
        let model = CPUModel(
            interval: .milliseconds(10), cores: 1,
            sample: climbing(pids: [1], step: 1_000_000, counter: Counter()),
            loadSample: { nil })

        let task = Task { await model.run() }
        await waitForUsage(model)
        task.cancel()

        #expect(!model.isWarmingUp)
        #expect(model.load == nil)
    }

    @Test("목록 합계는 상한으로 자르기 전 전부를 코어 수로 나눈다")
    func ownTotalCountsEveryProcess() async {
        // 상위 1개만 보여줘도 합계에는 둘 다 들어가야 "목록에 없는 몫"이 부풀지 않는다
        let model = CPUModel(
            interval: .milliseconds(10), limit: 1, cores: 2,
            sample: climbing(pids: [1, 2], step: 1_000_000, counter: Counter()),
            loadSample: { nil })

        let task = Task { await model.run() }
        await waitForUsage(model)
        task.cancel()

        let shown = model.usage.reduce(0) { $0 + $1.percent }
        #expect(model.usage.count == 1)
        #expect(model.ownTotal * 2 > shown)
    }

    @Test("목록에 없는 몫은 기계 전체 차이에 코어 수를 곱한다")
    func unlistedPercentUsesCoreUnits() async throws {
        // 커널: 사용 50% (가짜 틱 30·20·50). 코어 4개.
        // 프로세스 하나가 아주 조금만 써서 ownTotal은 50보다 훨씬 작다.
        let model = CPUModel(
            interval: .milliseconds(10), cores: 4,
            sample: climbing(pids: [1], step: 1, counter: Counter()),
            loadSample: climbingLoad(counter: Counter()))

        let task = Task { await model.run() }
        await waitForUsage(model)
        task.cancel()

        let unlisted = try #require(model.unlistedPercent)
        #expect(abs(unlisted - (50 - model.ownTotal) * 4) < 0.0001)
        // 표에는 합계 행이 실제로 들어 있다
        #expect(model.rows.contains(.unlisted(percent: unlisted)))
    }

    @Test("목록 합이 커널 사용량보다 커도 음수가 되지 않는다")
    func unlistedNeverNegative() async throws {
        // 측정 시차로 내 프로세스 합이 커널 합계를 넘는 순간이 있다.
        // 한 바퀴에 1000초치를 쓴다고 넣는다 — 기계가 바빠 구간이 몇 초로 늘어도
        // 프로세스 합이 커널 사용량(50%)을 확실히 넘는다.
        let model = CPUModel(
            interval: .milliseconds(10), cores: 1,
            sample: climbing(pids: [1], step: 1_000_000_000_000, counter: Counter()),
            loadSample: climbingLoad(counter: Counter()))

        let task = Task { await model.run() }
        await waitForUsage(model)
        task.cancel()

        #expect(try #require(model.unlistedPercent) == 0)
    }

    // 선택과 자세한 정보
    @Test("행을 누르면 그 프로그램의 자세한 정보가 채워진다")
    func selectFillsDetails() {
        let model = CPUModel(detailsReader: { fakeDetailsSendable($0) })
        model.select(42)
        #expect(model.selectedPID == 42)
        #expect(model.details?.pid == 42)
    }

    @Test("같은 행을 다시 누르면 선택이 풀린다")
    func selectTwiceClears() {
        let model = CPUModel(detailsReader: { fakeDetailsSendable($0) })
        model.select(42)
        model.select(42)
        #expect(model.selectedPID == nil)
        #expect(model.details == nil)
    }

    @Test("다른 행을 누르면 선택이 옮겨 간다")
    func selectOtherMoves() {
        let model = CPUModel(detailsReader: { fakeDetailsSendable($0) })
        model.select(1)
        model.select(2)
        #expect(model.selectedPID == 2)
        #expect(model.details?.pid == 2)
    }

    @Test("고른 프로그램이 끝나면 선택은 남고 정보만 비어 '끝났다'를 말할 수 있다")
    func vanishedProcessKeepsSelection() {
        let model = CPUModel(detailsReader: { _ in nil })
        model.select(7)
        #expect(model.selectedPID == 7)
        #expect(model.details == nil)
    }

    @Test("주기마다 고른 프로그램의 정보를 다시 읽는다")
    func refreshesDetailsEachRound() async {
        let counter = Counter()
        let model = CPUModel(
            interval: .milliseconds(10), cores: 1,
            sample: climbing(pids: [1], step: 1_000_000, counter: counter),
            detailsReader: { pid in fakeDetailsSendable(pid, memory: UInt64(counter.bump())) })
        model.select(1)
        let first = model.details?.memoryBytes

        let task = Task { await model.run() }
        await waitForUsage(model)
        // 정보 다시 읽기는 사용률이 채워진 **뒤** 별도 작업에서 끝난다. 곧바로 취소하면
        // 기계가 바쁠 때 읽기가 끝나기 전에 검사해 흔들린다.
        for _ in 0..<200 where model.details?.memoryBytes == first {
            try? await Task.sleep(for: .milliseconds(5))
        }
        task.cancel()

        #expect(model.details?.memoryBytes != first)
    }

    @Test("고른 게 없으면 정보를 읽지 않는다")
    func noSelectionNoRead() async {
        let reads = Counter()
        let model = CPUModel(
            interval: .milliseconds(10), cores: 1,
            sample: climbing(pids: [1], step: 1_000_000, counter: Counter()),
            detailsReader: { pid in _ = reads.bump(); return fakeDetailsSendable(pid) })
        let task = Task { await model.run() }
        await waitForUsage(model)
        task.cancel()
        #expect(reads.count == 0)
    }

    @Test("마우스를 올린 동안은 순위가 바뀌어도 줄 순서가 그대로이고, 나가면 사용률순으로 돌아온다")
    func holdingOrderKeepsRowsStill() async throws {
        let rates = FlippingRates()
        let model = CPUModel(
            interval: .milliseconds(10), cores: 1,
            sample: { rates.next() },
            loadSample: { nil })
        let task = Task { await model.run() }
        defer { task.cancel() }
        await waitForUsage(model)
        #expect(model.rows.map(\.id) == ["p1", "p2"])   // 처음에는 1번이 많이 쓴다

        model.holdOrder(true)
        rates.flip()                                     // 이제 2번이 더 많이 쓴다
        for _ in 0..<400 where model.usage.first?.pid != 2 {
            try? await Task.sleep(for: .milliseconds(5))
        }
        try #require(model.usage.first?.pid == 2, "순위가 바뀌지 않아 시험이 성립하지 않는다")

        #expect(model.rows.map(\.id) == ["p1", "p2"], "붙잡아 둔 동안 줄이 움직였다")

        model.holdOrder(false)
        #expect(model.rows.map(\.id) == ["p2", "p1"])
    }
}

/// 부를 때마다 pid 1·2의 누적값이 오르는 가짜 수집기. `flip` 뒤에는 오르는 속도가 서로 바뀐다.
private final class FlippingRates: @unchecked Sendable {
    private let lock = NSLock()
    private var flipped = false
    private var totals: [pid_t: UInt64] = [1: 0, 2: 0]

    func flip() { lock.lock(); flipped = true; lock.unlock() }

    func next() -> [ProcessCPUTick] {
        lock.lock(); defer { lock.unlock() }
        let step: [pid_t: UInt64] = flipped ? [1: 1_000_000, 2: 4_000_000] : [1: 4_000_000, 2: 1_000_000]
        for (pid, add) in step { totals[pid, default: 0] += add }
        return totals.map { ProcessCPUTick(pid: $0.key, name: "p\($0.key)", nanoseconds: $0.value) }
    }
}

private func fakeDetailsSendable(_ pid: pid_t, memory: UInt64 = 100) -> ProcessDetails {
    ProcessDetails(pid: pid, name: "fileproviderd", isMine: true, memoryBytes: memory)
}
