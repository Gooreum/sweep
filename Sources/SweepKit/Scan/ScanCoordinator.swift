import Foundation

/// 여러 `CleanupScanner`를 동시에 돌리고 결과를 하나로 합친다.
public struct ScanCoordinator: Sendable {
    private let scanners: [any CleanupScanner]

    public init(scanners: [any CleanupScanner]) { self.scanners = scanners }

    /// 앱이 실제로 쓰는 기본 구성.
    public static func standard() -> ScanCoordinator {
        ScanCoordinator(scanners: [
            RunawayTempScanner(),
            XcodeScanner(),
            DevCacheScanner(),
            StaleCacheScanner(),
            LargeFileScanner(),
            DuplicateScanner(),
        ])
    }

    /// 스캔 도중 한 번씩 흘러나오는 중간 상태.
    public struct Progress: Sendable {
        /// 지금까지 모인 결과. 정규화가 끝나 있어 그대로 화면에 그릴 수 있다.
        public let items: [CleanupItem]
        /// 0~1. 스캐너 개수가 아니라 **실측 소요 시간 가중치**로 계산한다.
        public let fraction: Double
        public let elapsed: Duration
        /// 남은 시간 추정. 진행률이 너무 작으면 값이 튀어서 nil을 준다.
        public let estimatedRemaining: Duration?
        public let finishedScanners: Int
        public let totalScanners: Int

        public var percent: Int { Int((fraction * 100).rounded()) }
    }

    /// 여러 스캐너가 동시에 보고하는 진행률을 한 값으로 모은다.
    ///
    /// 자식 태스크들이 각자 다른 스레드에서 호출하므로 잠금이 필요하다.
    private final class ProgressTracker: @unchecked Sendable {
        private let lock = NSLock()
        private let weights: [Double]
        private var fractions: [Double]
        private var latestItems: [CleanupItem] = []
        private var finished = 0

        init(weights: [Double]) {
            self.weights = weights
            self.fractions = Array(repeating: 0, count: weights.count)
        }

        /// 스캐너 하나의 진행을 갱신하고 전체 가중 진행률을 돌려준다.
        func update(scanner index: Int, to value: Double) -> Double {
            lock.lock(); defer { lock.unlock() }
            fractions[index] = min(max(value, 0), 1)
            return weightedFraction()
        }

        /// 스캐너 하나가 끝났다. 결과를 저장하고 완료 수를 올린다.
        func complete(items: [CleanupItem]) {
            lock.lock(); defer { lock.unlock() }
            latestItems = items
            finished += 1
        }

        func snapshot() -> (items: [CleanupItem], fraction: Double, finished: Int) {
            lock.lock(); defer { lock.unlock() }
            return (latestItems, weightedFraction(), finished)
        }

        private func weightedFraction() -> Double {
            let total = weights.reduce(0, +)
            guard total > 0 else { return 0 }
            return zip(weights, fractions).reduce(0) { $0 + $1.0 * $1.1 } / total
        }
    }

    /// 스캐너를 병렬로 돌리고 전부 끝난 결과만 돌려준다.
    public func scan() async -> [CleanupItem] {
        var latest: [CleanupItem] = []
        for await progress in stream() { latest = progress.items }
        return latest
    }

    /// 스캐너 하나가 끝날 때마다 지금까지의 결과를 흘린다.
    ///
    /// 전체 스캔은 20초가 넘는다. 그동안 빈 화면을 보여주지 않으려면
    /// 부분 결과를 그릴 수 있어야 한다.
    public func stream() -> AsyncStream<Progress> {
        let scanners = self.scanners
        return AsyncStream { continuation in
            let task = Task {
                let started = ContinuousClock.now
                let tracker = ProgressTracker(weights: scanners.map(\.progressWeight))
                var found: [CleanupItem] = []

                /// 진행이 바뀔 때마다 같은 형태로 흘린다.
                @Sendable func emit(fraction: Double, items: [CleanupItem], finished: Int) {
                    let elapsed = started.duration(to: .now)
                    continuation.yield(Progress(
                        items: items,
                        fraction: fraction,
                        elapsed: elapsed,
                        estimatedRemaining: Self.remaining(elapsed: elapsed, fraction: fraction),
                        finishedScanners: finished,
                        totalScanners: scanners.count))
                }

                await withTaskGroup(of: [CleanupItem].self) { group in
                    for (index, scanner) in scanners.enumerated() {
                        group.addTask {
                            await scanner.scan { value in
                                _ = tracker.update(scanner: index, to: value)
                                let snapshot = tracker.snapshot()
                                emit(fraction: snapshot.fraction, items: snapshot.items,
                                     finished: snapshot.finished)
                            }
                        }
                    }
                    for await items in group {
                        found += items
                        tracker.complete(items: Self.normalize(found))
                        let snapshot = tracker.snapshot()
                        emit(fraction: snapshot.fraction, items: snapshot.items,
                             finished: snapshot.finished)
                    }
                }
                // 마지막은 반드시 100%로 끝맺는다. 반올림 때문에 99%에서 멈추면 안 된다.
                emit(fraction: 1, items: Self.normalize(found), finished: scanners.count)
                continuation.finish()
            }
            // 소비자가 중단하면 스캔도 멈춘다. 안 그러면 창을 닫아도 디스크를 계속 훑는다.
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// 남은 시간 = 지금까지 걸린 시간 × (남은 비율 / 진행한 비율).
    ///
    /// 진행률이 너무 작으면 추정이 수십 배로 튄다. 그럴 땐 값을 주지 않는 편이 정직하다.
    static func remaining(elapsed: Duration, fraction: Double) -> Duration? {
        guard fraction >= 0.03, fraction < 1 else { return nil }
        let seconds = Double(elapsed.components.seconds)
            + Double(elapsed.components.attoseconds) / 1e18
        let estimate = seconds * (1 - fraction) / fraction
        guard estimate.isFinite, estimate >= 0 else { return nil }
        return .seconds(estimate)
    }

    /// 안전 필터 → 정렬 → 경로 중복 제거.
    ///
    /// 중간 결과에도 똑같이 걸어야 스캔 도중 목록 순서가 흔들리지 않는다.
    /// `ProtectedPaths`를 한 번 더 통과시키는 것이 2차 방어선이다 —
    /// 스캐너가 버그로 엉뚱한 경로를 뱉어도 UI 목록에 도달하지 못한다.
    static func normalize(_ items: [CleanupItem]) -> [CleanupItem] {
        var seen: Set<URL> = []
        return items
            .filter { $0.size > 0 && ProtectedPaths.isRemovable($0.url) }
            .sorted { lhs, rhs in
                // 위험한 카테고리가 위로, 같은 카테고리 안에서는 큰 것부터
                lhs.category.sortOrder == rhs.category.sortOrder
                    ? lhs.size > rhs.size
                    : lhs.category.sortOrder < rhs.category.sortOrder
            }
            // 같은 경로를 두 스캐너가 잡으면 합계가 두 배로 보인다.
            // (~/Downloads는 DuplicateScanner와 LargeFileScanner가 함께 본다.)
            // 정렬 뒤에 거르므로 더 위에 오는 카테고리가 이긴다.
            .filter { seen.insert($0.url).inserted }
    }
}
