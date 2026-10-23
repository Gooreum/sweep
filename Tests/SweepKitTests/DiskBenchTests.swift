import Testing
import Foundation
@testable import SweepKit

/// 공간 보기·크기 재기의 속도를 이 Mac의 실제 폴더로 잰다.
///
/// 몇 분이 걸리고 기계마다 값이 달라 평소엔 돌지 않는다:
/// `SWEEP_BENCH=1 swift test --filter DiskBench`. 경로는 `SWEEP_BENCH_PATH`로 바꾼다(기본 `~/Library`).
@Suite("DiskBench", .enabled(if: ProcessInfo.processInfo.environment["SWEEP_BENCH"] == "1"))
struct DiskBenchTests {

    private var target: URL {
        if let path = ProcessInfo.processInfo.environment["SWEEP_BENCH_PATH"] {
            return URL(filePath: path)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library")
    }

    /// 예전 방식 그대로: FileManager로 한 항목씩, 한 스레드에서. 비교 기준이다.
    private static func legacyTotal(_ url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey,
                                         .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        guard let values = try? url.resourceValues(forKeys: keys) else { return 0 }
        if values.isSymbolicLink == true { return 0 }
        guard values.isDirectory == true else {
            return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        guard let children = try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: Array(keys), options: []) else { return 0 }
        return children.reduce(0) { $0 + legacyTotal($1) }
    }

    private static func time<T>(_ body: () -> T) -> (T, Double) {
        let start = Date()
        let value = body()
        return (value, Date().timeIntervalSince(start))
    }

    @Test("예전 방식과 새 방식의 시간·합계")
    func compare() {
        let url = target
        let (legacy, legacySeconds) = Self.time { Self.legacyTotal(url) }
        let (tree, treeSeconds) = Self.time {
            DiskUsageTree.build(at: url, canReadAppData: true)
        }
        let (summary, summarySeconds) = Self.time { DirectorySize.summary(at: url) }

        print("""
        [DiskBench] \(url.path)
          예전(FileManager·한 스레드): \(String(format: "%.2f", legacySeconds))s  \(legacy) B
          공간 보기 트리:              \(String(format: "%.2f", treeSeconds))s  \(tree.size) B
          DirectorySize.summary:       \(String(format: "%.2f", summarySeconds))s  \(summary.bytes) B
        """)
        // 재는 동안 다른 앱이 파일을 쓰므로 바이트 단위로 같을 수는 없다. 1% 안이면 같은 것을 센 것이다.
        let tolerance = max(Int64(1 << 20), legacy / 100)
        #expect(abs(tree.size - legacy) <= tolerance)
        #expect(abs(summary.bytes - legacy) <= tolerance)
    }
}
