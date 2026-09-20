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

    /// 첫 두 샘플이 아직 모이지 않았다.
    ///
    /// **빈 목록과 다르다.** 빈 목록은 "아무도 CPU를 안 쓴다"이고 이것은
    /// "아직 모른다"이다. 둘을 같은 화면으로 그리면 준비 중인 2초 동안
    /// 앱이 거짓말을 한다.
    public private(set) var isWarmingUp = true

    /// 사용률의 분모가 되는 논리 코어 수.
    ///
    /// `public`인 이유는 화면이 "코어 N개 전체 기준"이라고 밝혀야 하기 때문이다.
    /// 뷰가 `ProcessCPUSampler.coreCount`를 따로 읽으면 주입으로 코어 수를 바꾼
    /// 테스트·데모에서 화면 문구와 실제 분모가 어긋난다.
    public let cores: Int

    private let interval: Duration
    private let limit: Int
    private let sample: @Sendable () -> [ProcessCPUTick]

    /// `sample`을 갈아끼울 수 있게 뒀다 — 실제 프로세스를 띄우지 않고
    /// 주기·상한·취소를 검사하기 위해서다. `ItemActions`가 Finder 호출을
    /// 바꿔 끼울 수 있게 둔 것과 같은 방식이다.
    public init(
        interval: Duration = .seconds(2),
        limit: Int = 20,
        cores: Int = ProcessCPUSampler.coreCount,
        sample: @escaping @Sendable () -> [ProcessCPUTick] = ProcessCPUSampler.tick
    ) {
        self.interval = interval
        self.limit = limit
        self.cores = cores
        self.sample = sample
    }

    /// 뷰의 `.task`가 붙잡는다. 탭을 떠나면 SwiftUI가 취소하므로 따로 멈출 필요가 없다 —
    /// **CPU를 보는 화면이 안 보이는 동안 CPU를 쓰면 안 된다.**
    ///
    /// 한 바퀴에 한 번만 잰다. 직전 샘플을 들고 있어서, 주기마다 두 번씩
    /// 재는 낭비를 하지 않는다.
    public func run() async {
        var previous = await measure()

        while !Task.isCancelled {
            try? await Task.sleep(for: interval)
            // 자는 동안 취소됐으면 여기서 끝낸다. 취소된 뒤에 한 번 더 재면
            // 화면을 떠난 뒤에도 500개를 훑는다.
            guard !Task.isCancelled else { return }

            let current = await measure()
            usage = Array(
                ProcessUsage.compute(from: previous, to: current, over: interval, cores: cores)
                    .prefix(limit))
            isWarmingUp = false
            previous = current
        }
    }

    /// 500개가 넘는 프로세스를 훑는 동안 화면이 멈추면 안 된다. MainActor 밖으로 낸다.
    private func measure() async -> [ProcessCPUTick] {
        let sample = self.sample
        return await Task.detached(priority: .utility) { sample() }.value
    }
}
