import Foundation
import Testing
@testable import SweepKit

/// 앱 번들을 여는 규칙. **위치와 모양 둘 다** 맞아야 열린다.
///
/// 이 스위트는 판정 함수만 본다 — 실제 앱을 지우지 않는다.
@Suite("응용 프로그램 관문")
struct ApplicationBundleTests {

    /// 앱 폴더 두 곳을 성분 배열로. 홈은 테스트마다 고정한다.
    private let home = URL(filePath: "/Users/tester")

    private var folders: [[String]] {
        [URL(filePath: "/Applications"), home.appending(path: "Applications")]
            .map(\.standardizedFileURL.pathComponents)
    }

    private func components(_ path: String) -> [String] {
        URL(filePath: path).standardizedFileURL.pathComponents
    }

    // TC-1
    @Test("/Applications 바로 아래 .app은 후보다")
    func topLevelBundle() {
        #expect(ProtectedPaths.isApplicationBundle(
            components("/Applications/Figma.app"), folders: folders))
    }

    // TC-2
    @Test("번들 내부는 열리지 않는다")
    func insideBundle() {
        #expect(!ProtectedPaths.isApplicationBundle(
            components("/Applications/Figma.app/Contents"), folders: folders))
        #expect(!ProtectedPaths.isApplicationBundle(
            components("/Applications/Figma.app/Contents/MacOS/Figma"), folders: folders))
    }

    // TC-3
    @Test(".app이 아닌 것은 후보가 아니다")
    func notABundle() {
        #expect(!ProtectedPaths.isApplicationBundle(
            components("/Applications/readme.txt"), folders: folders))
        #expect(!ProtectedPaths.isApplicationBundle(
            components("/Applications/Utilities"), folders: folders))
    }

    // TC-4
    @Test("앱 폴더 밖의 .app은 후보가 아니다")
    func outsideApplicationFolders() {
        #expect(!ProtectedPaths.isApplicationBundle(
            components("/Users/tester/Downloads/Fake.app"), folders: folders))
        #expect(!ProtectedPaths.isApplicationBundle(
            components("/System/Applications/Mail.app"), folders: folders))
    }

    // TC-5
    @Test("~/Applications 바로 아래도 후보다")
    func homeApplications() {
        #expect(ProtectedPaths.isApplicationBundle(
            components("/Users/tester/Applications/YT Music.app"), folders: folders))
        // 한 단 아래는 열지 않는다 — 깊이 1로 못박았다
        #expect(!ProtectedPaths.isApplicationBundle(
            components("/Users/tester/Applications/Chrome Apps.localized/Gmail.app"),
            folders: folders))
    }

    // TC-6
    @Test("앱 폴더 자신은 후보가 아니다")
    func folderItself() {
        #expect(!ProtectedPaths.isApplicationBundle(
            components("/Applications"), folders: folders))
        #expect(!ProtectedPaths.isApplicationBundle(
            components("/Users/tester/Applications"), folders: folders))
    }

    // TC-7
    @Test("샌드박스 밖에서는 늘 열린다")
    func outsideSandbox() {
        #expect(ProtectedPaths.applicationsRemovable(sandboxed: false, granted: []))
    }

    // TC-8
    @Test("샌드박스에서 허락이 없으면 닫힌다")
    func sandboxedWithoutGrant() {
        #expect(!ProtectedPaths.applicationsRemovable(sandboxed: true, granted: []))
    }

    // TC-9
    @Test("샌드박스에서 /Applications를 허락하면 열린다")
    func sandboxedWithGrant() {
        #expect(ProtectedPaths.applicationsRemovable(
            sandboxed: true, granted: [URL(filePath: "/Applications")]))
    }

    // TC-10
    @Test("관계없는 폴더 허락으로는 열리지 않는다")
    func sandboxedWithUnrelatedGrant() {
        #expect(!ProtectedPaths.applicationsRemovable(
            sandboxed: true, granted: [Sandbox.userHome.appending(path: "Downloads")]))
    }
}

/// 관문 전체(`veto`)가 앱 번들을 통과시키는지.
///
/// **안전 규칙**: 모든 대상이 **실재하지 않는 경로**다. 관문이 깨져도 지울 것이 없다.
/// `validate`는 경로가 없으면 소유권·플래그 검사를 건너뛰므로 위치 판정만 정확히 겨눈다.
@Suite("응용 프로그램 관문 통과")
struct ApplicationVetoTests {

    /// 실재할 리 없는 이름. 실수로 만들어져도 알아볼 수 있게 접두사를 붙인다.
    private let ghost = "sweep-없는앱-9E3A1C.app"

    private var systemApps: URL { URL(filePath: "/Applications") }
    private var homeApps: URL { Sandbox.userHome.appending(path: "Applications") }

    // TC-1
    @Test("/Applications 아래 앱은 범위 밖이 아니다")
    func systemBundlePasses() {
        #expect(ProtectedPaths.veto(for: systemApps.appending(path: ghost)) == nil)
    }

    // TC-2
    @Test("번들 내부는 범위 밖이다")
    func insideBundleVetoed() {
        let inside = systemApps.appending(path: ghost).appending(path: "Contents")
        #expect(ProtectedPaths.veto(for: inside) != nil)
    }

    // TC-3
    @Test(".app이 아닌 것은 범위 밖이다")
    func nonBundleVetoed() {
        #expect(ProtectedPaths.veto(
            for: systemApps.appending(path: "sweep-없는파일-9E3A1C.txt")) != nil)
    }

    // TC-4
    @Test("~/Applications 아래 앱도 통과한다")
    func homeBundlePasses() {
        #expect(ProtectedPaths.veto(for: homeApps.appending(path: ghost)) == nil)
    }

    // TC-5
    @Test("앱 폴더 자체는 지울 수 없다")
    func folderItselfVetoed() {
        #expect(ProtectedPaths.veto(for: systemApps) != nil)
    }

    // TC-6
    @Test("다른 곳의 .app은 여전히 막힌다")
    func bundleElsewhereVetoed() {
        let elsewhere = Sandbox.userHome.appending(path: "Documents").appending(path: ghost)
        #expect(ProtectedPaths.veto(for: elsewhere) != nil)
    }

    // TC-7
    @Test("기존 루트 판정은 그대로다")
    func existingRootsUnchanged() {
        let cache = Sandbox.userHome
            .appending(path: "Library/Caches")
            .appending(path: "sweep-없는폴더-9E3A1C")
        #expect(ProtectedPaths.isRemovable(cache))
    }
}

/// 앱에만 적용되는 소유권 예외.
///
/// 기전(부모 폴더 쓰기 권한)은 **임시 폴더**로 검증한다 — 사용자의 실제
/// `~/Applications` 권한을 건드리지 않는다. 실기 확인은 읽기 전용 조회뿐이다.
@Suite("앱 소유권 예외")
struct ApplicationOwnershipTests {

    // TC-1 / TC-2
    @Test("부모 폴더에 쓸 수 있을 때만 참이다")
    func parentWritability() throws {
        let parent = URL(filePath: NSTemporaryDirectory())
            .appending(path: "sweep-owner-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: parent.path)
            try? FileManager.default.removeItem(at: parent)
        }
        let child = parent.appending(path: "Thing.app")

        #expect(ProtectedPaths.canWriteParent(of: child))

        // 읽기·실행만 남기면 이름 바꾸기가 막힌다 — 휴지통 이동이 실패하는 상태다.
        try FileManager.default.setAttributes([.posixPermissions: 0o555],
                                              ofItemAtPath: parent.path)
        #expect(!ProtectedPaths.canWriteParent(of: child))
    }

    // TC-3
    @Test("부모가 없으면 쓸 수 없다")
    func missingParent() {
        let orphan = URL(filePath: "/sweep-없는폴더-9E3A1C/Thing.app")
        #expect(!ProtectedPaths.canWriteParent(of: orphan))
    }

    // TC-4
    @Test("root 소유 앱은 소유권으로 막히지 않는다")
    func rootOwnedApplicationIsNotVetoedByOwnership() throws {
        let apps = URL(filePath: "/Applications")
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: apps, includingPropertiesForKeys: nil)) ?? []

        // root 소유이면서 삭제 금지 플래그가 없는 앱 하나. 없으면 확인할 것이 없다.
        let candidate = contents.first { url in
            guard url.lastPathComponent.hasSuffix(".app"),
                  let info = ProtectedPaths.fileInfo(of: url)
            else { return false }
            return info.uid != getuid() && info.flags & ProtectedPaths.undeletableFlags == 0
        }
        guard let candidate else { return }

        // 실행 중일 수도 있으므로 "통과"가 아니라 **소유권 사유가 아님**을 단정한다.
        #expect(ProtectedPaths.veto(for: candidate)
                != .notOwnedByCurrentUser(candidate.standardizedFileURL))
    }

    // TC-5
    @Test("앱이 아니면 소유권 규칙이 그대로다")
    func nonApplicationKeepsOwnershipRule() {
        let powerlog = URL(filePath: "/private/tmp/powerlog")
        guard let info = ProtectedPaths.fileInfo(of: powerlog), info.uid != getuid()
        else { return }

        #expect(ProtectedPaths.veto(for: powerlog)
                == .notOwnedByCurrentUser(ProtectedPaths.canonical(powerlog)))
    }
}

/// 실행 중인 앱은 지우지 않는다.
///
/// `trashItem`은 이름 바꾸기라 실행 중이어도 성공한다 — 앱은 휴지통에서 계속 돌다가
/// 다음 실행에 깨진다. 실행 목록을 갈아끼워 검증한다. 테스트가 앱을 띄울 수는 없고,
/// 띄운다면 그것을 지우는 TC가 되어 버린다.
@Suite("실행 중인 앱 보호", .serialized)
struct RunningApplicationTests {

    private let ghost = URL(filePath: "/Applications/sweep-없는앱-9E3A1C.app")

    /// 실행 목록을 잠시 바꾸고 원래대로 돌려 둔다.
    private func withRunning(_ urls: [URL], _ body: () -> Void) {
        let original = ProtectedPaths.runningApplicationURLs
        ProtectedPaths.runningApplicationURLs = { urls }
        defer { ProtectedPaths.runningApplicationURLs = original }
        body()
    }

    // TC-1
    @Test("실행 목록이 비면 막지 않는다")
    func notRunning() {
        withRunning([]) {
            #expect(ProtectedPaths.veto(for: ghost) == nil)
        }
    }

    // TC-2
    @Test("실행 중이면 거부한다")
    func running() {
        withRunning([ghost]) {
            #expect(ProtectedPaths.veto(for: ghost)
                    == .applicationRunning(ghost.standardizedFileURL))
        }
    }

    // TC-3
    @Test("다른 앱이 실행 중인 것은 상관없다")
    func otherAppRunning() {
        withRunning([URL(filePath: "/Applications/sweep-다른앱-9E3A1C.app")]) {
            #expect(ProtectedPaths.veto(for: ghost) == nil)
        }
    }

    // TC-4
    @Test("앱이 아닌 경로는 이 검사를 타지 않는다")
    func nonApplicationSkipsCheck() {
        let cache = Sandbox.userHome
            .appending(path: "Library/Caches")
            .appending(path: "sweep-없는폴더-9E3A1C")
        withRunning([cache]) {
            #expect(ProtectedPaths.veto(for: cache) == nil)
        }
    }

    // TC-5
    @Test("사유 문구가 무엇을 해야 하는지 말한다")
    func message() {
        let message = RemovalVeto.applicationRunning(ghost).message
        #expect(message.hasPrefix("실행 중인 앱입니다"))
        #expect(message.contains(ghost.path))
    }

    // TC-6
    @Test("기본 구현이 실제 실행 중인 앱을 집는다")
    func defaultImplementation() {
        // 테스트 프로세스 자신은 번들이 없을 수 있다. Finder·Dock 등 무엇이든 있으면 된다.
        #expect(!RunningApplications.urls.isEmpty)
    }
}

/// 샌드박스에서 앱을 지우려면 `/Applications`를 허락받아야 한다.
@Suite("앱 폴더 허락")
struct ApplicationGrantableTests {

    private var applications: FolderAccess.Grantable? {
        FolderAccess.grantables.first { $0.folder.path == "/Applications" }
    }

    // TC-1
    @Test("허락 목록에 응용 프로그램이 있다")
    func listed() throws {
        let grantable = try #require(applications)
        #expect(grantable.label == "응용 프로그램")
        #expect(!grantable.purpose.isEmpty)
    }

    // TC-2
    @Test("북마크 키가 서로 겹치지 않는다")
    func uniqueKeys() {
        let keys = FolderAccess.grantables.map(\.key)
        #expect(Set(keys).count == keys.count, "북마크가 서로 덮어쓴다")
    }

    // TC-3
    @Test("그 폴더를 허락하면 앱이 열린다")
    func grantOpensApplications() throws {
        let grantable = try #require(applications)
        #expect(ProtectedPaths.applicationsRemovable(
            sandboxed: true, granted: [grantable.folder]))
    }

    // TC-4
    @Test("기존 허락 대상이 그대로다")
    func existingGrantablesUnchanged() {
        let labels = FolderAccess.grantables.map(\.label)
        #expect(labels.prefix(3) == ["~/Library", "~/.npm", "~/.expo"])
    }
}

/// 이 기계의 실제 `/Applications`를 훑어 판정 분포가 의도대로인지 본다.
///
/// **읽기 전용이다.** `veto` 조회만 하고 아무것도 지우거나 바꾸지 않는다.
/// 가짜 경로 TC만으로는 "실제 앱들이 정말 열렸는가"를 알 수 없어서 둔다 —
/// 소유권 예외를 넣은 이유가 바로 실기에서 2/3이 막혔기 때문이다.
@Suite("실제 응용 프로그램 판정")
struct ApplicationSurveyTests {

    private var bundles: [URL] {
        let apps = URL(filePath: "/Applications")
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: apps, includingPropertiesForKeys: nil)) ?? []
        return contents.filter { $0.lastPathComponent.hasSuffix(".app") }
    }

    /// 심볼릭 링크는 빼고 본다.
    ///
    /// 실측: `/Applications/Safari.app`은 폴더가 아니라
    /// `/System/Volumes/Preboot/Cryptexes/App/...`를 가리키는 링크다. 관문은 실경로로
    /// 판정하므로 이런 앱은 `outsideAllowedRoots`로 막힌다 — **의도한 대로**지만
    /// 사유가 다르다. 링크를 섞으면 "일반 앱이 열렸는가"를 잴 수 없다.
    private func isSymbolicLink(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) ?? false
    }

    // TC-1
    @Test("앱은 통과하거나 시스템 보호·실행 중으로만 막힌다")
    func onlyExpectedVetoes() {
        for bundle in bundles where !isSymbolicLink(bundle) {
            switch ProtectedPaths.veto(for: bundle) {
            case nil, .systemProtected, .applicationRunning:
                continue
            case .some(let veto):
                Issue.record("앱이 뜻밖의 사유로 막혔다: \(veto.message)")
            }
        }
    }

    // TC-2
    @Test("시스템이 심어 둔 앱은 어떤 식으로든 막힌다")
    func systemAppsProtected() {
        // 삭제 금지 플래그가 걸렸거나, 시스템 볼륨을 가리키는 링크이거나.
        let systemOwned = bundles.filter { bundle in
            if let info = ProtectedPaths.fileInfo(of: bundle),
               info.flags & ProtectedPaths.undeletableFlags != 0 { return true }
            return isSymbolicLink(bundle)
        }
        // 이 기계에 그런 앱이 없을 수도 있다. 있으면 하나도 열려서는 안 된다.
        for bundle in systemOwned {
            #expect(ProtectedPaths.veto(for: bundle) != nil,
                    "시스템 앱이 열렸다: \(bundle.lastPathComponent)")
        }
    }

    // TC-3
    @Test("번들 내부는 잠겨 있다")
    func bundleInteriorLocked() {
        guard let bundle = bundles.first else { return }
        let inside = bundle.appending(path: "Contents")
        #expect(ProtectedPaths.veto(for: inside) != nil)
    }
}
