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

    /// 스캐너를 병렬로 돌린다.
    ///
    /// 병합 직후 `ProtectedPaths`를 한 번 더 통과시키는 것이 2차 방어선이다.
    /// 스캐너가 버그로 엉뚱한 경로를 뱉어도 UI 목록에 도달하지 못한다.
    public func scan() async -> [CleanupItem] {
        var found: [CleanupItem] = []
        await withTaskGroup(of: [CleanupItem].self) { group in
            for scanner in scanners {
                group.addTask { await scanner.scan() }
            }
            for await items in group { found += items }
        }

        var seen: Set<URL> = []
        return found
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
