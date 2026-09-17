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
    /// 만든 날 / 마지막 사용. 스캐너가 크기를 세는 순회에서 같이 읽어 채운다.
    public let dates: FileDates

    public var id: URL { url }

    public init(
        url: URL,
        size: Int64,
        category: ScanCategory,
        safety: SafetyLevel,
        detail: String = "",
        dates: FileDates = .unknown
    ) {
        self.url = url
        self.size = size
        self.category = category
        self.safety = safety
        self.detail = detail
        self.dates = dates
    }

    /// 사람이 읽는 크기 문자열. ("152.1 GB")
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    /// 목록에 보여줄 이름. 경로 마지막 구성요소.
    public var displayName: String { url.lastPathComponent }

    /// 우측 열 둘째 줄. "2026.05.18 만듦 · 4개월 전 사용"
    ///
    /// **둘을 한 줄에 같이 둔다.** 처음에는 만든 날을 왼쪽 둘째 줄에 두고 설명이
    /// 없을 때만 보여줬는데, 실기에서 정크 항목은 거의 전부 설명이 붙어 있어
    /// **만든 날이 한 줄도 안 나왔다.** 있으나 마나 한 표시였다.
    ///
    /// 한쪽만 읽히면 읽히는 쪽만 준다. 둘 다 없으면 nil — 빈 줄을 만들지 않는다.
    public func datesLine(now: Date = Date()) -> String? {
        let parts = [dates.createdLabel(), dates.lastUsedLabel(now: now)].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    public var isSelectedByDefault: Bool { safety.isSelectedByDefault }
}

extension Array where Element == CleanupItem {
    /// 회수 가능한 총 바이트.
    public var totalSize: Int64 { reduce(0) { $0 + $1.size } }

    public var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}
