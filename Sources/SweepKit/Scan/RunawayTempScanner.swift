import Foundation

/// 두 시점의 크기 차이로 **지금 커지고 있는** 임시 파일을 찾는다.
///
/// 단순히 큰 파일이 아니다. 크기가 그대로인 오래된 임시 파일은 폭주가 아니다.
public struct RunawayTempScanner: CleanupScanner {
    public let category: ScanCategory = .runawayTemp

    /// 두 샘플 사이 간격. 짧으면 증가를 못 잡고, 길면 스캔이 느려진다.
    public let samplingInterval: Duration
    /// 이 크기 미만은 애초에 후보로 보지 않는다.
    public let minimumSize: Int64

    private let roots: [URL]

    public static let defaultRoots: [URL] = [
        URL(filePath: "/private/var/folders"),
        URL(filePath: "/private/tmp"),
    ]

    /// `roots`는 테스트에서 샌드박스를 넣기 위해 열어 둔다 —
    /// 실제 /private/tmp에 100MB짜리 픽스처를 만들 수는 없다.
    public init(samplingInterval: Duration = .seconds(3),
                minimumSize: Int64 = 100 * 1024 * 1024,
                roots: [URL] = RunawayTempScanner.defaultRoots) {
        self.samplingInterval = samplingInterval
        self.minimumSize = minimumSize
        self.roots = roots
    }

    public func scan() async -> [CleanupItem] {
        let candidates = roots.flatMap { children(of: $0) }
            .filter { ProtectedPaths.isRemovable($0) }

        // 1차 샘플 — 큰 것만 남긴다. 작은 것까지 두 번 세면 스캔이 느려진다.
        let first = candidates
            .map { (url: $0, size: DirectorySize.bytes(at: $0)) }
            .filter { $0.size >= minimumSize }
        guard !first.isEmpty else { return [] }

        try? await Task.sleep(for: samplingInterval)

        // 2차 샘플 — 증가분이 폭주 여부를 가른다.
        return first.compactMap { sample in
            let now = DirectorySize.bytes(at: sample.url)
            guard now > 0 else { return nil }       // 그새 사라졌다
            let growth = now - sample.size
            return CleanupItem(
                url: sample.url,
                size: now,
                category: .runawayTemp,
                // 증가 중이라면 무언가 쓰고 있다는 뜻이다. 함부로 지우게 두지 않는다.
                safety: growth > 0 ? .caution : .safe,
                detail: Self.detail(growth: growth, over: samplingInterval))
        }
    }

    /// "33.0 MB/분 증가 중"처럼 사람이 판단할 수 있는 속도로 환산한다.
    static func detail(growth: Int64, over interval: Duration) -> String {
        guard growth > 0 else { return "증가 없음 — 남겨진 임시 파일" }
        let seconds = Double(interval.components.seconds)
        guard seconds > 0 else { return "증가 중" }
        let perMinute = Int64(Double(growth) / seconds * 60)
        return "\(ByteCountFormatter.string(fromByteCount: perMinute, countStyle: .file))/분 증가 중"
    }
}
