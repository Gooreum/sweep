import Foundation

/// `~/Downloads`의 크고 독립적인 파일을 찾는다.
///
/// 허용 루트 전체를 훑지 않는 이유: 실측 결과 100MB 이상 파일 11개 중 8개가
/// 다른 스캐너가 이미 보고하는 디렉토리의 **내부** 파일이었다.
/// 같은 바이트를 두 번 세는 데다, 번들 안의 바이너리 하나만 지우면 번들이 깨지고
/// 회수도 되지 않는다. 통째로 지울 수 있는 독립 파일만 후보로 올린다.
public struct LargeFileScanner: CleanupScanner {
    public let category: ScanCategory = .largeFile

    public let minimumSize: Int64

    private let home: URL

    public init(minimumSize: Int64 = 100 * 1024 * 1024,
                home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.minimumSize = minimumSize
        self.home = home
    }

    public func scan() async -> [CleanupItem] {
        let root = home.appending(path: "Downloads")
        return Self.largeFiles(under: root, minimumSize: minimumSize).map { found in
            CleanupItem(
                url: found.url,
                size: found.size,
                category: .largeFile,
                // 사용자가 일부러 받은 파일이다. 자동 선택하지 않는다.
                safety: .caution,
                detail: Self.detail(modified: found.modified))
        }
    }

    /// "3개월 전에 받았습니다"처럼 판단 근거가 되는 시점을 준다.
    static func detail(modified: Date, now: Date = Date()) -> String {
        let days = Int(now.timeIntervalSince(modified) / 86_400)
        switch days {
        case ..<1: return "오늘 받았습니다"
        case ..<30: return "\(days)일 전에 받았습니다"
        default: return "\(days / 30)개월 전에 받았습니다"
        }
    }

    /// 임계 이상 일반 파일. 심볼릭 링크는 제외한다 —
    /// 링크를 지워도 용량은 회수되지 않고 대상만 고아가 된다.
    private static func largeFiles(under root: URL, minimumSize: Int64)
        -> [(url: URL, size: Int64, modified: Date)] {
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey, .isSymbolicLinkKey,
            .totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .contentModificationDateKey,
        ]
        guard let walker = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else { return [] }

        var found: [(url: URL, size: Int64, modified: Date)] = []
        for case let url as URL in walker {
            guard let v = try? url.resourceValues(forKeys: keys),
                  v.isSymbolicLink != true,
                  v.isRegularFile == true
            else { continue }

            let size = Int64(v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? 0)
            guard size >= minimumSize else { continue }

            found.append((url: url, size: size,
                          modified: v.contentModificationDate ?? .distantPast))
        }
        return found
    }
}
