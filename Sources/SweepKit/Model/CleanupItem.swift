import Foundation

/// 스캐너가 찾아낸 정리 후보 하나.
///
/// 스캐너 종류와 무관하게 UI와 `Remover`는 이 타입만 다룬다.
public struct CleanupItem: Sendable, Hashable, Identifiable {
    /// 삭제 대상 경로.
    public let url: URL
    /// 바이트 단위 크기. 디렉토리면 하위 전체 합계.
    public let size: Int64
    public let category: ScanCategory
    public let safety: SafetyLevel
    /// 사용자에게 보여줄 부연 설명. 예: "Simulator (PID 81652)가 쓰는 중 · 33MB/분 증가"
    public let detail: String

    public var id: URL { url }

    public init(
        url: URL,
        size: Int64,
        category: ScanCategory,
        safety: SafetyLevel,
        detail: String = ""
    ) {
        self.url = url
        self.size = size
        self.category = category
        self.safety = safety
        self.detail = detail
    }

    /// 사람이 읽는 크기 문자열. ("152.1 GB")
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    /// 목록에 보여줄 이름. 경로 마지막 구성요소.
    public var displayName: String { url.lastPathComponent }

    public var isSelectedByDefault: Bool { safety.isSelectedByDefault }
}

extension Array where Element == CleanupItem {
    /// 회수 가능한 총 바이트.
    public var totalSize: Int64 { reduce(0) { $0 + $1.size } }

    public var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}
