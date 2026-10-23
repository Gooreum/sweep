import Foundation

/// 디스크 사용량 트리의 한 노드.
public struct DiskUsageNode: Identifiable, Sendable, Hashable, Codable {
    public let url: URL
    public let size: Int64
    public let children: [DiskUsageNode]

    /// 안을 들여다볼 수 있었는가.
    ///
    /// 못 읽은 디렉토리를 0바이트로 그리면 **거짓말이 된다.** 허용 루트 안만
    /// 볼 때는 거의 없던 일이지만 `/`나 `~/Library/Containers`에서는 흔하다.
    /// 빈 디렉토리도 0바이트라 크기만으로는 둘을 구분할 수 없다.
    public let isReadable: Bool

    public init(url: URL, size: Int64, children: [DiskUsageNode] = [],
                isReadable: Bool = true) {
        self.url = url
        self.size = size
        self.children = children
        self.isReadable = isReadable
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

extension DiskUsageNode {
    /// `target`을 품은 갈래를 따라 내려가며 크기를 `delta`만큼 바꾼다 — 조상 전부 함께.
    ///
    /// `removing`이면 정확히 그 노드를 children에서 뺀다. 노드가 없으면(가지치기·깊이 밖)
    /// 가장 깊은 조상까지만 바꾼다 — 그 조상의 크기에는 이미 들어 있기 때문이다.
    /// 이 트리 밖이면 nil.
    func adjusting(_ target: URL, by delta: Int64, removing: Bool) -> DiskUsageNode? {
        guard target.isSameOrInside(url) else { return nil }

        var children = self.children
        if let index = children.firstIndex(where: { target.isSameOrInside($0.url) }) {
            let child = children[index]
            if removing, child.url.pathKey == target.pathKey {
                children.remove(at: index)
            } else if let updated = child.adjusting(target, by: delta, removing: removing) {
                children[index] = updated
                // 크기가 바뀌면 순서도 바뀐다. 목록은 크기순이 규칙이다.
                children.sort { $0.size > $1.size }
            }
        }
        return DiskUsageNode(url: url, size: max(0, size + delta), children: children,
                             // 안 넘기면 기본값 true로 되살아나 "읽을 수 없음"이 사라진다
                             isReadable: isReadable)
    }

    /// 트리 안에서 그 경로의 노드. 목록에 남지 않은 곳이면 nil.
    func node(at target: URL) -> DiskUsageNode? {
        if url.pathKey == target.pathKey { return self }
        guard target.isSameOrInside(url) else { return nil }
        for child in children {
            if let found = child.node(at: target) { return found }
        }
        return nil
    }
}

extension URL {
    /// 비교용 경로. `.`·`..`만 정리하고 끝의 `/`는 뗀다.
    ///
    /// `standardizedFileURL`은 쓰지 않는다 — 있는 경로에서만 `/private`를 떼서,
    /// 지워져 없어진 파일과 남아 있는 부모 폴더가 서로 다른 경로로 보인다.
    var pathKey: String {
        let path = standardized.path
        return path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
    }

    /// 이 경로가 `ancestor` 자신이거나 그 아래인가. `/foo`가 `/foobar`를 품지 않게 `/`까지 맞춘다.
    func isSameOrInside(_ ancestor: URL) -> Bool {
        let mine = pathKey, theirs = ancestor.pathKey
        return mine == theirs || mine.hasPrefix(theirs == "/" ? "/" : theirs + "/")
    }
}

/// 여러 스레드가 함께 보는 중단 신호.
///
/// 순회는 `Task.detached`에서 도는데 그 안에서는 바깥 `Task`의 취소가 보이지
/// 않는다. 볼륨 전체를 훑으면 몇 분이 걸리므로 멈출 방법이 있어야 한다.
public final class CancelFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var flag = false

    public init() {}

    public func cancel() {
        lock.lock(); defer { lock.unlock() }
        flag = true
    }

    public var isCancelled: Bool {
        lock.lock(); defer { lock.unlock() }
        return flag
    }
}

public enum DiskUsageTree {

    /// 사용량 트리를 만든다.
    ///
    /// `maxDepth`와 `minimumSize`로 가지치기하는 이유: 끝까지 파고들면 화면에 그릴 수
    /// 없을 만큼 작은 조각이 수만 개 나오고 스캔만 느려진다. 눈에 보이는 것만 만든다.
    ///
    /// 가지치기된 자식도 **부모의 size에는 포함된다.** 합계가 맞아야 면적 비교가 의미를 갖는다.
    ///
    /// `onBytesScanned`는 폴더 하나를 읽을 때마다 그 폴더 **바로 아래 파일들의 바이트 합**을
    /// 한 번 알린다. 다 더하면 루트 크기가 된다 — 진행률의 분자다.
    public static func build(at url: URL,
                             maxDepth: Int = 4,
                             minimumSize: Int64 = 1024 * 1024,
                             canReadAppData: Bool = FullDiskAccess.isGranted,
                             appDataHome: URL = Sandbox.userHome,
                             isCancelled: @escaping @Sendable () -> Bool = { false },
                             onBytesScanned: (@Sendable (Int64) -> Void)? = nil) -> DiskUsageNode {
        let walk = Walk(
            minimumSize: minimumSize,
            protectedPrefixes: canReadAppData
                ? [] : AppDataPaths.roots(home: appDataHome).map { $0.standardizedFileURL.path + "/" },
            isCancelled: isCancelled,
            onBytesScanned: onBytesScanned)

        let path = url.standardizedFileURL.path
        // 전체 디스크 접근이 없으면 남의 앱 폴더를 **열어 보지도 않는다.**
        // 열면 그 앱마다 "다른 앱의 데이터에 접근하려고 합니다"가 뜬다 —
        // 앱 폴더 수만큼 물으므로 한 번 허용으로 끝나지 않는다.
        // 못 읽는다고 표시하면 화면이 배너로 켜는 길을 알려 준다.
        if walk.isProtected(path) { return DiskUsageNode(url: url, size: 0, isReadable: false) }

        // 루트 자신만 속성을 따로 묻는다. 그 아래는 부모 폴더를 읽을 때 같이 받는다.
        guard let values = try? url.resourceValues(forKeys: rootKeys) else {
            return DiskUsageNode(url: url, size: 0)
        }
        // 링크는 크기에 넣지 않는다. 따라가면 대상 용량이 중복 집계된다.
        if values.isSymbolicLink == true { return DiskUsageNode(url: url, size: 0) }
        guard values.isDirectory == true else {
            let size = Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
            onBytesScanned?(size)
            return DiskUsageNode(url: url, size: size)
        }
        return walk.directory(url: url, path: path, depth: maxDepth, parallelLevels: parallelLevels)
    }

    /// 몇 단계까지 자식 폴더를 여러 스레드로 나눠 잴까.
    ///
    /// 한 단계만 나누면 `/`처럼 한 자식(`Users`)이 거의 전부인 곳에서 한 스레드만 일한다.
    /// 두 단계면 그 아래 폴더들로 다시 나뉜다. 더 깊으면 스레드만 늘고 빨라지지 않는다.
    static let parallelLevels = 2

    private static let rootKeys: Set<URLResourceKey> = [
        .isDirectoryKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
    ]

    /// 한 번의 순회가 공유하는 설정.
    private struct Walk: Sendable {
        let minimumSize: Int64
        /// 열면 안 되는 앱 데이터 구역의 **안쪽** 접두사(`…/Library/Containers/`).
        /// 구역 자신은 목록에 보여야 하므로 끝의 `/`까지 맞아야 안쪽이다.
        let protectedPrefixes: [String]
        let isCancelled: @Sendable () -> Bool
        let onBytesScanned: (@Sendable (Int64) -> Void)?

        func isProtected(_ path: String) -> Bool {
            !protectedPrefixes.isEmpty && protectedPrefixes.contains { path.hasPrefix($0) }
        }

        /// 폴더 하나. 항목을 정확히 한 번만 보고, 크기는 자식에서 올려받는다.
        ///
        /// 예전에는 노드마다 `DirectorySize.bytes(at:)`를 불렀는데, 그 함수가 하위 전체를
        /// 훑으므로 같은 파일을 깊이만큼 반복해서 셌다 — 실측 30.7초가 이것 때문이었다.
        func directory(url: URL, path: String, depth: Int, parallelLevels: Int) -> DiskUsageNode {
            // 몇 분짜리 순회를 끊을 수 있어야 한다. 폴더 단위면 충분히 촘촘하다.
            if isCancelled() { return DiskUsageNode(url: url, size: 0) }

            // 못 읽었으면 0바이트가 아니라 "모른다"다. `?? []`로 삼키면
            // 권한 없는 폴더가 "0 KB"로 보인다.
            guard let entries = BulkDirectory.entries(atPath: path) else {
                return DiskUsageNode(url: url, size: 0, isReadable: false)
            }

            // 이 아래는 목록에 남지 않는다. 크기만 합치면 되므로 URL·노드를 만들지 않는다 —
            // 깊은 곳일수록 항목이 많아 이것만으로 순회 시간의 상당 부분이다.
            if depth <= 0, parallelLevels <= 0 {
                return DiskUsageNode(url: url, size: size(path: path, entries: entries))
            }

            var fileBytes: Int64 = 0
            var nodes: [DiskUsageNode] = []
            var folders: [(url: URL, path: String)] = []
            for entry in entries {
                let childPath = BulkDirectory.join(path, entry.name)
                let isFolder = entry.kind == .directory
                let childURL = URL(filePath: childPath,
                                   directoryHint: isFolder ? .isDirectory : .notDirectory)
                if isProtected(childPath) {
                    nodes.append(DiskUsageNode(url: childURL, size: 0, isReadable: false))
                    continue
                }
                switch entry.kind {
                case .directory:
                    folders.append((childURL, childPath))
                case .symlink:
                    // 링크는 세되 크기는 0이다. 따라 내려가지 않는다.
                    nodes.append(DiskUsageNode(url: childURL, size: 0))
                case .file, .other:
                    fileBytes += entry.allocated
                    nodes.append(DiskUsageNode(url: childURL, size: entry.allocated))
                }
            }
            // 항목마다가 아니라 폴더마다 한 번. 여러 스레드가 항목마다 잠금을 잡으면
            // 나눠 잰 이득이 사라진다.
            if fileBytes > 0 { onBytesScanned?(fileBytes) }

            let measure: @Sendable ((url: URL, path: String)) -> DiskUsageNode = { folder in
                directory(url: folder.url, path: folder.path,
                          depth: depth - 1, parallelLevels: parallelLevels - 1)
            }
            let measured = parallelLevels > 0 && folders.count > 1
                ? folders.concurrentMap(measure)
                : folders.map(measure)

            let total = fileBytes + measured.reduce(0) { $0 + $1.size }
            // 깊이를 넘어서도 **순회는 계속한다** — 크기를 정확히 합치려면 끝까지 세야 한다.
            // 달라지는 것은 children에 넣느냐뿐이다.
            //
            // 못 읽은 노드는 크기와 무관하게 남긴다. 크기가 0이라 최소 크기에
            // 걸려 잘려 나가면, 안에 뭐가 얼마나 있는지 모르는 폴더가 목록에서
            // 통째로 사라진다 — 0으로 보이는 것보다 나쁘다.
            let children = depth > 0
                ? (nodes + measured).filter { $0.size >= minimumSize || !$0.isReadable }
                    .sorted { $0.size > $1.size }
                : []
            return DiskUsageNode(url: url, size: total, children: children)
        }

        /// 목록에 남지 않는 갈래의 합계. 한 스레드에서 스택으로 훑는다.
        /// 규칙은 `directory`와 같다 — 링크 0, 앱 데이터 구역 안쪽은 열지 않음, 폴더마다 진행 보고.
        private func size(path: String, entries first: [BulkEntry]) -> Int64 {
            var total: Int64 = 0
            var pending: [(path: String, entries: [BulkEntry]?)] = [(path, first)]
            while let next = pending.popLast() {
                if isCancelled() { break }
                guard let entries = next.entries ?? BulkDirectory.entries(atPath: next.path) else { continue }
                var fileBytes: Int64 = 0
                for entry in entries {
                    switch entry.kind {
                    case .directory:
                        let child = BulkDirectory.join(next.path, entry.name)
                        if !isProtected(child) { pending.append((child, nil)) }
                    case .symlink:
                        continue
                    case .file, .other:
                        if !protectedPrefixes.isEmpty, isProtected(BulkDirectory.join(next.path, entry.name)) {
                            continue
                        }
                        fileBytes += entry.allocated
                    }
                }
                if fileBytes > 0 { onBytesScanned?(fileBytes) }
                total += fileBytes
            }
            return total
        }
    }
}

extension Array where Element: Sendable {
    /// 원소마다 `transform`을 여러 스레드에서 돌리고 **원래 순서대로** 모은다.
    ///
    /// 디스크 순회는 동기 코드라 `TaskGroup`에 넣으면 협력 스레드 풀을 막는다.
    /// GCD가 코어 수에 맞춰 나눈다.
    func concurrentMap<T: Sendable>(_ transform: @Sendable (Element) -> T) -> [T] {
        let results = UnsafeMutableBufferPointer<T?>.allocate(capacity: count)
        results.initialize(repeating: nil)
        defer { results.deallocate() }
        nonisolated(unsafe) let slots = results
        withoutActuallyEscaping(transform) { transform in
            DispatchQueue.concurrentPerform(iterations: count) { index in
                // 칸마다 한 스레드만 쓴다.
                slots[index] = transform(self[index])
            }
        }
        return results.map { $0! }
    }
}
