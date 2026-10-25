import Foundation

/// 파일·디렉토리가 실제로 차지하는 디스크 바이트를 센다.
public enum DirectorySize {

    private static let keys: Set<URLResourceKey> = [
        .isDirectoryKey, .isSymbolicLinkKey, .isRegularFileKey,
        .totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
        .creationDateKey, .contentModificationDateKey,
    ]

    /// 한 번 순회한 결과. 크기와 날짜를 같이 돌려준다.
    public struct Summary: Sendable, Equatable {
        public let bytes: Int64
        public let dates: FileDates

        public static let empty = Summary(bytes: 0, dates: .unknown)
    }

    /// 하위 전체 합계와 날짜. 접근할 수 없는 항목은 건너뛴다 —
    /// 권한 없는 파일 하나 때문에 스캔 전체가 실패하면 안 된다.
    ///
    /// 심볼릭 링크는 따라가지 않는다. 따라가면 링크 대상 용량이 중복 집계되고,
    /// 허용 루트 밖 용량이 정리 후보 크기에 섞인다.
    ///
    /// **순회를 두 번 돌지 않는다.** 크기를 세려면 어차피 하위를 전부 훑어야 하고,
    /// 그때 수정 시각도 같이 손에 들어온다. 예전에는 `StaleCacheScanner`가 같은 트리를
    /// 크기용 한 번, 날짜용 한 번 돌았다.
    public static func summary(at url: URL) -> Summary {
        guard let values = try? url.resourceValues(forKeys: keys) else { return .empty }
        if values.isSymbolicLink == true { return .empty }
        let created = values.creationDate
        guard values.isDirectory == true else {
            return Summary(bytes: allocated(values),
                           dates: FileDates(created: created,
                                            lastUsed: values.contentModificationDate))
        }

        // 바로 아래 폴더들을 여러 스레드로 나눠 잰다. `getattrlistbulk`만으로는 1.3배였고
        // (실측 ~/Code 63→48초) 나눠야 SSD가 여러 곳을 동시에 읽는다.
        let path = url.standardizedFileURL.path
        guard let entries = BulkDirectory.entries(atPath: path) else {
            return Summary(bytes: 0, dates: FileDates(created: created))
        }
        var top = Tally()
        var folders: [String] = []
        for entry in entries {
            if entry.kind == .directory {
                folders.append(BulkDirectory.join(path, entry.name))
            } else {
                top.add(entry)
            }
        }
        let below = folders.count > 1 ? folders.concurrentMap(Tally.walk) : folders.map(Tally.walk)
        let total = below.reduce(top) { $0.merged($1) }
        return Summary(bytes: total.bytes, dates: FileDates(created: created, lastUsed: total.newest))
    }

    /// 한 갈래의 합계와 가장 최근 수정 시각.
    private struct Tally: Sendable {
        var bytes: Int64 = 0
        var newest: Date?

        mutating func add(_ entry: BulkEntry) {
            switch entry.kind {
            case .directory, .symlink:
                // 링크는 세지도 따라가지도 않는다.
                return
            case .file, .other:
                bytes += entry.allocated
                // **일반 파일의 mtime만 센다.** 디렉토리 mtime은 항목이 추가·삭제되거나
                // 다른 프로세스가 건드리기만 해도 갱신돼서, 포함하면 331일 묵은 캐시가
                // "오늘 쓴 것"으로 보인다 (실측에서 이 때문에 검출이 통째로 실패했다).
                if entry.kind == .file, let modified = entry.modified,
                   newest == nil || modified > newest! {
                    newest = modified
                }
            }
        }

        func merged(_ other: Tally) -> Tally {
            var result = self
            result.bytes += other.bytes
            if let date = other.newest, result.newest == nil || date > result.newest! {
                result.newest = date
            }
            return result
        }

        /// 폴더 하나 아래 전부. 한 스레드에서 스택으로 훑는다.
        @Sendable static func walk(_ root: String) -> Tally {
            var tally = Tally()
            var pending = [root]
            while let path = pending.popLast() {
                // 접근 실패는 무시하고 계속한다 — 권한 없는 폴더 하나 때문에 전체가 실패하면 안 된다.
                guard let entries = BulkDirectory.entries(atPath: path) else { continue }
                for entry in entries {
                    if entry.kind == .directory {
                        pending.append(BulkDirectory.join(path, entry.name))
                    } else {
                        tally.add(entry)
                    }
                }
            }
            return tally
        }
    }

    /// 크기만 필요한 곳을 위한 얇은 래퍼.
    public static func bytes(at url: URL) -> Int64 { summary(at: url).bytes }

    /// 논리 크기가 아니라 할당 크기를 쓴다. 지웠을 때 실제로 회수되는 양이기 때문이다.
    private static func allocated(_ v: URLResourceValues) -> Int64 {
        Int64(v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? 0)
    }
}
