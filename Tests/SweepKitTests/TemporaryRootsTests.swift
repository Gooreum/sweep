import Testing
import Foundation
@testable import SweepKit

/// `/private/var/folders` 아래 root 소유 버킷이 삭제 후보로 새어 나오던 버그의 회귀 방지.
@Suite("임시 컨테이너 루트")
struct TemporaryRootsTests {

    private var fm: FileManager { .default }

    /// `<컨테이너>` — `C`/`T`의 부모.
    private var container: URL {
        URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .resolvingSymlinksInPath().standardizedFileURL.deletingLastPathComponent()
    }

    private func veto(_ url: URL) -> RemovalVeto? {
        do { try ProtectedPaths.validate(url); return nil }
        catch let v as RemovalVeto { return v }
        catch { Issue.record("예상 밖 오류: \(error)"); return nil }
    }

    // TC-1
    @Test("userTemporaryRoots가 컨테이너의 C와 T를 돌려준다")
    func derivesContainerCandT() {
        let roots = ProtectedPaths.userTemporaryRoots

        #expect(roots.count == 2)
        #expect(roots.map(\.lastPathComponent) == ["C", "T"])
        for root in roots {
            #expect(root.deletingLastPathComponent().standardizedFileURL == container)
            #expect(fm.fileExists(atPath: root.path), "실재하지 않는 루트: \(root.path)")
        }
    }

    // TC-2
    @Test("allowedRoots에 /private/var/folders가 남아 있지 않다")
    func varFoldersIsNoLongerARoot() {
        let paths = ProtectedPaths.allowedRoots.map {
            $0.resolvingSymlinksInPath().standardizedFileURL.path
        }
        #expect(!paths.contains("/private/var/folders"))
        #expect(!paths.contains("/var/folders"))
    }

    // TC-3 — 이번 버그의 직접 재현
    @Test("root 소유 버킷 /private/var/folders/mg는 거부된다")
    func rejectsRootOwnedBucket() throws {
        // 버킷은 컨테이너의 부모다. (<버킷>/<해시> → 부모 <버킷>)
        // Foundation은 실재하는 /private/var/folders를 /var/folders로 접으므로 그 형태로 비교한다.
        let bucket = container.deletingLastPathComponent()
        try #require(ProtectedPaths.canonical(bucket.deletingLastPathComponent()).path
            == ProtectedPaths.canonical(URL(filePath: "/private/var/folders")).path)

        guard case .outsideAllowedRoots = veto(bucket) else {
            Issue.record("버킷이 거부되지 않았다: \(bucket.path) → \(String(describing: veto(bucket)))")
            return
        }
        #expect(!ProtectedPaths.isRemovable(bucket))
    }

    // TC-4
    @Test("사용자 컨테이너 자체는 사용자 소유여도 거부된다")
    func rejectsUserContainerItself() {
        // 컨테이너는 uid가 나와 같다. 그래서 소유권 검사만으로는 막을 수 없고
        // 루트를 C/T로 좁힌 것이 유일한 방어다.
        guard case .outsideAllowedRoots = veto(container) else {
            Issue.record("컨테이너가 거부되지 않았다: \(container.path)")
            return
        }
    }

    // TC-5
    @Test("C와 T 자체는 allowedRootItself로 거부된다")
    func rejectsCandTThemselves() {
        for root in ProtectedPaths.userTemporaryRoots {
            guard case .allowedRootItself = veto(root) else {
                Issue.record("\(root.path): allowedRootItself가 아니라 \(String(describing: veto(root)))")
                return
            }
        }
    }

    // TC-6
    @Test("T 하위 개별 항목은 통과한다")
    func allowsItemsInsideT() throws {
        let temp = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
        let probe = temp.appending(path: "sweep-root-probe-\(UUID().uuidString)")
        try fm.createDirectory(at: probe, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: probe) }

        try ProtectedPaths.validate(probe)      // 던지지 않아야 한다
        #expect(ProtectedPaths.isRemovable(probe))
    }

    // TC-7
    @Test("샌드박스 하위 중첩 항목도 통과한다")
    func allowsNestedSandboxItems() throws {
        let temp = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
        let nested = temp.appending(path: "sweep-root-probe-\(UUID().uuidString)/inner/leaf")
        try fm.createDirectory(at: nested, withIntermediateDirectories: true)
        defer {
            try? fm.removeItem(at: temp.appending(path: nested.pathComponents[temp.pathComponents.count]))
        }

        #expect(ProtectedPaths.isRemovable(nested))
    }

    // TC-8
    @Test("기존 허용 루트 4종은 자체는 거부하고 하위는 통과한다")
    func existingRootsStillBehave() {
        let home = fm.homeDirectoryForCurrentUser
        let cases: [(root: URL, child: URL)] = [
            (home.appending(path: "Library/Developer"),
             home.appending(path: "Library/Developer/Xcode/DerivedData/App-x")),
            (home.appending(path: "Library/Caches"),
             home.appending(path: "Library/Caches/org.swift.swiftpm")),
            (home.appending(path: "Downloads"),
             home.appending(path: "Downloads/무언가.zip")),
            (URL(filePath: "/private/tmp"),
             URL(filePath: "/private/tmp/sweep-x")),
        ]

        for (root, child) in cases {
            guard case .allowedRootItself = veto(root) else {
                Issue.record("\(root.path): allowedRootItself가 아니라 \(String(describing: veto(root)))")
                return
            }
            #expect(veto(child) == nil, "\(child.path)가 거부됐다: \(String(describing: veto(child)))")
        }
    }
}
