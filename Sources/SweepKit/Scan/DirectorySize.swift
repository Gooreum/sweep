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

        guard let walker = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [],
            errorHandler: { _, _ in true }      // 접근 실패는 무시하고 계속한다
        ) else { return Summary(bytes: 0, dates: FileDates(created: created)) }

        var total: Int64 = 0
        var newest: Date?
        for case let child as URL in walker {
            guard let v = try? child.resourceValues(forKeys: keys) else { continue }
            // 링크는 세지 않고 넘어가기만 한다. 열거자는 심볼릭 링크를 따라 내려가지
            // 않으므로 그것으로 충분하다.
            //
            // 여기서 skipDescendants()를 부르면 안 된다. 그 호출은 "가장 최근에 얻은
            // 디렉토리"의 하위를 건너뛰는데, 링크는 디렉토리가 아니라서 대신 **부모의
            // 나머지 하위가 통째로 잘려나간다.** 실측에서 261MB짜리 캐시가 3MB로
            // 집계되는 원인이었다.
            if v.isSymbolicLink == true { continue }
            guard v.isDirectory != true else { continue }
            total += allocated(v)

            // **일반 파일의 mtime만 센다.** 디렉토리 mtime은 항목이 추가·삭제되거나
            // 다른 프로세스가 건드리기만 해도 갱신돼서, 포함하면 331일 묵은 캐시가
            // "오늘 쓴 것"으로 보인다 (실측에서 이 때문에 검출이 통째로 실패했다).
            if v.isRegularFile == true, let modified = v.contentModificationDate,
               newest == nil || modified > newest! {
                newest = modified
            }
        }
        return Summary(bytes: total, dates: FileDates(created: created, lastUsed: newest))
    }

    /// 크기만 필요한 곳을 위한 얇은 래퍼.
    public static func bytes(at url: URL) -> Int64 { summary(at: url).bytes }

    /// 논리 크기가 아니라 할당 크기를 쓴다. 지웠을 때 실제로 회수되는 양이기 때문이다.
    private static func allocated(_ v: URLResourceValues) -> Int64 {
        Int64(v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? 0)
    }
}
