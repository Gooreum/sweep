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
    /// 설정 파일이 폴더 **안**에 있어야 한다(가상환경의 `pyvenv.cfg`). 기본은 폴더 옆이다.
    public let manifestsInside: Bool
    /// 프로젝트의 `.gitignore`에 이 폴더가 적혀 있어야 한다. `dist`·`build`·`vendor`처럼
    /// 커밋된 결과물이거나 직접 만든 파일일 수 있는 이름에 건다(`GitIgnore`).
    public let requiresIgnore: Bool

    public init(name: String, manifests: [String], lockFiles: [String], rebuildHint: String,
                manifestsInside: Bool = false, requiresIgnore: Bool = false) {
        self.name = name
        self.manifests = manifests
        self.lockFiles = lockFiles
        self.rebuildHint = rebuildHint
        self.manifestsInside = manifestsInside
        self.requiresIgnore = requiresIgnore
    }

    /// 짝이 맞은 결과. 어느 설정 파일로 맞았는지 화면에 말해야 한다.
    public struct Match: Sendable, Equatable {
        public let rule: ProjectArtifactRule
        public let manifest: String
    }

    private static let nodeLocks = ["package-lock.json", "yarn.lock", "pnpm-lock.yaml", "bun.lockb"]

    /// 규칙표. 이름이 흔하거나 커밋될 수 있는 `dist`·`build`(JS)·`vendor`는 `.gitignore`에
    /// 적혀 있을 때만, 가상환경은 폴더 안에 `pyvenv.cfg`가 있을 때만 잡는다.
    /// 같은 이름의 규칙이 여럿이면(`target`, `build`, `vendor`) 먼저 맞는 쪽이 이긴다.
    public static let all: [ProjectArtifactRule] = [
        .init(name: "node_modules", manifests: ["package.json"],
              lockFiles: ["package-lock.json", "yarn.lock", "pnpm-lock.yaml", "bun.lockb"],
              rebuildHint: String(localized: "지워도 다시 설치하면 생겨요 (npm install)")),
        .init(name: "target", manifests: ["Cargo.toml"], lockFiles: [],
              rebuildHint: String(localized: "지워도 다시 빌드하면 생겨요 (cargo build)")),
        .init(name: "target", manifests: ["pom.xml"], lockFiles: [],
              rebuildHint: String(localized: "지워도 다시 빌드하면 생겨요 (mvn package)")),
        .init(name: "Pods", manifests: ["Podfile"], lockFiles: ["Podfile.lock"],
              rebuildHint: String(localized: "지워도 다시 설치하면 생겨요 (pod install)")),
        .init(name: "build", manifests: ["build.gradle", "build.gradle.kts"], lockFiles: [],
              rebuildHint: String(localized: "지워도 다시 빌드하면 생겨요 (gradle build)")),
        .init(name: ".build", manifests: ["Package.swift"], lockFiles: [],
              rebuildHint: String(localized: "지워도 다시 빌드하면 생겨요 (swift build)")),
        .init(name: ".next", manifests: ["package.json"], lockFiles: [],
              rebuildHint: String(localized: "지워도 다시 빌드하면 생겨요 (next build)")),
        .init(name: ".nuxt", manifests: ["package.json"], lockFiles: [],
              rebuildHint: String(localized: "지워도 다시 빌드하면 생겨요 (nuxt build)")),
        .init(name: ".svelte-kit", manifests: ["package.json"], lockFiles: [],
              rebuildHint: String(localized: "vite dev로 SvelteKit 파일을 다시 만들어요")),
        .init(name: ".expo", manifests: ["package.json"], lockFiles: [],
              rebuildHint: String(localized: "expo start로 Expo 설정을 다시 만들어요")),
        .init(name: ".gradle",
              manifests: ["build.gradle", "build.gradle.kts", "settings.gradle", "settings.gradle.kts"],
              lockFiles: [], rebuildHint: String(localized: "지워도 다시 빌드하면 생겨요 (gradle build)")),
        .init(name: ".dart_tool", manifests: ["pubspec.yaml"], lockFiles: [],
              rebuildHint: String(localized: "지워도 다시 받으면 생겨요 (flutter pub get)")),
        .init(name: ".venv", manifests: ["pyvenv.cfg"],
              lockFiles: ["requirements.txt", "poetry.lock", "Pipfile.lock", "uv.lock"],
              rebuildHint: String(localized: "Python 가상환경이에요. 지워도 다시 만들 수 있어요"),
              manifestsInside: true),
        .init(name: "venv", manifests: ["pyvenv.cfg"],
              lockFiles: ["requirements.txt", "poetry.lock", "Pipfile.lock", "uv.lock"],
              rebuildHint: String(localized: "Python 가상환경이에요. 지워도 다시 만들 수 있어요"),
              manifestsInside: true),
        .init(name: "dist", manifests: ["package.json"], lockFiles: nodeLocks,
              rebuildHint: String(localized: "지워도 다시 빌드하면 생겨요 (npm run build)"), requiresIgnore: true),
        .init(name: "build", manifests: ["package.json"], lockFiles: nodeLocks,
              rebuildHint: String(localized: "지워도 다시 빌드하면 생겨요 (npm run build)"), requiresIgnore: true),
        .init(name: "vendor", manifests: ["composer.json"], lockFiles: ["composer.lock"],
              rebuildHint: String(localized: "지워도 다시 설치하면 생겨요 (composer install)"), requiresIgnore: true),
        .init(name: "vendor", manifests: ["go.mod"], lockFiles: [],
              rebuildHint: String(localized: "지워도 다시 받으면 생겨요 (go mod vendor)"), requiresIgnore: true),
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
            // 가상환경은 설정 파일이 폴더 안에 있고, 나머지는 폴더 옆에 있다
            let base = rule.manifestsInside ? url : project
            guard let manifest = rule.manifests.first(where: {
                isKind(base.appending(path: $0), S_IFREG)
            }) else { continue }
            // 커밋될 수 있는 이름은 저장소가 "만들어지는 것"이라고 적어 둔 것만 믿는다
            if rule.requiresIgnore, !GitIgnore.lists(name, from: project) { continue }
            return Match(rule: rule, manifest: manifest)
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
