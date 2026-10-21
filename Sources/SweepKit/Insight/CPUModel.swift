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

    /// 목록에 없는 몫(root·다른 계정 프로세스)을 프로세스 행과 같은 단위로.
    ///
    /// 기계 전체 기준 차이(`load.used − ownTotal`)에 코어 수를 곱해 코어 하나 = 100으로
    /// 바꾼다. 측정 시차로 차이가 음수가 될 수 있어 0에서 막는다. 커널 값이 없으면 nil.
    public var unlistedPercent: Double? {
        guard let load else { return nil }
        return max(0, load.used - ownTotal) * Double(cores)
    }

    /// 마우스가 표 위에 있는 동안 붙잡아 둔 줄 순서(`CPURow.id`). 없으면 사용률순이다.
    private var heldOrder: [String]?

    /// 표와 상위 목록이 그리는 줄. 읽은 프로세스 사이에 시스템 프로세스 합계가 끼어 있다.
    ///
    /// 붙잡아 둔 동안에도 **값은 주기마다 바뀐다.** 순서만 그대로다 — 2초마다 순위가
    /// 뒤섞이면 누르려는 순간 행이 움직여 옆 프로그램이 골라진다. 새로 나타난 줄은
    /// 끝에 붙고, 끝난 프로세스의 줄은 사라진다.
    public var rows: [CPURow] {
        let base = CPURow.rows(usage: usage, unlisted: unlistedPercent)
        guard let heldOrder else { return base }
        let position = Dictionary(heldOrder.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        return base.enumerated()
            .sorted { lhs, rhs in
                let l = position[lhs.element.id] ?? Int.max, r = position[rhs.element.id] ?? Int.max
                return l != r ? l < r : lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    /// 표 위에 마우스가 있는 동안 순서를 붙잡는다. 나가면 다시 사용률순이다.
    public func holdOrder(_ hold: Bool) {
        heldOrder = hold ? CPURow.rows(usage: usage, unlisted: unlistedPercent).map(\.id) : nil
    }

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

    /// 표에서 고른 프로그램. 합계 행은 고를 수 없다.
    ///
    /// 고른 뒤 그 프로그램이 끝나도 유지한다 — `details`만 nil이 되어 화면이
    /// "이 프로그램은 끝났어요"라고 말한다. 선택이 말없이 풀리면 사용자가 방금 누른 것이 사라진다.
    public private(set) var selectedPID: pid_t?

    /// 고른 프로그램의 자세한 정보. 못 찾으면 nil.
    public private(set) var details: ProcessDetails?

    private let interval: Duration
    private let limit: Int
    private let sample: @Sendable () -> [ProcessCPUTick]
    private let loadSample: @Sendable () -> CPULoadTicks?
    private let detailsReader: @Sendable (pid_t) -> ProcessDetails?

    /// `sample`을 갈아끼울 수 있게 뒀다 — 실제 프로세스를 띄우지 않고
    /// 주기·상한·취소를 검사하기 위해서다. `ItemActions`가 Finder 호출을
    /// 바꿔 끼울 수 있게 둔 것과 같은 방식이다.
    public init(
        interval: Duration = .seconds(2),
        limit: Int = 20,
        cores: Int = ProcessCPUSampler.coreCount,
        sample: @escaping @Sendable () -> [ProcessCPUTick] = ProcessCPUSampler.tick,
        loadSample: @escaping @Sendable () -> CPULoadTicks? = SystemCPULoad.tick,
        detailsReader: @escaping @Sendable (pid_t) -> ProcessDetails? = ProcessDetailsReader.read(pid:)
    ) {
        self.interval = interval
        self.limit = limit
        self.cores = cores
        self.sample = sample
        self.loadSample = loadSample
        self.detailsReader = detailsReader
    }

    /// 행을 눌렀을 때. 같은 행을 다시 누르면 선택을 푼다. 읽는 건 프로세스 한 개와
    /// 목록 한 번이라 메인에서 바로 읽어도 화면이 멈추지 않는다.
    public func select(_ pid: pid_t?) {
        selectedPID = (pid == selectedPID) ? nil : pid
        details = selectedPID.flatMap(detailsReader)
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
            // 메모리 같은 값은 흘러가므로 주기마다 다시 읽는다. 고른 게 없으면 읽지 않는다.
            if let pid = selectedPID {
                let reader = detailsReader
                details = await Task.detached(priority: .utility) { reader(pid) }.value
            }
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
