import Foundation

/// 프로젝트 안에서 다시 설치·빌드하면 되살아나는 폴더와, 그 짝이 되는 설정 파일.
///
/// 스캐너(`ProjectArtifactScanner`), 관문(`RemovalScope.projectArtifacts`),
/// 큰 파일 탐색(`UserFileWalker`)이 **이 표 하나**를 같이 쓴다. 판정을 두 벌로 두면
/// 스캐너가 찾은 것을 관문이 버리거나, 관문이 연 것을 스캐너가 모른다.
///
/// 이름만 보지 않는다. `target`·`build`는 흔한 이름이라 사용자가 만든 폴더일 수 있다.
/// **같은 폴더에 설정 파일이 실제로 있을 때만** 산출물로 친다.
public struct ProjectArtifactRule: Sendable, Equatable {
    /// 산출물 폴더 이름.
    public let name: String
    /// 같은 폴더에 하나라도 있어야 하는 설정 파일.
    public let manifests: [String]
    /// 다시 설치했을 때 같은 버전이 오는지 보장하는 파일. 비어 있으면 필요 없다(순수 빌드 산출물).
    public let lockFiles: [String]
    /// 지운 뒤 다시 만드는 법. 목록 설명 줄에 쓴다.
    public let rebuildHint: String

    /// 짝이 맞은 결과. 어느 설정 파일로 맞았는지 화면에 말해야 한다.
    public struct Match: Sendable, Equatable {
        public let rule: ProjectArtifactRule
        public let manifest: String
    }

    /// MVP 규칙. `dist`·`vendor`는 커밋된 결과물일 수 있어 넣지 않는다.
    public static let all: [ProjectArtifactRule] = [
        .init(name: "node_modules", manifests: ["package.json"],
              lockFiles: ["package-lock.json", "yarn.lock", "pnpm-lock.yaml", "bun.lockb"],
              rebuildHint: String(localized: "npm install로 다시 설치해요")),
        .init(name: "target", manifests: ["Cargo.toml"], lockFiles: [],
              rebuildHint: String(localized: "cargo build로 다시 만들어요")),
        .init(name: "target", manifests: ["pom.xml"], lockFiles: [],
              rebuildHint: String(localized: "mvn package로 다시 만들어요")),
        .init(name: "Pods", manifests: ["Podfile"], lockFiles: ["Podfile.lock"],
              rebuildHint: String(localized: "pod install로 다시 설치해요")),
        .init(name: "build", manifests: ["build.gradle", "build.gradle.kts"], lockFiles: [],
              rebuildHint: String(localized: "gradle build로 다시 만들어요")),
        .init(name: ".build", manifests: ["Package.swift"], lockFiles: [],
              rebuildHint: String(localized: "swift build로 다시 만들어요")),
    ]

    /// 규칙표에 있는 폴더 이름. 짝 여부와 관계없이 스캐너가 이 안으로 내려가지 않는다.
    public static let names: Set<String> = Set(all.map(\.name))

    /// 이 경로가 짝이 맞는 산출물인가.
    ///
    /// 산출물 자신도 설정 파일도 **링크를 따라가지 않는다.** 링크인 `node_modules`는
    /// 바깥을 가리킬 수 있고, 링크인 `package.json`은 짝이 있다고 속일 수 있다.
    /// 설정 파일은 일반 파일이어야 한다 — 같은 이름의 폴더는 짝이 아니다.
    public static func match(_ url: URL) -> Match? {
        let name = url.lastPathComponent
        guard names.contains(name), isKind(url, S_IFDIR) else { return nil }
        let project = url.deletingLastPathComponent()
        for rule in all where rule.name == name {
            if let manifest = rule.manifests.first(where: {
                isKind(project.appending(path: $0), S_IFREG)
            }) {
                return Match(rule: rule, manifest: manifest)
            }
        }
        return nil
    }

    /// lock 파일이 있어야 하는 규칙인데 프로젝트에 하나도 없는가.
    /// 그러면 다시 설치했을 때 다른 버전이 올 수 있다.
    public func needsLock(in project: URL) -> Bool {
        !lockFiles.isEmpty && !lockFiles.contains {
            Self.isKind(project.appending(path: $0), S_IFREG)
        }
    }

    /// lstat으로 종류를 본다. 링크면 링크로 나와 폴더·파일 어느 쪽에도 맞지 않는다.
    private static func isKind(_ url: URL, _ kind: mode_t) -> Bool {
        var info = stat()
        guard lstat(url.path, &info) == 0 else { return false }
        return info.st_mode & S_IFMT == kind
    }
}
