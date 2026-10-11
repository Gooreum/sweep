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
                home: URL = Sandbox.userHome) {
        self.minimumSize = minimumSize
        self.home = home
    }

    private struct Candidate {
        let url: URL
        let size: Int64
        let created: Date
        let modified: Date?
    }

    /// 실측 0.18초. 1초 안에 끝나므로 중간 보고 없이 완료 시점만 알린다.
    public var progressWeight: Double { 0.2 }

    public func scan() async -> [CleanupItem] {
        let root = DownloadsFolder.url(in: home)
        let files = Self.regularFiles(under: root).filter { $0.size >= minimumSize }

        var items: [CleanupItem] = []

        // 1단계: 크기로 묶는다. 크기가 다르면 내용이 같을 수 없으므로 해시 비용을 아낀다.
        for (size, sameSize) in Dictionary(grouping: files, by: \.size) where sameSize.count > 1 {

            // 2단계: 앞 64KB만 해시. 대부분의 오탐이 여기서 걸러진다.
            for sameHead in Self.groupedByHash(sameSize, limit: 64 * 1024) {

                // 3단계: 전체 해시로 확정.
                for identical in Self.groupedByHash(sameHead, limit: nil) {

                    // 가장 먼저 받은 것을 원본으로 남기고 나머지만 후보로 올린다.
                    let ordered = identical.sorted { $0.created < $1.created }
                    let original = ordered[0]
                    for duplicate in ordered.dropFirst() {
                        items.append(CleanupItem(
                            url: duplicate.url,
                            size: size,
                            category: .duplicate,
                            safety: .safe,
                            detail: "\(original.url.lastPathComponent)와 내용이 같습니다",
                            dates: FileDates(created: duplicate.created,
                                             lastUsed: duplicate.modified)))
                    }
                }
            }
        }
        return items
    }

    /// 해시가 같은 것끼리 묶는다. 둘 이상 모인 묶음만 돌려준다.
    ///
    /// **읽지 못한 파일은 어느 묶음에도 넣지 않는다.** 권한이 없거나 iCloud에서
    /// 아직 안 내려온 파일 둘을 "내용이 같다"고 할 근거는 없다 — 예전에는 둘 다
    /// 빈 문자열 키로 묶여 `.safe` 중복이 되고, 한쪽이 휴지통으로 갔다.
    private static func groupedByHash(_ candidates: [Candidate], limit: Int?) -> [[Candidate]] {
        var groups: [String: [Candidate]] = [:]
        for candidate in candidates {
            guard let key = hash(of: candidate.url, limit: limit) else { continue }
            groups[key, default: []].append(candidate)
        }
        return groups.values.filter { $0.count > 1 }
    }

    /// 파일 전체를 메모리에 올리지 않도록 1MB씩 끊어 읽는다.
    /// `limit`이 있으면 앞부분만 읽는다.
    ///
    /// 열지 못하거나 **읽는 도중 오류가 나면 nil**이다. 오류와 EOF를 구분한다 —
    /// 구분하지 않으면 도중에 끊긴 일부분의 해시가 완전한 해시처럼 돌아간다.
    static func hash(of url: URL, limit: Int?) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        var hasher = SHA256()
        var remaining = limit ?? Int.max
        while remaining > 0 {
            // `read(upToCount:)`는 EOF에서 nil을 준다. `try?`로 감싸면 오류도 nil이 되어
            // 둘이 구분되지 않는다 — 예전 코드가 부분 해시를 돌려준 이유다.
            let chunk: Data?
            do { chunk = try handle.read(upToCount: min(remaining, 1 << 20)) } catch { return nil }
            guard let chunk, !chunk.isEmpty else { break }
            hasher.update(data: chunk)
            remaining -= chunk.count
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// 하위 전체의 일반 파일. 심볼릭 링크와 디렉토리는 제외한다.
    private static func regularFiles(under root: URL) -> [Candidate] {
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey,
            .creationDateKey, .contentModificationDateKey,
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
                                   created: v.creationDate ?? .distantPast,
                                   modified: v.contentModificationDate))
        }
        return found
    }
}
