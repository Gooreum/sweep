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
