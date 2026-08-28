import Foundation

/// 디스크 사용량 트리의 한 노드.
public struct DiskUsageNode: Identifiable, Sendable, Hashable {
    public let url: URL
    public let size: Int64
    public let children: [DiskUsageNode]

    public init(url: URL, size: Int64, children: [DiskUsageNode] = []) {
        self.url = url
        self.size = size
        self.children = children
    }

    public var id: URL { url }
    public var name: String { url.lastPathComponent }
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

public enum DiskUsageTree {

    /// 사용량 트리를 만든다.
    ///
    /// `maxDepth`와 `minimumSize`로 가지치기하는 이유: 끝까지 파고들면 화면에 그릴 수
    /// 없을 만큼 작은 조각이 수만 개 나오고 스캔만 느려진다. 눈에 보이는 것만 만든다.
    ///
    /// 가지치기된 자식도 **부모의 size에는 포함된다.** 합계가 맞아야 면적 비교가 의미를 갖는다.
    public static func build(at url: URL,
                             maxDepth: Int = 3,
                             minimumSize: Int64 = 10 * 1024 * 1024) -> DiskUsageNode {
        let size = DirectorySize.bytes(at: url)
        guard maxDepth > 0, isDirectory(url) else {
            return DiskUsageNode(url: url, size: size)
        }

        let children = contents(of: url)
            .map { build(at: $0, maxDepth: maxDepth - 1, minimumSize: minimumSize) }
            .filter { $0.size >= minimumSize }
            .sorted { $0.size > $1.size }

        return DiskUsageNode(url: url, size: size, children: children)
    }

    private static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }

    private static func contents(of url: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
    }
}
