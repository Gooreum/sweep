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
        probes += [
            home.appending(path: ".npm/_cacache"),
            home.appending(path: ".turso/turso"),
            home.appending(path: ".nvm/versions"),
        ]

        for url in probes {
            #expect(ProtectedPaths.isRemovable(url) == (ProtectedPaths.veto(for: url) == nil),
                    "판정이 갈라졌다: \(url.path)")
        }
    }

    @Test("홈 직속 개발 캐시는 하위만 열린다")
    func homeToolCachesAreRemovableBelowRootOnly() {
        #expect(ProtectedPaths.isRemovable(home.appending(path: ".npm/_cacache")))
        #expect(ProtectedPaths.isRemovable(home.appending(path: ".npm/_npx")))
        #expect(ProtectedPaths.isRemovable(home.appending(path: ".expo/versions-cache")))

        // 루트 자체는 기존 allowedRootItself 규칙이 막는다.
        #expect(!ProtectedPaths.isRemovable(home.appending(path: ".npm")))
        #expect(!ProtectedPaths.isRemovable(home.appending(path: ".expo")))
    }

    @Test("앱 캐시 폴더는 이름이 맞을 때만 열린다")
    func appCacheFoldersOpenByNameOnly() {
        let appSupport = home.appending(path: "Library/Application Support")

        // 실측된 실제 경로들. depth 2·4·5가 섞여 있다.
        #expect(ProtectedPaths.isRemovable(appSupport.appending(path: "Slack/Cache")))
        #expect(ProtectedPaths.isRemovable(appSupport.appending(path: "Slack/Code Cache")))
        #expect(ProtectedPaths.isRemovable(
            appSupport.appending(path: "Notion/Partitions/notion/Cache")))
        #expect(ProtectedPaths.isRemovable(
            appSupport.appending(path: "Figma/DesktopProfile/v39/GPUCache")))
        #expect(ProtectedPaths.isRemovable(
            appSupport.appending(path: "Google/Chrome/Default/Service Worker/CacheStorage")))
    }

    @Test("앱 캐시 규칙이 사용자 데이터까지 열지는 않는다")
    func appCacheRuleKeepsUserDataClosed() {
        let appSupport = home.appending(path: "Library/Application Support")

        for path in [
            "",                                  // Application Support 자체
            "Slack",                             // 앱 폴더 자체
            "Notion/notion.db",                  // 로컬 DB
            "Slack/IndexedDB",                   // 웹앱 데이터
            "Google/Chrome/Default/Local Storage",
            "Google/Chrome/Default/Local Extension Settings",
            "FileProvider",                      // iCloud·Dropbox 상태
            "Slack/Cache/Cache_Data",            // 캐시 폴더 안쪽 — 캐시 자체만 연다
            // Service Worker는 통째로 열지 않는다. Database가 등록 정보다.
            "Google/Chrome/Default/Service Worker",
            "Google/Chrome/Default/Service Worker/Database",
        ] {
            let url = path.isEmpty ? appSupport : appSupport.appending(path: path)
            #expect(!ProtectedPaths.isRemovable(url), "열리면 안 되는 경로가 열렸다: \(path)")
        }
    }

    @Test("앱 캐시 이름이라도 Application Support 밖이면 열리지 않는다")
    func appCacheNamesOutsideAppSupportStayClosed() {
        // 이름만 맞다고 열면 관문이 이름 하나로 뚫린다.
        #expect(!ProtectedPaths.isRemovable(home.appending(path: "Documents/Cache")))
        #expect(!ProtectedPaths.isRemovable(home.appending(path: "Desktop/GPUCache")))
    }

    @Test("너무 깊은 앱 캐시는 열지 않는다")
    func deeplyNestedAppCacheStaysClosed() {
        // 실측상 가장 깊은 것이 5단계(Chrome의 Service Worker/CacheStorage)다.
        let deep = home.appending(
            path: "Library/Application Support/a/b/c/d/e/f/Cache")
        #expect(!ProtectedPaths.isRemovable(deep))
    }

    @Test("실행 파일이 든 도구 폴더는 열지 않는다")
    func toolFoldersWithBinariesStayClosed() {
        // ~/.turso는 sqld(39M)·turso(17M) 실행 파일 둘뿐이고,
        // ~/.nvm은 node 런타임 설치본이다. 지우면 명령어가 사라진다.
        for path in [".turso", ".turso/turso", ".nvm", ".nvm/versions"] {
            let url = home.appending(path: path)
            guard case .outsideAllowedRoots = ProtectedPaths.veto(for: url) else {
                Issue.record("\(path): outsideAllowedRoots로 거부되어야 한다")
                continue
            }
        }
    }

    // MARK: - 디스크 맵 범위 (내 소유면 어디든, 기본 폴더 자체·계정 데이터만 제외)

    private func diskMapVeto(_ relative: String) -> RemovalVeto? {
        ProtectedPaths.veto(for: home.appending(path: relative), scope: .diskMap)
    }

    // TC-1 · TC-2
    @Test("내 문서는 디스크 맵 범위에서는 열리고 정리 범위에서는 막힌다")
    func documentsOpenOnlyInDiskMapScope() {
        let target = home.appending(path: "Documents/영상.mov")

        #expect(ProtectedPaths.veto(for: target, scope: .diskMap) == nil)
        // 스캐너 쪽 관문은 그대로다 — 범위를 열었다고 2차 방어선이 넓어지면 안 된다.
        guard case .outsideAllowedRoots = ProtectedPaths.veto(for: target) else {
            Issue.record("정리 범위 판정이 바뀌었다")
            return
        }
    }

    // TC-3
    @Test("디스크 맵에서도 루트·홈·정리 루트 자체·denyList는 막힌다")
    func diskMapKeepsCommonVetoes() {
        guard case .rootOrHome = ProtectedPaths.veto(for: URL(filePath: "/"), scope: .diskMap) else {
            Issue.record("루트가 열렸다"); return
        }
        guard case .rootOrHome = ProtectedPaths.veto(for: home, scope: .diskMap) else {
            Issue.record("홈이 열렸다"); return
        }
        guard case .allowedRootItself = diskMapVeto("Library/Caches") else {
            Issue.record("정리 루트 자체가 열렸다"); return
        }
        guard case .protectedPath = diskMapVeto("Library/Developer/Xcode/UserData/Provisioning Profiles") else {
            Issue.record("denyList가 열렸다"); return
        }
    }

    // TC-4 · TC-5
    @Test("홈의 기본 폴더는 자체만 막히고 안의 항목은 열린다")
    func essentialFoldersBlockThemselvesOnly() {
        for folder in ["Documents", "Library", "Library/Application Support", "Library/Containers"] {
            guard case .essentialFolder = diskMapVeto(folder) else {
                Issue.record("\(folder) 자체가 열렸다: \(String(describing: diskMapVeto(folder)))")
                continue
            }
        }
        #expect(diskMapVeto("Documents/안/파일.txt") == nil)
        #expect(diskMapVeto("Library/Application Support/SomeApp") == nil)
    }

    // TC-6
    @Test("계정 데이터는 자체와 그 아래가 모두 막힌다")
    func userDataBlocksDescendants() {
        for path in ["Library/Keychains", "Library/Keychains/login.keychain-db",
                     "Library/Mobile Documents/com~apple~CloudDocs/메모.txt"] {
            guard case .essentialFolder = diskMapVeto(path) else {
                Issue.record("\(path)가 열렸다: \(String(describing: diskMapVeto(path)))")
                continue
            }
        }
    }

    // TC-7
    @Test("시스템 영역은 범위가 아니라 소유권·플래그가 막는다")
    func systemAreaIsVetoedByOwnershipNotScope() {
        let veto = ProtectedPaths.veto(for: URL(filePath: "/System/Library"), scope: .diskMap)
        #expect(veto != nil, "/System/Library가 열렸다")
        if case .outsideAllowedRoots = veto {
            Issue.record("디스크 맵 범위가 영역으로 막았다 — 소유권으로 막혀야 한다")
        }
    }

    // TC-8
    @Test("샌드박스 디스크 맵은 Downloads와 허락받은 폴더 안만 닿는다")
    func diskMapReachabilityFollowsGrants() {
        let documents = home.appending(path: "Documents/a.mov").standardizedFileURL.pathComponents
        let downloads = home.appending(path: "Downloads/a.dmg").standardizedFileURL.pathComponents
        let apps = URL(filePath: "/Applications/x.app").standardizedFileURL.pathComponents

        // 샌드박스 밖에서는 어디든 — 시스템은 소유권·플래그가 지킨다
        #expect(ProtectedPaths.diskMapReachable(apps, sandboxed: false, granted: []))

        #expect(ProtectedPaths.diskMapReachable(downloads, sandboxed: true, granted: []))
        #expect(!ProtectedPaths.diskMapReachable(documents, sandboxed: true, granted: []))

        #expect(ProtectedPaths.diskMapReachable(documents, sandboxed: true, granted: [home]))
        #expect(!ProtectedPaths.diskMapReachable(apps, sandboxed: true, granted: [home]))
    }

    // TC-9
    @Test("디스크 맵 범위에서도 isRemovable과 veto 판정이 일치한다")
    func diskMapEntriesNeverDisagree() {
        var probes: [URL] = [
            URL(filePath: "/"), home,
            home.appending(path: "Documents/중요파일.txt"),
            home.appending(path: "Library/Keychains/login.keychain-db"),
            home.appending(path: "Library/Application Support/SomeApp"),
            URL(filePath: "/System/Library"),
            URL(filePath: "/private/tmp/sweep-\(UUID().uuidString).bin"),
        ]
        probes += ProtectedPaths.allowedRoots
        probes += ProtectedPaths.allowedRoots.map { $0.appending(path: "child.bin") }

        for url in probes {
            #expect(ProtectedPaths.isRemovable(url, scope: .diskMap)
                    == (ProtectedPaths.veto(for: url, scope: .diskMap) == nil),
                    "판정이 갈라졌다: \(url.path)")
        }
    }
}
