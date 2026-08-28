import Foundation

/// 파일·디렉토리가 실제로 차지하는 디스크 바이트를 센다.
public enum DirectorySize {

    private static let keys: Set<URLResourceKey> = [
        .isDirectoryKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
    ]

    /// 하위 전체 합계. 접근할 수 없는 항목은 건너뛴다 —
    /// 권한 없는 파일 하나 때문에 스캔 전체가 실패하면 안 된다.
    ///
    /// 심볼릭 링크는 따라가지 않는다. 따라가면 링크 대상 용량이 중복 집계되고,
    /// 허용 루트 밖 용량이 정리 후보 크기에 섞인다.
    public static func bytes(at url: URL) -> Int64 {
        guard let values = try? url.resourceValues(forKeys: keys) else { return 0 }
        if values.isSymbolicLink == true { return 0 }
        guard values.isDirectory == true else { return allocated(values) }

        guard let walker = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [],
            errorHandler: { _, _ in true }      // 접근 실패는 무시하고 계속한다
        ) else { return 0 }

        var total: Int64 = 0
        for case let child as URL in walker {
            guard let v = try? child.resourceValues(forKeys: keys) else { continue }
            if v.isSymbolicLink == true {
                walker.skipDescendants()
                continue
            }
            if v.isDirectory != true { total += allocated(v) }
        }
        return total
    }

    /// 논리 크기가 아니라 할당 크기를 쓴다. 지웠을 때 실제로 회수되는 양이기 때문이다.
    private static func allocated(_ v: URLResourceValues) -> Int64 {
        Int64(v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? 0)
    }
}
