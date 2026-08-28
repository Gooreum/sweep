import Foundation
import CryptoKit

/// 내용이 같은 파일을 찾는다. 대상은 `~/Downloads` —
/// 허용 루트 중 사용자가 같은 파일을 여러 번 받아 쌓이는 유일한 곳이다.
public struct DuplicateScanner: CleanupScanner {
    public let category: ScanCategory = .duplicate

    /// 이 크기 미만은 중복이어도 회수량이 미미해 목록만 어지럽힌다.
    public let minimumSize: Int64

    private let home: URL

    public init(minimumSize: Int64 = 1024 * 1024,
                home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.minimumSize = minimumSize
        self.home = home
    }

    private struct Candidate {
        let url: URL
        let size: Int64
        let created: Date
    }

    /// 실측 0.18초. 1초 안에 끝나므로 중간 보고 없이 완료 시점만 알린다.
    public var progressWeight: Double { 0.2 }

    public func scan() async -> [CleanupItem] {
        let root = home.appending(path: "Downloads")
        let files = Self.regularFiles(under: root).filter { $0.size >= minimumSize }

        var items: [CleanupItem] = []

        // 1단계: 크기로 묶는다. 크기가 다르면 내용이 같을 수 없으므로 해시 비용을 아낀다.
        for (size, sameSize) in Dictionary(grouping: files, by: \.size) where sameSize.count > 1 {

            // 2단계: 앞 64KB만 해시. 대부분의 오탐이 여기서 걸러진다.
            let byHead = Dictionary(grouping: sameSize) { Self.hash(of: $0.url, limit: 64 * 1024) }
            for (_, sameHead) in byHead where sameHead.count > 1 {

                // 3단계: 전체 해시로 확정.
                let byFull = Dictionary(grouping: sameHead) { Self.hash(of: $0.url, limit: nil) }
                for (_, identical) in byFull where identical.count > 1 {

                    // 가장 먼저 받은 것을 원본으로 남기고 나머지만 후보로 올린다.
                    let ordered = identical.sorted { $0.created < $1.created }
                    let original = ordered[0]
                    for duplicate in ordered.dropFirst() {
                        items.append(CleanupItem(
                            url: duplicate.url,
                            size: size,
                            category: .duplicate,
                            safety: .safe,
                            detail: "\(original.url.lastPathComponent)와 내용이 같습니다"))
                    }
                }
            }
        }
        return items
    }

    /// 파일 전체를 메모리에 올리지 않도록 1MB씩 끊어 읽는다.
    /// `limit`이 있으면 앞부분만 읽는다.
    static func hash(of url: URL, limit: Int?) -> String {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return "" }
        defer { try? handle.close() }

        var hasher = SHA256()
        var remaining = limit ?? Int.max
        while remaining > 0,
              let chunk = try? handle.read(upToCount: min(remaining, 1 << 20)),
              !chunk.isEmpty {
            hasher.update(data: chunk)
            remaining -= chunk.count
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// 하위 전체의 일반 파일. 심볼릭 링크와 디렉토리는 제외한다.
    private static func regularFiles(under root: URL) -> [Candidate] {
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .creationDateKey,
        ]
        guard let walker = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else { return [] }

        var found: [Candidate] = []
        for case let url as URL in walker {
            guard let v = try? url.resourceValues(forKeys: keys),
                  v.isSymbolicLink != true,
                  v.isRegularFile == true,
                  let size = v.fileSize
            else { continue }
            found.append(Candidate(url: url, size: Int64(size),
                                   created: v.creationDate ?? .distantPast))
        }
        return found
    }
}
