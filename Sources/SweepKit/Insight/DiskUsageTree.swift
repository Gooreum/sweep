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

extension DiskUsageNode {
    /// 목록 막대의 길이 비율. **가장 큰 항목** 기준이다.
    ///
    /// 전체 합 기준이면 하나가 압도할 때 나머지가 전부 보이지 않는 선이 된다 —
    /// 트리맵이 이 데이터에서 실패한 이유가 그것이었다.
    public func barRatio(largest: Int64) -> Double {
        guard largest > 0 else { return 0 }
        return min(1, max(0, Double(size) / Double(largest)))
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
        // 무엇이든 들여다봤으면 보고한다. `countEntries`가 링크와 읽기 실패 항목까지
        // 세므로 여기서 빼먹으면 분모가 커져 퍼센트가 100에 닿지 못한다 —
        // 실측에서 링크 232개 때문에 99%에서 멈췄다.
        onEntryScanned?()

        guard let values = try? url.resourceValues(forKeys: keys) else {
            return DiskUsageNode(url: url, size: 0)
        }
        // 링크는 크기에 넣지 않는다. 따라가면 대상 용량이 중복 집계된다.
        // 다만 **방문은 했으므로** 위에서 이미 보고했다 — 두 성질은 별개다.
        if values.isSymbolicLink == true { return DiskUsageNode(url: url, size: 0) }

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

    /// 크기를 재기 전에 항목 수만 센다. 이 값이 진행률의 분모가 된다.
    ///
    /// `stat`을 부르지 않고 `readdir`의 `d_type`만으로 디렉토리를 판별한다.
    /// `FileManager.enumerator`로 세면 6.2초인데 이 방식은 3.6초다 —
    /// 퍼센트 하나 때문에 대기 시간을 두 배로 만들 수는 없다.
    ///
    /// 숨김 파일을 포함하는 이유는 `build`도 포함하기 때문이다. 한쪽만 빼면 분모가 어긋난다.
    public static func countEntries(at url: URL,
                                    isCancelled: @Sendable () -> Bool = { false },
                                    onCounted: (@Sendable (Int) -> Void)? = nil) -> Int {
        var total = 0
        var stack = [url.path]

        while let path = stack.popLast() {
            if isCancelled() { return total }
            // 디렉토리 단위로 보고한다. 분모가 생기기 전에도 숫자가 움직여야
            // 멈춘 것처럼 보이지 않는다.
            onCounted?(total)
            guard let handle = opendir(path) else { continue }
            defer { closedir(handle) }

            while let entry = readdir(handle) {
                // `.`/`..`는 바이트로 거른다. 여기서 String을 만들면
                // 항목 7만 개에 대해 문자열 생성 비용이 그대로 붙는다(실측 5.9 → 3.4초 차이).
                let isDotEntry = withUnsafePointer(to: entry.pointee.d_name) {
                    $0.withMemoryRebound(to: CChar.self, capacity: 3) { name in
                        name[0] == 46 && (name[1] == 0 || (name[1] == 46 && name[2] == 0))
                    }
                }
                if isDotEntry { continue }
                total += 1

                // 이름이 필요한 건 더 내려갈 디렉토리뿐이다. 파일은 세기만 하면 된다.
                // 링크는 세되 따라 내려가지 않는다 — build도 링크 하위를 보지 않는다.
                guard entry.pointee.d_type == DT_DIR else { continue }
                let name = withUnsafePointer(to: entry.pointee.d_name) {
                    $0.withMemoryRebound(to: CChar.self,
                                         capacity: Int(entry.pointee.d_namlen) + 1) {
                        String(cString: $0)
                    }
                }
                stack.append(path + "/" + name)
            }
        }
        return total
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
