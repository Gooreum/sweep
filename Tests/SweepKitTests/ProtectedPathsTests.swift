import Testing
import Foundation
@testable import SweepKit

@Suite("ProtectedPaths")
struct ProtectedPathsTests {

    private var home: URL { FileManager.default.homeDirectoryForCurrentUser }

    // TC-1
    @Test("허용 루트 하위 경로는 통과한다")
    func allowsPathInsideAllowedRoot() throws {
        let target = home.appending(path: "Library/Caches/org.swift.swiftpm")
        try ProtectedPaths.validate(target)   // 던지지 않아야 한다
        #expect(ProtectedPaths.isRemovable(target))
    }

    @Test("깊이 중첩된 허용 경로도 통과한다")
    func allowsDeeplyNestedPath() throws {
        let target = home.appending(path: "Library/Developer/Xcode/DerivedData/App-abc/Build")
        try ProtectedPaths.validate(target)
    }

    // TC-2
    @Test("허용 루트 밖 경로는 outsideAllowedRoots로 거부된다")
    func rejectsPathOutsideAllowedRoots() {
        let target = home.appending(path: "Documents/중요파일.txt")

        #expect(throws: RemovalVeto.self) {
            try ProtectedPaths.validate(target)
        }
        #expect(!ProtectedPaths.isRemovable(target))

        do {
            try ProtectedPaths.validate(target)
            Issue.record("거부되어야 하는데 통과했다")
        } catch let veto as RemovalVeto {
            guard case .outsideAllowedRoots = veto else {
                Issue.record("outsideAllowedRoots가 아니라 \(veto)")
                return
            }
        } catch {
            Issue.record("예상 밖 오류: \(error)")
        }
    }

    // TC-3
    @Test("루트 디렉토리는 rootOrHome으로 거부된다")
    func rejectsRootDirectory() {
        do {
            try ProtectedPaths.validate(URL(filePath: "/"))
            Issue.record("루트가 통과했다")
        } catch let veto as RemovalVeto {
            guard case .rootOrHome = veto else {
                Issue.record("rootOrHome이 아니라 \(veto)")
                return
            }
        } catch {
            Issue.record("예상 밖 오류: \(error)")
        }
    }

    // TC-4
    @Test("홈 디렉토리 자체는 rootOrHome으로 거부된다")
    func rejectsHomeDirectory() {
        do {
            try ProtectedPaths.validate(home)
            Issue.record("홈이 통과했다")
        } catch let veto as RemovalVeto {
            guard case .rootOrHome = veto else {
                Issue.record("rootOrHome이 아니라 \(veto)")
                return
            }
        } catch {
            Issue.record("예상 밖 오류: \(error)")
        }
    }

    // TC-5
    @Test("denyList 경로는 허용 루트 안이어도 protectedPath로 거부된다")
    func rejectsDenyListedPath() {
        let profiles = home.appending(path: "Library/Developer/Xcode/UserData/Provisioning Profiles")

        // 허용 루트(~/Library/Developer) 하위인 것을 먼저 확인 — 즉 4번이 아니라 3번에서 걸려야 한다
        #expect(profiles.isDescendant(of: home.appending(path: "Library/Developer")))

        do {
            try ProtectedPaths.validate(profiles)
            Issue.record("보호 경로가 통과했다")
        } catch let veto as RemovalVeto {
            guard case .protectedPath = veto else {
                Issue.record("protectedPath가 아니라 \(veto)")
                return
            }
        } catch {
            Issue.record("예상 밖 오류: \(error)")
        }
    }

    @Test("denyList 하위 파일도 함께 보호된다")
    func rejectsFileInsideDenyListedDirectory() {
        let profile = home.appending(
            path: "Library/Developer/Xcode/UserData/Provisioning Profiles/abc.mobileprovision")
        #expect(!ProtectedPaths.isRemovable(profile))
    }

    // TC-6
    @Test("허용 루트 안의 심볼릭 링크가 바깥을 가리키면 거부된다")
    func rejectsSymlinkEscapingAllowedRoot() throws {
        let fm = FileManager.default

        // 링크가 가리킬 바깥 대상 (허용 루트 밖)
        // NSTemporaryDirectory()는 /private/var/folders/... 로 풀리는데 이것 자체가 허용 루트라
        // 여기 두면 "바깥"이 되지 않는다. Application Support는 어느 허용 루트에도 속하지 않는다.
        let outsideDir = home.appending(path: "Library/Application Support")
            .appending(path: "sweep-escape-\(UUID().uuidString)")
        try fm.createDirectory(at: outsideDir, withIntermediateDirectories: true)
        let secret = outsideDir.appending(path: "secret.txt")
        try "건드리면 안 되는 파일".write(to: secret, atomically: true, encoding: .utf8)

        // 허용 루트(~/Library/Caches) 안에 링크를 만든다
        let linkDir = home.appending(path: "Library/Caches")
        let link = linkDir.appending(path: "sweep-test-link-\(UUID().uuidString)")
        try fm.createSymbolicLink(at: link, withDestinationURL: secret)

        defer {
            try? fm.removeItem(at: link)
            try? fm.removeItem(at: outsideDir)
        }

        // 링크 경로 자체는 허용 루트 안이지만, 실경로가 바깥이므로 거부되어야 한다
        #expect(throws: RemovalVeto.self) {
            try ProtectedPaths.validate(link)
        }
        // 그리고 실제 파일은 그대로 남아 있어야 한다
        #expect(fm.fileExists(atPath: secret.path))
    }

    // TC-7
    @Test("허용 루트 자체는 allowedRootItself로 거부된다")
    func rejectsAllowedRootItself() {
        for root in ProtectedPaths.allowedRoots {
            do {
                try ProtectedPaths.validate(root)
                Issue.record("허용 루트 자체가 통과했다: \(root.path)")
            } catch let veto as RemovalVeto {
                guard case .allowedRootItself = veto else {
                    Issue.record("\(root.path): allowedRootItself가 아니라 \(veto)")
                    return
                }
            } catch {
                Issue.record("예상 밖 오류: \(error)")
            }
        }
    }

    // TC-8
    @Test("상위 참조(..)가 섞인 경로는 정규화 후 거부된다")
    func rejectsPathWithParentTraversal() {
        let sneaky = home.appending(path: "Library/Caches/../Documents/중요파일.txt")
        #expect(!ProtectedPaths.isRemovable(sneaky))
    }

    @Test("경로 구성요소 단위 비교로 접두사 오판을 하지 않는다")
    func doesNotConfusePrefixSiblings() {
        // ~/Downloads 는 허용, ~/Downloads-backup 은 허용되면 안 된다
        let sibling = home.appending(path: "Downloads-backup/파일.zip")
        #expect(!ProtectedPaths.isRemovable(sibling))
    }

    // MARK: - 사유가 붙은 판정 (디스크 맵이 행마다 물어본다)

    // TC-2
    @Test("홈 디렉토리는 rootOrHome 사유로 막힌다")
    func vetoNamesHomeReason() {
        guard case .rootOrHome = ProtectedPaths.veto(for: home) else {
            Issue.record("홈: rootOrHome이 아니라 \(String(describing: ProtectedPaths.veto(for: home)))")
            return
        }
    }

    // TC-3
    @Test("허용 루트 밖은 outsideAllowedRoots 사유로 막힌다")
    func vetoNamesOutsideReason() {
        let outside = home.appending(path: "Documents/중요파일.txt")
        guard case .outsideAllowedRoots = ProtectedPaths.veto(for: outside) else {
            Issue.record("Documents: outsideAllowedRoots가 아니다")
            return
        }
    }

    // TC-4
    @Test("허용 루트 안의 파일은 사유가 없다")
    func vetoIsNilInsideAllowedRoot() {
        let inside = home.appending(path: "Library/Caches/sweep-veto-\(UUID().uuidString)")
        #expect(ProtectedPaths.veto(for: inside) == nil)
    }

    // TC-5
    @Test("isRemovable과 veto 판정이 모든 경우에 일치한다")
    func twoEntriesNeverDisagree() {
        // 화면이 "정리 가능"이라 써 놓고 눌렀더니 막히면 최악이다.
        // 판정 로직이 두 벌이면 언젠가 갈라진다.
        var probes: [URL] = [
            URL(filePath: "/"),
            home,
            home.appending(path: "Documents/중요파일.txt"),
            home.appending(path: "Library/Developer/Xcode/UserData/Provisioning Profiles"),
            URL(filePath: "/private/tmp/sweep-\(UUID().uuidString).bin"),
        ]
        probes += ProtectedPaths.allowedRoots
        probes += ProtectedPaths.allowedRoots.map { $0.appending(path: "child.bin") }

        for url in probes {
            #expect(ProtectedPaths.isRemovable(url) == (ProtectedPaths.veto(for: url) == nil),
                    "판정이 갈라졌다: \(url.path)")
        }
    }
}