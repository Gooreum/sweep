import Foundation
import CryptoKit

/// 내용이 같은 파일을 찾는다. 대상은 사용자 폴더 전부(`UserFolders.roots`)이고,
/// **루트를 가로질러** 묶는다 — Downloads에 받은 것을 Documents에 옮겨 두고
/// 원본을 지우지 않는 경우가 가장 흔하다.
public struct DuplicateScanner: CleanupScanner {
    public let category: ScanCategory = .duplicate

    /// 이 크기 미만은 중복이어도 회수량이 미미해 목록만 어지럽힌다.
    public let minimumSize: Int64

    private let home: URL
    private let roots: [URL]
    private let isDataless: @Sendable (URL) -> Bool

    /// `roots`를 주지 않으면 그 홈의 사용자 폴더 전부다.
    public init(minimumSize: Int64 = 1024 * 1024,
                home: URL = Sandbox.userHome,
                roots: [URL]? = nil) {
        self.init(minimumSize: minimumSize, home: home, roots: roots,
                  isDataless: { UserFileWalker.isDataless($0) })
    }

    /// iCloud 자리표시자 판정을 갈아끼운다 — 테스트에서 그런 파일은 만들 수 없다.
    init(minimumSize: Int64, home: URL, roots: [URL]?,
         isDataless: @escaping @Sendable (URL) -> Bool) {
        self.minimumSize = minimumSize
        self.home = home
        self.roots = roots ?? UserFolders.roots(home: home)
        self.isDataless = isDataless
    }

    private struct Candidate {
        let url: URL
        let size: Int64
        let created: Date
        let modified: Date?
    }

    /// Downloads 하나일 때 실측 0.18초였다. 큰 파일 스캐너와 같은 폴더를 훑고(10.7초)
    /// 같은 크기 묶음을 해시하는 시간이 더해진다.
    public var progressWeight: Double { 12 }

    public func scan() async -> [CleanupItem] {
        await scan(onProgress: { _ in })
    }

    /// 훑기에 앞 절반, 해시에 뒤 절반을 쓴다. 해시 쪽은 묶음 수를 미리 알 수 없어 끝에 한 번 알린다.
    public func scan(onProgress: @escaping @Sendable (Double) -> Void) async -> [CleanupItem] {
        let downloads = DownloadsFolder.url(in: home)
        var files: [Candidate] = []
        for (index, root) in roots.enumerated() {
            files += UserFileWalker.files(under: root, minimumSize: minimumSize, isDataless: isDataless)
                .map { Candidate(url: $0.url, size: $0.logicalSize,
                                 created: $0.created ?? .distantPast, modified: $0.modified) }
            onProgress(0.5 * Double(index + 1) / Double(max(roots.count, 1)))
        }

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
                            // Downloads 밖의 사본은 일부러 둔 것일 수 있다(프로젝트 에셋, 백업).
                            // 원본이 남아도 자동 선택하지 않는다.
                            safety: duplicate.url.isDescendant(of: downloads) ? .safe : .caution,
                            detail: String(localized: "같은 내용의 원본이 남아요: \(originalName(original.url, beside: duplicate.url))"),
                            dates: FileDates(created: duplicate.created,
                                             lastUsed: duplicate.modified),
                            originalURL: original.url))
                    }
                }
            }
        }
        onProgress(1)
        return items
    }

    /// 열거자가 주는 경로와 같은 모양의 홈 경로(`/var` → `/private/var`).
    ///
    /// `resolvingSymlinksInPath()`는 쓸 수 없다 — 그건 거꾸로 `/private`를 떼어 낸다.
    private var realHomePath: String {
        guard let resolved = realpath(home.path, nil) else { return home.path }
        defer { free(resolved) }
        return String(cString: resolved)
    }

    /// 원본을 가리키는 말. 같은 폴더면 이름만, 다른 폴더면 `~/Documents/a.pdf`처럼 경로를 쓴다 —
    /// 루트가 여럿이면 이름만으로는 원본이 어디 있는지 찾을 수 없다.
    private func originalName(_ original: URL, beside duplicate: URL) -> String {
        original.deletingLastPathComponent().standardizedFileURL.path
            == duplicate.deletingLastPathComponent().standardizedFileURL.path
            ? original.lastPathComponent
            : CleanupItem.abbreviating(original.path, home: realHomePath)
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
}
