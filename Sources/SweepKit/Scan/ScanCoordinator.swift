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
        public let finishedScanners: Int
        public let totalScanners: Int
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
                var found: [CleanupItem] = []
                var finished = 0

                await withTaskGroup(of: [CleanupItem].self) { group in
                    for scanner in scanners {
                        group.addTask { await scanner.scan() }
                    }
                    for await items in group {
                        found += items
                        finished += 1
                        continuation.yield(Progress(
                            items: Self.normalize(found),
                            finishedScanners: finished,
                            totalScanners: scanners.count))
                    }
                }
                continuation.finish()
            }
            // 소비자가 중단하면 스캔도 멈춘다. 안 그러면 창을 닫아도 디스크를 계속 훑는다.
            continuation.onTermination = { _ in task.cancel() }
        }
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
