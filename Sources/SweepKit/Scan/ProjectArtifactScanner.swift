import Foundation

/// 등록한 프로젝트 폴더(`ProjectFolders`) 아래에서 설정 파일과 짝이 맞는
/// 설치·빌드 폴더(`ProjectArtifactRule`)를 찾는다.
///
/// 다시 설치하면 되살아나므로 기본은 safe다. 다만 최근에 고친 프로젝트이거나
/// lock 파일이 없어 다시 설치하면 버전이 달라질 수 있으면 caution으로 둔다.
public struct ProjectArtifactScanner: CleanupScanner {
    public let category: ScanCategory = .projectArtifact

    private let roots: [URL]
    private let now: Date
    private let recentDays: Int

    /// 모노레포 `packages/*/node_modules`까지 닿는 깊이.
    static let maxDepth = 8

    public init(roots: [URL] = ProjectFolders.roots(), now: Date = Date(), recentDays: Int = 14) {
        self.roots = roots
        self.now = now
        self.recentDays = recentDays
    }

    /// 첫 값. 산출물마다 하위 전체 크기를 세므로 node_modules가 많으면 수십 초가 걸릴 수 있다.
    /// 실측 뒤 조정한다.
    public var progressWeight: Double { 2 }

    public func scan() async -> [CleanupItem] {
        await scan(onProgress: { _ in })
    }

    /// 산출물 하나를 셀 때마다 알린다. 찾기보다 크기 세기가 훨씬 오래 걸린다.
    public func scan(onProgress: @escaping @Sendable (Double) -> Void) async -> [CleanupItem] {
        let found = roots.flatMap { Self.artifacts(under: $0) }
        var items: [CleanupItem] = []
        for (index, (url, match)) in found.enumerated() {
            if Task.isCancelled { break }
            let summary = DirectorySize.summary(at: url)
            let (safety, detail) = assess(project: url.deletingLastPathComponent(), match: match)
            items.append(CleanupItem(url: url, size: summary.bytes, category: .projectArtifact,
                                     safety: safety, detail: detail, dates: summary.dates))
            onProgress(Double(index + 1) / Double(found.count))
        }
        if found.isEmpty { onProgress(1) }
        return items.sorted { $0.size > $1.size }
    }

    /// 루트 아래의 짝이 맞는 산출물.
    ///
    /// 규칙표 이름과 같은 폴더는 **짝이 맞든 아니든** 안으로 내려가지 않는다 —
    /// node_modules 안의 node_modules를 따로 세지 않고, 짝 없는 폴더 안도 헤매지 않는다.
    /// 숨김 폴더(`.git` 등)는 내려가지 않되 `.build`만 통과시킨다. 링크는 따라가지 않는다.
    static func artifacts(under root: URL) -> [(URL, ProjectArtifactRule.Match)] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey]
        guard let walker = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: keys,
            options: [.skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else { return [] }

        var found: [(URL, ProjectArtifactRule.Match)] = []
        for case let url as URL in walker {
            guard let v = try? url.resourceValues(forKeys: Set(keys)),
                  v.isSymbolicLink != true, v.isDirectory == true
            else { continue }
            // 디렉토리일 때만 skipDescendants를 부른다. 파일·링크에서 부르면
            // 부모의 나머지 하위가 잘린다(`DirectorySize` 참고).
            let name = url.lastPathComponent
            if ProjectArtifactRule.names.contains(name) {
                walker.skipDescendants()
                if let match = ProjectArtifactRule.match(url) { found.append((url, match)) }
                continue
            }
            if name.hasPrefix(".") || walker.level >= maxDepth {
                walker.skipDescendants()
            }
        }
        return found
    }

    /// 안전도와 설명. 사유가 있으면 설명 맨 앞에 둔다 — 사유는 늘 보이는 자리에 있어야 한다.
    func assess(project: URL, match: ProjectArtifactRule.Match) -> (SafetyLevel, String) {
        let hint = match.rule.rebuildHint
        if let touched = Self.lastActivity(of: project),
           touched > now.addingTimeInterval(-Double(recentDays) * 86_400) {
            return (.caution, String(localized: "최근 \(recentDays)일 안에 고친 프로젝트예요 · \(hint)"))
        }
        if match.rule.needsLock(in: project) {
            return (.caution, String(localized: "lock 파일이 없어 다시 설치하면 버전이 달라질 수 있어요 · \(hint)"))
        }
        return (.safe, String(localized: "\(match.manifest) 짝 · \(hint)"))
    }

    /// 프로젝트를 마지막으로 고친 때. 프로젝트 폴더 **바로 아래 항목**의 최신 수정일이다.
    /// 산출물 폴더는 뺀다 — 빌드만 돌려도 갱신돼 "최근에 고친" 것으로 보인다.
    static func lastActivity(of project: URL) -> Date? {
        let children = (try? FileManager.default.contentsOfDirectory(
            at: project, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return children
            .filter { !ProjectArtifactRule.names.contains($0.lastPathComponent)
                && $0.lastPathComponent != ".DS_Store" }
            .compactMap { try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate }
            .max()
    }
}
