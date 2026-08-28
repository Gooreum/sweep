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
                             maxDepth: Int = 4,
                             minimumSize: Int64 = 1024 * 1024,
                             onEntryScanned: (@Sendable () -> Void)? = nil) -> DiskUsageNode {
        node(at: url, depth: maxDepth, minimumSize: minimumSize,
             onEntryScanned: onEntryScanned)
    }

    /// 항목 하나를 정확히 한 번만 본다. 크기는 자식에서 올려받는다.
    ///
    /// 예전에는 노드마다 `DirectorySize.bytes(at:)`를 불렀는데, 그 함수가 하위 전체를
    /// 훑으므로 같은 파일을 깊이만큼 반복해서 셌다 — 실측 30.7초가 이것 때문이었다.
    private static func node(at url: URL, depth: Int, minimumSize: Int64,
                             onEntryScanned: (@Sendable () -> Void)?) -> DiskUsageNode {
        guard let values = try? url.resourceValues(forKeys: keys) else {
            return DiskUsageNode(url: url, size: 0)
        }
        // 링크는 세지 않는다. 따라가면 대상 용량이 중복 집계된다.
        if values.isSymbolicLink == true { return DiskUsageNode(url: url, size: 0) }

        onEntryScanned?()

        guard values.isDirectory == true else {
            return DiskUsageNode(url: url, size: allocated(values))
        }

        var total: Int64 = 0
        var children: [DiskUsageNode] = []
        for child in contents(of: url) {
            let node = node(at: child, depth: depth - 1, minimumSize: minimumSize,
                            onEntryScanned: onEntryScanned)
            total += node.size
            // 깊이를 넘어서도 **순회는 계속한다** — 크기를 정확히 합치려면 끝까지 세야 한다.
            // 달라지는 것은 children에 넣느냐뿐이다.
            if depth > 0, node.size >= minimumSize { children.append(node) }
        }
        return DiskUsageNode(url: url, size: total,
                             children: children.sorted { $0.size > $1.size })
    }

    private static let keys: Set<URLResourceKey> = [
        .isDirectoryKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
    ]

    /// 논리 크기가 아니라 할당 크기. 지웠을 때 실제로 회수되는 양이다.
    private static func allocated(_ v: URLResourceValues) -> Int64 {
        Int64(v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? 0)
    }

    /// 하위 항목을 가져오면서 **필요한 속성을 함께 프리페치**한다.
    /// `includingPropertiesForKeys: nil`로 가져오면 뒤이은 `resourceValues`가
    /// 항목마다 별도 syscall이 되어 순회가 두 배 가까이 느려진다.
    ///
    /// 숨김 파일도 포함한다. 용량을 보는 화면에서 `.git` 같은 것을 빼면
    /// 합계가 실제와 어긋난다(실측 37MB 차이).
    private static func contents(of url: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: Array(keys), options: [])) ?? []
    }
}
