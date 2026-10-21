import Testing
import Foundation
@testable import SweepKit

/// 개발 프로젝트 산출물: 규칙표·스캐너·관문·폴더 목록.
@Suite("ProjectArtifact")
struct ProjectArtifactTests {

    private let fm = FileManager.default

    /// 임시 루트. 관문이 경로 구성요소로 비교하므로 링크(`/var` → `/private/var`)를 푼다.
    private func makeRoot() throws -> (root: URL, cleanup: () -> Void) {
        let root = URL(filePath: NSTemporaryDirectory())
            .appending(path: "sweep-projects-\(UUID().uuidString)")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let real = root.resolvingSymlinksInPath()
        return (real, { try? FileManager.default.removeItem(at: real) })
    }

    private func dir(_ root: URL, _ relative: String) throws -> URL {
        let url = root.appending(path: relative)
        try fm.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @discardableResult
    private func file(_ root: URL, _ relative: String, bytes: Int = 4) throws -> URL {
        let url = root.appending(path: relative)
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 1, count: bytes).write(to: url)
        return url
    }

    /// 글이 든 파일(`.gitignore` 등).
    @discardableResult
    private func file(_ root: URL, _ relative: String, _ text: String) throws -> URL {
        let url = root.appending(path: relative)
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// 프로젝트 바로 아래 항목의 수정일을 옮긴다. 최근 활동 판정이 이것을 본다.
    private func age(_ project: URL, days: Double) throws {
        let date = Date().addingTimeInterval(-days * 86_400)
        for child in try fm.contentsOfDirectory(at: project, includingPropertiesForKeys: nil) {
            try fm.setAttributes([.modificationDate: date], ofItemAtPath: child.path)
        }
    }

    private func components(_ url: URL) -> [String] { url.standardizedFileURL.pathComponents }

    // MARK: - 규칙표

    @Test("설정 파일이 옆에 있어야 짝이 맞는다")
    func matchNeedsManifest() throws {
        let (root, cleanup) = try makeRoot()
        defer { cleanup() }
        try file(root, "a/package.json")
        let paired = try dir(root, "a/node_modules")
        let unpaired = try dir(root, "b/node_modules")
        // 설정 파일 이름의 **폴더**는 짝이 아니다
        try dir(root, "c/Cargo.toml")
        let fakeTarget = try dir(root, "c/target")
        try file(root, "d/pom.xml")
        let maven = try dir(root, "d/target")

        #expect(ProjectArtifactRule.match(paired)?.manifest == "package.json")
        #expect(ProjectArtifactRule.match(unpaired) == nil)
        #expect(ProjectArtifactRule.match(fakeTarget) == nil)
        #expect(ProjectArtifactRule.match(maven)?.manifest == "pom.xml")
        // 규칙표에 없는 이름은 짝이 있어도 아니다
        #expect(ProjectArtifactRule.match(try dir(root, "a/dist")) == nil)
    }

    @Test("링크인 산출물은 짝으로 치지 않는다")
    func symlinkArtifactDoesNotMatch() throws {
        let (root, cleanup) = try makeRoot()
        defer { cleanup() }
        let outside = try makeRoot()
        defer { outside.cleanup() }
        try file(root, "e/package.json")
        try fm.createSymbolicLink(at: root.appending(path: "e/node_modules"),
                                  withDestinationURL: outside.root)
        #expect(ProjectArtifactRule.match(root.appending(path: "e/node_modules")) == nil)
    }

    @Test("lock이 필요한 규칙에서 lock이 없으면 needsLock이다")
    func lockJudgement() throws {
        let (root, cleanup) = try makeRoot()
        defer { cleanup() }
        let node = ProjectArtifactRule.all.first { $0.name == "node_modules" }!
        let cargo = ProjectArtifactRule.all.first { $0.manifests == ["Cargo.toml"] }!
        let project = try dir(root, "p")

        #expect(node.needsLock(in: project))
        #expect(!cargo.needsLock(in: project))
        try file(root, "p/yarn.lock")
        #expect(!node.needsLock(in: project))
    }

    @Test("다시 만들어지는 숨김 폴더도 설정 파일이 옆에 있을 때만 짝이 맞는다")
    func hiddenGeneratedFolders() throws {
        let (root, cleanup) = try makeRoot()
        defer { cleanup() }
        try file(root, "web/package.json")
        try file(root, "app/build.gradle.kts")
        try file(root, "flutter/pubspec.yaml")
        try file(root, "gradle/settings.gradle")

        for name in [".next", ".nuxt", ".svelte-kit", ".expo"] {
            #expect(ProjectArtifactRule.match(try dir(root, "web/\(name)"))?.manifest == "package.json", "\(name)")
            #expect(ProjectArtifactRule.match(try dir(root, "none/\(name)")) == nil, "\(name) 짝 없음")
        }
        #expect(ProjectArtifactRule.match(try dir(root, "app/.gradle"))?.manifest == "build.gradle.kts")
        #expect(ProjectArtifactRule.match(try dir(root, "gradle/.gradle"))?.manifest == "settings.gradle")
        #expect(ProjectArtifactRule.match(try dir(root, "flutter/.dart_tool"))?.manifest == "pubspec.yaml")
    }

    @Test("가상환경은 폴더 안에 pyvenv.cfg가 있을 때만 짝이 맞고, 없으면 그냥 폴더다")
    func virtualEnvironmentNeedsMarkerInside() throws {
        let (root, cleanup) = try makeRoot()
        defer { cleanup() }
        try file(root, "py/.venv/pyvenv.cfg")
        try file(root, "py/venv/pyvenv.cfg")
        try dir(root, "plain/.venv")
        try file(root, "plain/pyvenv.cfg")   // 옆에 있어도 안에 없으면 가상환경이 아니다

        #expect(ProjectArtifactRule.match(root.appending(path: "py/.venv"))?.manifest == "pyvenv.cfg")
        #expect(ProjectArtifactRule.match(root.appending(path: "py/venv"))?.manifest == "pyvenv.cfg")
        #expect(ProjectArtifactRule.match(root.appending(path: "plain/.venv")) == nil)
    }

    @Test("dist·build·vendor는 .gitignore에 적혀 있을 때만 짝이 맞는다")
    func ignoreGatedFolders() throws {
        let (root, cleanup) = try makeRoot()
        defer { cleanup() }
        // 적혀 있음
        try file(root, "ignored/package.json")
        try file(root, "ignored/.gitignore", "dist\n/build\n")
        let dist = try dir(root, "ignored/dist")
        let build = try dir(root, "ignored/build")
        // 적혀 있지 않음 — 커밋된 결과물일 수 있다
        try file(root, "tracked/package.json")
        let trackedDist = try dir(root, "tracked/dist")
        let trackedBuild = try dir(root, "tracked/build")
        // PHP·Go vendor
        try file(root, "php/composer.json")
        try file(root, "php/.gitignore", "vendor/")
        let phpVendor = try dir(root, "php/vendor")
        try file(root, "go/go.mod")
        let goVendor = try dir(root, "go/vendor")   // .gitignore 없음 — Go는 커밋하는 경우가 많다

        #expect(ProjectArtifactRule.match(dist)?.manifest == "package.json")
        #expect(ProjectArtifactRule.match(build)?.manifest == "package.json")
        #expect(ProjectArtifactRule.match(trackedDist) == nil)
        #expect(ProjectArtifactRule.match(trackedBuild) == nil)
        #expect(ProjectArtifactRule.match(phpVendor)?.manifest == "composer.json")
        #expect(ProjectArtifactRule.match(goVendor) == nil)
    }

    @Test("Gradle build는 .gitignore 없이도 짝이 맞고, JS build는 .gitignore가 있어야 한다")
    func buildHasTwoRules() throws {
        let (root, cleanup) = try makeRoot()
        defer { cleanup() }
        try file(root, "g/build.gradle")
        try file(root, "j/package.json")

        #expect(ProjectArtifactRule.match(try dir(root, "g/build"))?.manifest == "build.gradle")
        #expect(ProjectArtifactRule.match(try dir(root, "j/build")) == nil)
        try file(root, "j/.gitignore", "build\n")
        #expect(ProjectArtifactRule.match(root.appending(path: "j/build"))?.manifest == "package.json")
    }

    @Test("가상환경과 JS 결과물은 lock 파일이 없으면 확인 필요다")
    func newRulesNeedLockFiles() throws {
        let (root, cleanup) = try makeRoot()
        defer { cleanup() }
        let venv = ProjectArtifactRule.all.first { $0.name == ".venv" }!
        let dist = ProjectArtifactRule.all.first { $0.name == "dist" }!
        let next = ProjectArtifactRule.all.first { $0.name == ".next" }!
        let project = try dir(root, "p")

        #expect(venv.needsLock(in: project))
        #expect(dist.needsLock(in: project))
        #expect(!next.needsLock(in: project))
        try file(root, "p/requirements.txt")
        try file(root, "p/package-lock.json")
        #expect(!venv.needsLock(in: project))
        #expect(!dist.needsLock(in: project))
    }

    // MARK: - 스캐너

    @Test("새 종류도 스캐너가 찾고, .gitignore에 없는 dist와 짝 없는 폴더는 빠진다")
    func scannerFindsNewKinds() async throws {
        let (root, cleanup) = try makeRoot()
        defer { cleanup() }
        try file(root, "web/package.json")
        try file(root, "web/package-lock.json")
        try file(root, "web/.gitignore", "dist\n")
        try file(root, "web/.next/cache/a", bytes: 3_000)
        try file(root, "web/dist/bundle.js", bytes: 2_000)
        try file(root, "web/build/out.js", bytes: 900)        // .gitignore에 없음
        try file(root, "py/pyvenv.cfg.txt")
        try file(root, "py/.venv/pyvenv.cfg", bytes: 800)
        try file(root, "py/.venv/lib/x", bytes: 1_500)
        try file(root, "lonely/.next/x", bytes: 5_000)        // package.json 없음
        for path in ["web", "py"] { try age(root.appending(path: path), days: 30) }

        let items = await ProjectArtifactScanner(roots: [root], recentDays: 14).scan()
        // `/var`↔`/private/var` 표기가 달라 경로 앞부분은 비교하지 않는다
        let found = Set(items.map {
            $0.url.deletingLastPathComponent().lastPathComponent + "/" + $0.url.lastPathComponent
        })

        #expect(found == ["web/.next", "web/dist", "py/.venv"])
        // lock 파일이 있는 JS 결과물은 안전, 가상환경은 lock이 없어 확인 필요
        #expect(items.first { $0.url.lastPathComponent == "dist" }?.safety == .safe)
        #expect(items.first { $0.url.lastPathComponent == ".venv" }?.safety == .caution)
    }

    @Test("짝이 맞는 산출물만 크기순으로 나오고 중첩·숨김·링크는 빠진다")
    func scannerFindsPairedArtifacts() async throws {
        let (root, cleanup) = try makeRoot()
        defer { cleanup() }
        let outside = try makeRoot()
        defer { outside.cleanup() }

        try file(root, "a/package.json"); try file(root, "a/package-lock.json")
        try file(root, "a/node_modules/x/index.js", bytes: 8_192)
        // node_modules 안의 node_modules는 따로 세지 않는다
        try file(root, "a/node_modules/x/package.json")
        try file(root, "a/node_modules/x/node_modules/y/index.js", bytes: 8_192)
        try file(root, "b/node_modules/z.js", bytes: 8_192)               // 짝 없음
        try file(root, "c/Cargo.toml"); try file(root, "c/target/debug/bin", bytes: 65_536)
        try file(root, "d/target/out", bytes: 8_192)                      // 짝 없음
        try file(outside.root, "pkg/index.js", bytes: 8_192)
        try file(root, "e/package.json"); try file(root, "e/yarn.lock")
        try fm.createSymbolicLink(at: root.appending(path: "e/node_modules"),
                                  withDestinationURL: outside.root.appending(path: "pkg"))
        try file(root, ".git/x/package.json")                              // 숨김 폴더 안
        try file(root, ".git/x/node_modules/a.js", bytes: 8_192)
        try file(root, "f/Package.swift"); try file(root, "f/.build/debug/o", bytes: 8_192)

        let items = await ProjectArtifactScanner(roots: [root]).scan()
        // 열거자는 `/var`를 풀지 않은 경로를 준다. 끝 두 구성요소로 비교한다.
        let paths = items.map { $0.url.pathComponents.suffix(2).joined(separator: "/") }

        #expect(Set(paths) == ["a/node_modules", "c/target", "f/.build"])
        #expect(items.map(\.size) == items.map(\.size).sorted(by: >))
        #expect(items.allSatisfy { $0.category == .projectArtifact })
        // 중첩된 node_modules까지 합쳐서 센다
        let node = items.first { $0.url.lastPathComponent == "node_modules" }!
        #expect(node.size >= 16_384)
    }

    @Test("오래된 프로젝트는 지워도 됨, 최근 프로젝트와 lock 없는 node_modules는 확인 필요")
    func safetyJudgement() async throws {
        let (root, cleanup) = try makeRoot()
        defer { cleanup() }
        try file(root, "old/package.json"); try file(root, "old/package-lock.json")
        try file(root, "old/node_modules/a.js", bytes: 4_096)
        try file(root, "new/package.json"); try file(root, "new/package-lock.json")
        try file(root, "new/node_modules/a.js", bytes: 4_096)
        try file(root, "nolock/package.json")
        try file(root, "nolock/node_modules/a.js", bytes: 4_096)
        try age(root.appending(path: "old"), days: 15)
        try age(root.appending(path: "new"), days: 1)
        try age(root.appending(path: "nolock"), days: 30)

        let items = await ProjectArtifactScanner(roots: [root], recentDays: 14).scan()
        func item(_ project: String) -> CleanupItem? {
            items.first { $0.url.deletingLastPathComponent().lastPathComponent == project }
        }

        #expect(item("old")?.safety == .safe)
        #expect(item("old")?.detail.contains("package.json") == true)
        #expect(item("new")?.safety == .caution)
        #expect(item("new")?.detail.contains("최근 14일") == true)
        #expect(item("nolock")?.safety == .caution)
        #expect(item("nolock")?.detail.contains("lock") == true)
    }

    @Test("산출물 폴더만 최근에 바뀐 프로젝트는 최근 활동으로 치지 않는다")
    func artifactChangesAreNotActivity() throws {
        let (root, cleanup) = try makeRoot()
        defer { cleanup() }
        let project = try dir(root, "p")
        try file(root, "p/Cargo.toml")
        try age(project, days: 40)
        try file(root, "p/target/new", bytes: 10)   // 방금 빌드

        let cutoff = Date().addingTimeInterval(-14 * 86_400)
        let last = try #require(ProjectArtifactScanner.lastActivity(of: project, since: cutoff))
        #expect(last < Date().addingTimeInterval(-39 * 86_400))
    }

    // MARK: - 관문

    @Test("관문은 등록한 루트 하위의 짝 맞는 산출물만 연다")
    func gateAllowsOnlyPairedInsideRoots() throws {
        let (root, cleanup) = try makeRoot()
        defer { cleanup() }
        let other = try makeRoot()
        defer { other.cleanup() }
        try file(root, "a/package.json")
        let paired = try dir(root, "a/node_modules")
        let unpaired = try dir(root, "b/node_modules")
        try file(other.root, "a/package.json")
        let outsideRoot = try dir(other.root, "a/node_modules")
        try fm.createSymbolicLink(at: root.appending(path: "a/link"),
                                  withDestinationURL: paired)

        let roots = [components(root)]
        #expect(ProtectedPaths.projectArtifactAllowed(components(paired), roots: roots))
        #expect(!ProtectedPaths.projectArtifactAllowed(components(unpaired), roots: roots))
        #expect(!ProtectedPaths.projectArtifactAllowed(components(outsideRoot), roots: roots))
        #expect(!ProtectedPaths.projectArtifactAllowed(components(root), roots: roots))
        // 프로젝트 폴더 자체나 그 안의 소스는 산출물이 아니다
        #expect(!ProtectedPaths.projectArtifactAllowed(components(root.appending(path: "a")), roots: roots))
        #expect(!ProtectedPaths.projectArtifactAllowed(components(root.appending(path: "a/package.json")), roots: roots))
    }

    @Test("프로젝트 범위는 정리 루트를 열지 않고, 정리 범위는 프로젝트 산출물을 열지 않는다")
    func scopesDoNotMix() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let cache = home.appending(path: "Library/Caches/org.swift.swiftpm")
        guard case .outsideAllowedRoots = ProtectedPaths.veto(for: cache, scope: .projectArtifacts) else {
            Issue.record("프로젝트 범위가 ~/Library/Caches를 열었다"); return
        }
        let artifact = home.appending(path: "Code/sweep-없는-프로젝트/node_modules")
        guard case .outsideAllowedRoots = ProtectedPaths.veto(for: artifact, scope: .cleanup) else {
            Issue.record("정리 범위가 프로젝트 산출물을 열었다"); return
        }
        // 등록한 루트가 없으면 프로젝트 범위도 닫혀 있다
        #expect(ProtectedPaths.veto(for: artifact, scope: .projectArtifacts) != nil)
    }

    // MARK: - 폴더 목록

    @Test("홈·/·Library·시스템 폴더는 거절하고 코드 폴더는 받는다")
    func validateFolders() {
        let home = URL(filePath: "/Users/sweep-tester")
        #expect(ProjectFolders.validate(home, home: home, existing: []) == .tooWide(home))
        #expect(ProjectFolders.validate(URL(filePath: "/"), home: home, existing: []) == .tooWide(URL(filePath: "/")))
        guard case .insideLibrary = ProjectFolders.validate(home.appending(path: "Library/Caches"),
                                                            home: home, existing: []) else {
            Issue.record("Library 안을 받았다"); return
        }
        guard case .systemFolder = ProjectFolders.validate(URL(filePath: "/System"), home: home, existing: []) else {
            Issue.record("/System을 받았다"); return
        }
        let code = home.appending(path: "Code")
        #expect(ProjectFolders.validate(code, home: home, existing: []) == nil)
        guard case .alreadyCovered = ProjectFolders.validate(code.appending(path: "app"),
                                                             home: home, existing: [code]) else {
            Issue.record("등록한 폴더 안을 또 받았다"); return
        }
    }

    @Test("목록은 저장·제거되고 샌드박스에서는 허락받은 곳만 루트가 된다")
    func registryAndRoots() throws {
        let suite = "sweep-projects-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let registry = ProjectFolders.Registry(defaults: defaults)
        let (root, cleanup) = try makeRoot()
        defer { cleanup() }

        try registry.add(root)
        #expect(registry.custom.map(\.path) == [root.path])
        #expect(throws: UserFolders.Rejection.self) { try registry.add(root.appending(path: "a")) }

        #expect(ProjectFolders.roots(custom: registry.custom, sandboxed: false, granted: []).count == 1)
        #expect(ProjectFolders.roots(custom: registry.custom, sandboxed: true, granted: []).isEmpty)
        #expect(ProjectFolders.roots(custom: registry.custom, sandboxed: true, granted: [root]).count == 1)

        registry.remove(root)
        #expect(registry.custom.isEmpty)
    }

    @Test("프로젝트 폴더 북마크 키는 큰 파일 폴더 키와 섞이지 않는다")
    func bookmarkKeysAreSeparate() {
        let folder = URL(filePath: "/Users/sweep-tester/Code")
        #expect(ProjectFolders.grantable(for: folder).key != UserFolders.grantable(for: folder).key)
    }

    @Test("등록한 폴더가 없거나 샌드박스에서 허락이 없으면 스캐너가 없다")
    func featureNeedsRoots() {
        #expect(Feature.projects.scanners(sandboxed: true, granted: []).isEmpty)
        #expect(!Feature.summaryCards.contains(.projects) || Feature.projects.isScannable)
    }

    // MARK: - 큰 파일 탐색

    @Test("큰 파일 탐색은 짝이 맞는 산출물 안으로 내려가지 않는다")
    func walkerSkipsPairedArtifacts() throws {
        let (root, cleanup) = try makeRoot()
        defer { cleanup() }
        try file(root, "rust/Cargo.toml")
        try file(root, "rust/target/big.bin", bytes: 4_096)
        try file(root, "notes/target/big.bin", bytes: 4_096)   // 짝 없는 target은 내 파일이다

        let found = UserFileWalker.files(under: root, minimumSize: 1_024, isDataless: { _ in false },
                                         inProjectFolder: { _ in true })
        let paths = Set(found.map { $0.url.pathComponents.suffix(3).joined(separator: "/") })
        #expect(paths == ["notes/target/big.bin"])
    }

    @Test("등록한 프로젝트 폴더 밖의 산출물 안 큰 파일은 큰 파일 탐색이 계속 찾는다")
    func walkerKeepsArtifactsOutsideProjectFolders() throws {
        let (root, cleanup) = try makeRoot()
        defer { cleanup() }
        try file(root, "rust/Cargo.toml")
        try file(root, "rust/target/big.bin", bytes: 4_096)

        // 개발 프로젝트 탭이 보여주지 않는 곳이므로 어디서도 안 보이게 되면 안 된다
        let found = UserFileWalker.files(under: root, minimumSize: 1_024, isDataless: { _ in false },
                                         inProjectFolder: { _ in false })
        let paths = Set(found.map { $0.url.pathComponents.suffix(3).joined(separator: "/") })
        #expect(paths == ["rust/target/big.bin"])
    }

    // MARK: - 최근 활동

    @Test("하위 파일만 고친 프로젝트도 최근에 고친 것으로 본다")
    func nestedEditIsActivity() throws {
        let (root, cleanup) = try makeRoot()
        defer { cleanup() }
        let project = try dir(root, "p")
        try file(root, "p/package.json")
        try file(root, "p/src/a/b.ts")
        let old = Date().addingTimeInterval(-60 * 86_400)
        // 프로젝트 바로 아래 항목과 폴더는 오래됐고, 깊은 파일 하나만 방금 고쳤다
        for path in ["p/package.json", "p/src", "p/src/a"] {
            try fm.setAttributes([.modificationDate: old], ofItemAtPath: root.appending(path: path).path)
        }
        let cutoff = Date().addingTimeInterval(-14 * 86_400)

        let last = try #require(ProjectArtifactScanner.lastActivity(of: project, since: cutoff))
        #expect(last > cutoff)
    }

    @Test(".git/index만 최근이어도 최근에 고친 것으로 본다")
    func gitIndexIsActivity() throws {
        let (root, cleanup) = try makeRoot()
        defer { cleanup() }
        let project = try dir(root, "p")
        try file(root, "p/package.json")
        try file(root, "p/.git/index")
        let old = Date().addingTimeInterval(-60 * 86_400)
        for path in ["p", "p/package.json", "p/.git"] {
            try fm.setAttributes([.modificationDate: old], ofItemAtPath: root.appending(path: path).path)
        }
        let cutoff = Date().addingTimeInterval(-14 * 86_400)

        let last = try #require(ProjectArtifactScanner.lastActivity(of: project, since: cutoff))
        #expect(last > cutoff)
    }
}
