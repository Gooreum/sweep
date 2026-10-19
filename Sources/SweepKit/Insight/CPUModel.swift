import Foundation

/// CPU 탭의 상태. 주기마다 한 번씩 재서 상위 몇 개를 들고 있는다.
///
/// `ScanModel`이 아니다 — 스캔·선택·삭제가 없는 **읽기 전용 관찰**이라
/// `DiskMapModel`과 같은 자리에 같은 모양으로 둔다. SwiftUI를 import하지 않는
/// 이유도 같다: 뷰 없이 테스트할 수 있어야 한다.
@MainActor
@Observable
public final class CPUModel {

    /// 사용률 내림차순, 최대 `limit`개.
    public private(set) var usage: [ProcessUsage] = []

    /// 기계 전체의 사용자·시스템·유휴. 커널에서 읽어 **모든 계정**을 담는다.
    ///
    /// 못 읽었으면 nil — 화면은 이 칸을 숨긴다. 프로세스 합으로 지어내지 않는다:
    /// 그렇게 셈하면 root 프로세스 몫이 유휴로 둔갑한다.
    public private(set) var load: SystemCPULoad?

    /// 읽은 프로세스 **전부**(상한 `limit`으로 자르기 전)를 기계 전체 100 기준으로 환산한 합.
    ///
    /// `load.used`에서 이것을 빼면 목록에 없는 몫 — root·다른 계정 프로세스 — 이 나온다.
    /// 상위 20개만 더하면 나머지 300개의 몫까지 "목록에 없음"으로 잘못 넘어간다.
    public private(set) var ownTotal: Double = 0

    /// 첫 두 샘플이 아직 모이지 않았다.
    ///
    /// **빈 목록과 다르다.** 빈 목록은 "아무도 CPU를 안 쓴다"이고 이것은
    /// "아직 모른다"이다. 둘을 같은 화면으로 그리면 준비 중인 2초 동안
    /// 앱이 거짓말을 한다.
    public private(set) var isWarmingUp = true

    /// 논리 코어 수. 프로세스 사용률의 상한(코어 수 × 100%)이고, `ownTotal`의 분모다.
    ///
    /// `public`인 이유는 화면이 "코어가 N개라 최대 N00%"라고 밝혀야 하기 때문이다.
    /// 뷰가 `ProcessCPUSampler.coreCount`를 따로 읽으면 주입으로 코어 수를 바꾼
    /// 테스트·데모에서 화면 문구와 실제 분모가 어긋난다.
    public let cores: Int

    private let interval: Duration
    private let limit: Int
    private let sample: @Sendable () -> [ProcessCPUTick]
    private let loadSample: @Sendable () -> CPULoadTicks?

    /// `sample`을 갈아끼울 수 있게 뒀다 — 실제 프로세스를 띄우지 않고
    /// 주기·상한·취소를 검사하기 위해서다. `ItemActions`가 Finder 호출을
    /// 바꿔 끼울 수 있게 둔 것과 같은 방식이다.
    public init(
        interval: Duration = .seconds(2),
        limit: Int = 20,
        cores: Int = ProcessCPUSampler.coreCount,
        sample: @escaping @Sendable () -> [ProcessCPUTick] = ProcessCPUSampler.tick,
        loadSample: @escaping @Sendable () -> CPULoadTicks? = SystemCPULoad.tick
    ) {
        self.interval = interval
        self.limit = limit
        self.cores = cores
        self.sample = sample
        self.loadSample = loadSample
    }

    /// 뷰의 `.task`가 붙잡는다. 탭을 떠나면 SwiftUI가 취소하므로 따로 멈출 필요가 없다 —
    /// **CPU를 보는 화면이 안 보이는 동안 CPU를 쓰면 안 된다.**
    ///
    /// 한 바퀴에 한 번만 잰다. 직전 샘플을 들고 있어서, 주기마다 두 번씩
    /// 재는 낭비를 하지 않는다.
    public func run() async {
        let clock = ContinuousClock()
        var (previous, previousLoad) = await measure()
        var previousAt = clock.now

        while !Task.isCancelled {
            try? await Task.sleep(for: interval)
            // 자는 동안 취소됐으면 여기서 끝낸다. 취소된 뒤에 한 번 더 재면
            // 화면을 떠난 뒤에도 500개를 훑는다.
            guard !Task.isCancelled else { return }

            let (current, currentLoad) = await measure()
            let now = clock.now

            // **`interval`이 아니라 실제로 흐른 시간으로 나눈다.**
            // `Task.sleep`은 최소 시간만 보장한다 — 기계가 바쁘면 더 오래 잔다.
            // 그때 분모를 약속한 값으로 두면 사용률이 그만큼 부풀려진다.
            // 실측: 테스트를 병렬로 돌려 기계가 바쁠 때 12.5%짜리가 68.7%로 찍혔다.
            // 하필 CPU가 바쁠 때 틀리는 값이라, 이 화면을 볼 이유가 있는 순간에 틀린다.
            let all = ProcessUsage.compute(from: previous, to: current, over: now - previousAt)
            usage = Array(all.prefix(limit))
            ownTotal = cores > 0 ? all.reduce(0) { $0 + $1.percent } / Double(cores) : 0
            // 같은 구간의 커널 합계. 한쪽이라도 못 읽었으면 지난 값을 들고 있지 않는다 —
            // 오래된 부하를 지금 값처럼 보여주면 이 칸이 거짓말을 한다.
            load = previousLoad.flatMap { before in
                currentLoad.flatMap { SystemCPULoad.compute(from: before, to: $0) }
            }
            isWarmingUp = false
            previous = current
            previousLoad = currentLoad
            previousAt = now
        }
    }

    /// 500개가 넘는 프로세스를 훑는 동안 화면이 멈추면 안 된다. MainActor 밖으로 낸다.
    private func measure() async -> ([ProcessCPUTick], CPULoadTicks?) {
        let sample = self.sample, loadSample = self.loadSample
        return await Task.detached(priority: .utility) { (sample(), loadSample()) }.value
    }
}
