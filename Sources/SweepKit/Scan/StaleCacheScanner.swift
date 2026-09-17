import Foundation

/// 오래 손대지 않은 `~/Library/Caches` 항목을 찾는다.
///
/// 설치된 앱 bundle id와 대조하는 방식은 쓰지 않는다. 실측 결과 오탐이 100%였다 —
/// reverse-DNS 캐시 이름은 앱만의 것이 아니라 헬퍼·XPC 서비스·업데이터도 같은 규칙을 쓴다.
/// 대신 최근 수정 시각만 본다. "주인이 사라졌다"가 아니라 "오래 안 썼다"고만 말한다.
public struct StaleCacheScanner: CleanupScanner {
    public let category: ScanCategory = .staleCache

    /// 이 기간 이상 아무것도 수정되지 않았으면 묵은 것으로 본다.
    public let staleAfter: TimeInterval
    /// 이 크기 미만은 묵었어도 회수량이 미미해 목록만 어지럽힌다.
    public let minimumSize: Int64

    private let home: URL

    public init(staleAfter: TimeInterval = 90 * 86_400,
                minimumSize: Int64 = 1024 * 1024,
                home: URL = Sandbox.userHome) {
        self.staleAfter = staleAfter
        self.minimumSize = minimumSize
        self.home = home
    }

    /// 실측 0.88초. 1초 안에 끝나므로 중간 보고 없이 완료 시점만 알린다.
    public var progressWeight: Double { 0.9 }

    public func scan() async -> [CleanupItem] {
        let caches = home.appending(path: "Library/Caches")
        let known = DevCacheScanner.knownCacheNames

        return children(of: caches).compactMap { url in
            // DevCacheScanner가 이미 safe로 보고하는 항목은 건너뛴다.
            // 두 번 세면 합계가 부풀고 같은 항목이 목록에 두 번 나온다.
            guard !known.contains(url.lastPathComponent) else { return nil }

            // 크기와 날짜를 **한 번의 순회**로 얻는다. 예전에는 같은 트리를
            // 크기용 한 번, 날짜용 한 번 돌았다.
            let found = DirectorySize.summary(at: url)
            guard found.bytes >= minimumSize else { return nil }

            guard let newest = found.dates.lastUsed else { return nil }
            let idle = Date().timeIntervalSince(newest)
            guard idle >= staleAfter else { return nil }

            return CleanupItem(
                url: url,
                size: found.bytes,
                category: .staleCache,
                // 주인이 살아 있을 수 있다. 기본 선택에서 빼 사용자가 직접 고르게 한다.
                safety: .caution,
                detail: "\(Int(idle / 86_400))일 동안 쓰이지 않았습니다",
                dates: found.dates)
        }
    }

    /// 하위 전체에서 가장 최근 수정 시각과 지금의 차이. 읽을 수 없으면 nil.
    ///
    /// "하위 어느 파일이든 최근에 손댔으면 이 캐시는 살아 있다"는 규칙은
    /// `DirectorySize.summary(at:)`가 크기를 세면서 같이 지킨다 —
    /// 여기서 트리를 한 번 더 돌지 않는다.
    static func idleInterval(of url: URL, now: Date = Date()) -> TimeInterval? {
        guard let newest = DirectorySize.summary(at: url).dates.lastUsed else { return nil }
        return now.timeIntervalSince(newest)
    }
}
