import Testing
import Foundation
@testable import SweepKit

@Suite("PermissionNeed")
struct PermissionNeedTests {

    private let home = Sandbox.userHome

    private func needs(_ feature: Feature, sandboxed: Bool = true, granted: [URL] = [],
                       fullDiskAccess: Bool = false) -> [PermissionNeed] {
        feature.permissionNeeds(sandboxed: sandboxed, granted: granted, fullDiskAccess: fullDiskAccess)
    }

    // TC-1
    @Test("샌드박스에서 아무것도 허용하지 않으면 정리할 파일은 ~/Library를 달라고 한다")
    func junkNeedsLibrary() {
        #expect(needs(.junk) == [.folder(FolderAccess.library)])
        // ~/.npm만 허용해도 ~/Library 안내는 남는다 — 지금은 조용히 빈 결과가 나오던 경우다.
        #expect(needs(.junk, granted: [home.appending(path: ".npm")]) == [.folder(FolderAccess.library)])
    }

    // TC-2
    @Test("큰 파일·중복 파일·휴지통은 홈 폴더부터 달라고 한다")
    func homeFirst() {
        for feature in [Feature.largeFile, .duplicate, .trash] {
            #expect(needs(feature) == [.folder(FolderAccess.home)])
        }
        // 휴지통은 전체 디스크 접근이 있어도 폴더가 먼저다.
        #expect(needs(.trash, fullDiskAccess: true) == [.folder(FolderAccess.home)])
    }

    // TC-3
    @Test("홈을 허용하면 휴지통은 전체 디스크 접근만 남는다")
    func trashNeedsFullDiskAccessAfterHome() {
        #expect(needs(.trash, granted: [home]) == [.fullDiskAccess])
        #expect(needs(.trash, granted: [home], fullDiskAccess: true).isEmpty)
        #expect(needs(.largeFile, granted: [home]).isEmpty)
    }

    // TC-4
    @Test("이 Mac을 허용하면 홈과 ~/Library도 열린 것으로 친다")
    func wholeDiskCoversEverything() {
        let root = [URL(filePath: "/")]
        #expect(needs(.junk, granted: root).isEmpty)
        #expect(needs(.largeFile, granted: root).isEmpty)
        #expect(needs(.trash, granted: root) == [.fullDiskAccess])
    }

    // TC-5
    @Test("샌드박스 밖에서는 휴지통의 전체 디스크 접근만 본다")
    func outsideSandbox() {
        #expect(needs(.trash, sandboxed: false) == [.fullDiskAccess])
        #expect(needs(.trash, sandboxed: false, fullDiskAccess: true).isEmpty)
        for feature in [Feature.junk, .largeFile, .duplicate] {
            #expect(needs(feature, sandboxed: false).isEmpty)
        }
    }

    @Test("응용 프로그램은 샌드박스에서 응용 프로그램 폴더를 달라고 한다")
    func applicationsNeedFolder() {
        #expect(needs(.applications) == [.folder(FolderAccess.applications)])
        #expect(needs(.applications, granted: [URL(filePath: "/Applications")]).isEmpty)
        #expect(needs(.applications, granted: [URL(filePath: "/")]).isEmpty)
        #expect(needs(.applications, sandboxed: false).isEmpty)
    }

    @Test("자기 허용 입구가 있는 화면은 안내하지 않는다")
    func screensWithOwnEntry() {
        for feature in [Feature.smartScan, .projects, .diskMap, .cpu] {
            #expect(needs(feature).isEmpty)
        }
    }

    // TC-7
    @Test("휴지통 열기 실패 사유는 폴더, 전체 디스크 접근 순서다")
    func trashOpenNeed() {
        #expect(ItemActions.trashOpenNeed(sandboxed: true, granted: [], fullDiskAccess: true)
                == .folder(FolderAccess.home))
        #expect(ItemActions.trashOpenNeed(sandboxed: true, granted: [home], fullDiskAccess: false)
                == .fullDiskAccess)
        #expect(ItemActions.trashOpenNeed(sandboxed: true, granted: [home], fullDiskAccess: true) == nil)
    }
}
