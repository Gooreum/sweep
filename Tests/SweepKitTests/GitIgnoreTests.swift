import Testing
import Foundation
@testable import SweepKit

/// `.gitignore`에 폴더가 적혀 있는지 보는 판정.
@Suite("GitIgnore")
struct GitIgnoreTests {

    private func hit(_ name: String, _ lines: [String], here: Bool = true) -> Bool {
        GitIgnore.matches(name: name, lines: lines, anchoredHere: here)
    }

    @Test("이름만 적힌 줄과 끝에 슬래시가 붙은 줄은 어디서나 맞는다")
    func plainNames() {
        #expect(hit("dist", ["dist"]))
        #expect(hit("dist", ["dist/"]))
        #expect(hit("dist", ["**/dist"]))
        #expect(hit("dist", ["**/dist/"]))
        #expect(hit("dist", ["dist"], here: false))
    }

    @Test("앞에 슬래시가 붙은 줄은 그 .gitignore가 있는 폴더 바로 아래에서만 맞는다")
    func anchored() {
        #expect(hit("dist", ["/dist"], here: true))
        #expect(hit("dist", ["/dist/"], here: true))
        #expect(!hit("dist", ["/dist"], here: false))
    }

    @Test("적혀 있지 않거나 다른 이름이면 맞지 않는다")
    func notListed() {
        #expect(!hit("dist", []))
        #expect(!hit("dist", ["build", "node_modules"]))
        #expect(!hit("dist", ["distribution"]))
        #expect(!hit("dist", ["mydist"]))
    }

    @Test("주석·빈 줄은 건너뛰고, 줄 앞뒤 공백은 무시한다")
    func commentsAndBlanks() {
        #expect(!hit("dist", ["# dist", "", "   "]))
        #expect(hit("dist", ["# 결과물", "", "  dist  "]))
    }

    @Test("부정 줄이 뒤에 오면 마지막 줄이 이긴다")
    func negation() {
        #expect(!hit("dist", ["dist", "!dist"]))
        #expect(hit("dist", ["!dist", "dist"]))
    }

    @Test("와일드카드와 하위 경로는 해석하지 않고 적혀 있지 않다고 본다")
    func unsupportedPatterns() {
        #expect(!hit("dist", ["dist*"]))
        #expect(!hit("dist", ["d*st"]))
        #expect(!hit("dist", ["dist/foo"]))
        #expect(!hit("dist", ["packages/*/dist"]))
    }

    // MARK: - 파일을 읽는 부분

    private func makeRoot() throws -> (URL, () -> Void) {
        let root = URL(filePath: NSTemporaryDirectory())
            .appending(path: "sweep-gitignore-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let real = root.resolvingSymlinksInPath()
        return (real, { try? FileManager.default.removeItem(at: real) })
    }

    private func write(_ root: URL, _ relative: String, _ text: String) throws {
        let url = root.appending(path: relative)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    @Test("프로젝트의 .gitignore에 적힌 폴더만 맞는다")
    func readsProjectFile() throws {
        let (root, cleanup) = try makeRoot()
        defer { cleanup() }
        try write(root, "p/.gitignore", "node_modules\n/dist\n")
        let project = root.appending(path: "p")

        #expect(GitIgnore.lists("dist", from: project))
        #expect(!GitIgnore.lists("build", from: project))
    }

    @Test("하위 패키지는 저장소 루트의 .gitignore를 따르되, 루트 앵커(/dist)는 하위에서 맞지 않는다")
    func walksUpToRepositoryRoot() throws {
        let (root, cleanup) = try makeRoot()
        defer { cleanup() }
        try write(root, "repo/.gitignore", "dist\n/build\n")
        try FileManager.default.createDirectory(at: root.appending(path: "repo/.git"),
                                                withIntermediateDirectories: true)
        try write(root, "repo/packages/a/package.json", "{}")
        let package = root.appending(path: "repo/packages/a")

        #expect(GitIgnore.lists("dist", from: package))
        #expect(!GitIgnore.lists("build", from: package), "/build는 루트 바로 아래만 가리킨다")
    }

    @Test("저장소 루트(.git이 있는 폴더) 위의 .gitignore는 보지 않는다")
    func stopsAtRepositoryRoot() throws {
        let (root, cleanup) = try makeRoot()
        defer { cleanup() }
        try write(root, ".gitignore", "dist\n")                        // 저장소 밖
        try FileManager.default.createDirectory(at: root.appending(path: "repo/.git"),
                                                withIntermediateDirectories: true)
        let project = root.appending(path: "repo")

        #expect(!GitIgnore.lists("dist", from: project))
    }

    @Test("너무 큰 .gitignore는 읽지 않고 적혀 있지 않다고 본다")
    func ignoresHugeFile() throws {
        let (root, cleanup) = try makeRoot()
        defer { cleanup() }
        let huge = String(repeating: "x\n", count: GitIgnore.maxBytes) + "dist\n"
        try write(root, "p/.gitignore", huge)

        #expect(!GitIgnore.lists("dist", from: root.appending(path: "p")))
    }
}
