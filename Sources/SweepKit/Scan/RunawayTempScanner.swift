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

    /// 사용자 임시 컨테이너의 `C`·`T`와 `/private/tmp`.
    ///
    /// `/private/var/folders`를 직접 훑으면 한 단계 아래가 root 소유 버킷(`mg`)이라
    /// 후보가 "모든 앱의 임시 데이터가 합쳐진 덩어리" 하나로 뭉개진다.
    /// 폭주하는 것은 개별 파일이므로 개별 파일이 보이는 깊이에서 훑어야 한다.
    public static var defaultRoots: [URL] {
        ProtectedPaths.userTemporaryRoots + [URL(filePath: "/private/tmp")]
    }

    /// `roots`는 테스트에서 샌드박스를 넣기 위해 열어 둔다 —
    /// 실제 /private/tmp에 100MB짜리 픽스처를 만들 수는 없다.
    public init(samplingInterval: Duration = .seconds(3),
                minimumSize: Int64 = 100 * 1024 * 1024,
                roots: [URL] = RunawayTempScanner.defaultRoots) {
        self.samplingInterval = samplingInterval
        self.minimumSize = minimumSize
        self.roots = roots
    }

    /// 실측 41초로 전체 스캔 시간의 94%를 차지한다. 다른 스캐너는 1초 안팎이다.
    public var progressWeight: Double { 40 }

    public func scan() async -> [CleanupItem] {
        await scan(onProgress: { _ in })
    }

    /// 두 번의 전체 순회가 시간을 다 쓰므로, 후보 하나를 잴 때마다 진행을 알린다.
    /// 그러지 않으면 40초 동안 진행률이 한 자리에 멈춰 있다.
    public func scan(onProgress: @escaping @Sendable (Double) -> Void) async -> [CleanupItem] {
        let candidates = roots.flatMap { children(of: $0) }
            .filter { ProtectedPaths.isRemovable($0) }
        onProgress(Self.listingShare)
        guard !candidates.isEmpty else { onProgress(1); return [] }

        // 1차 샘플 — 큰 것만 남긴다. 작은 것까지 두 번 세면 스캔이 느려진다.
        var measured: [(url: URL, size: Int64)] = []
        for (index, url) in candidates.enumerated() {
            measured.append((url: url, size: DirectorySize.bytes(at: url)))
            onProgress(Self.listingShare
                       + Self.passShare * Double(index + 1) / Double(candidates.count))
        }
        let first = measured.filter { $0.size >= minimumSize }
        guard !first.isEmpty else { onProgress(1); return [] }

        try? await Task.sleep(for: samplingInterval)
        let afterSleep = Self.listingShare + Self.passShare + Self.sleepShare
        onProgress(afterSleep)

        // 2차 샘플 — 증가분이 폭주 여부를 가른다.
        var found: [CleanupItem] = []
        for (index, sample) in first.enumerated() {
            defer {
                onProgress(afterSleep
                           + Self.passShare * Double(index + 1) / Double(first.count))
            }
            let now = DirectorySize.bytes(at: sample.url)
            guard now > 0 else { continue }         // 그새 사라졌다
            let growth = now - sample.size
            found.append(CleanupItem(
                url: sample.url,
                size: now,
                category: .runawayTemp,
                // 증가 중이라면 무언가 쓰고 있다는 뜻이다. 함부로 지우게 두지 않는다.
                safety: growth > 0 ? .caution : .safe,
                detail: Self.detail(growth: growth, over: samplingInterval)))
        }
        onProgress(1)
        return found
    }

    // 진행률을 시간 비중대로 쪼갠다. 두 번의 순회가 대부분을 차지하고
    // 대기는 samplingInterval(기본 3초)로 고정이다.
    private static let listingShare = 0.02
    private static let passShare = 0.44
    private static let sleepShare = 0.10

    /// "33.0 MB/분 증가 중"처럼 사람이 판단할 수 있는 속도로 환산한다.
    static func detail(growth: Int64, over interval: Duration) -> String {
        guard growth > 0 else { return "증가 없음 — 남겨진 임시 파일" }
        let seconds = Double(interval.components.seconds)
        guard seconds > 0 else { return "증가 중" }
        let perMinute = Int64(Double(growth) / seconds * 60)
        return "\(ByteCountFormatter.string(fromByteCount: perMinute, countStyle: .file))/분 증가 중"
    }
}
