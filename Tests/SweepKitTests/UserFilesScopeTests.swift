import Testing
import Foundation
@testable import SweepKit

/// 큰 파일·중복 파일만 사용자 폴더를 지울 수 있다. 정리 범위는 그대로 좁다.
@Suite("RemovalScope.userFiles")
struct UserFilesScopeTests {

    private var home: URL { FileManager.default.homeDirectoryForCurrentUser }

    private func veto(_ relative: String, _ scope: RemovalScope) -> RemovalVeto? {
        ProtectedPaths.veto(for: home.appending(path: relative), scope: scope)
    }

    @Test("사용자 폴더 안의 파일은 userFiles에서만 통과한다")
    func userFolderFilesOpenOnlyForUserFiles() {
        #expect(veto("Documents/sweep-없는-영상.mov", .userFiles) == nil)
        #expect(veto("Desktop/sweep-없는-영상.mov", .userFiles) == nil)
        guard case .outsideAllowedRoots = veto("Documents/sweep-없는-영상.mov", .cleanup) else {
            Issue.record("정리 범위가 Documents를 열었다"); return
        }
    }

    @Test("사용자 폴더 자체는 지울 수 없다")
    func userFolderItselfIsRoot() {
        guard case .allowedRootItself = veto("Documents", .userFiles) else {
            Issue.record("~/Documents 자체가 allowedRootItself가 아니다"); return
        }
    }

    @Test("userFiles도 Library 안의 계정 데이터는 열지 않는다")
    func userFilesDoesNotOpenLibrary() {
        guard case .outsideAllowedRoots = veto("Library/Safari/History.db", .userFiles) else {
            Issue.record("userFiles가 ~/Library/Safari를 열었다"); return
        }
        // 정리 루트는 userFiles에서도 그대로 열린다
        #expect(veto("Library/Caches/org.swift.swiftpm", .userFiles) == nil)
    }

    @Test("도구 캐시 하위만 열리고 인증 정보·실행 파일 층은 막힌다")
    func toolCacheRootsAreNarrow() {
        #expect(veto(".gradle/caches/modules-2", .cleanup) == nil)
        #expect(veto(".cargo/registry/cache", .cleanup) == nil)
        #expect(veto(".m2/repository/org", .cleanup) == nil)
        for relative in [".gradle/gradle.properties", ".m2/settings.xml", ".cargo/bin/cargo"] {
            guard case .outsideAllowedRoots = veto(relative, .cleanup) else {
                Issue.record("\(relative)가 열렸다"); continue
            }
        }
        guard case .allowedRootItself = veto(".gradle/caches", .cleanup) else {
            Issue.record("~/.gradle/caches 자체가 allowedRootItself가 아니다"); return
        }
    }

    @Test("휴지통·기기 백업·메일 첨부는 하위만 열린다")
    func newJunkRoots() {
        #expect(veto(".Trash/sweep-없는-파일", .cleanup) == nil)
        #expect(veto("Library/Application Support/MobileSync/Backup/00008030-ABC", .cleanup) == nil)
        #expect(veto("Library/Containers/com.apple.mail/Data/Library/Mail Downloads/X", .cleanup) == nil)
        guard case .allowedRootItself = veto(".Trash", .cleanup) else {
            Issue.record("~/.Trash 자체가 allowedRootItself가 아니다"); return
        }
        // 같은 컨테이너의 메일 데이터는 열지 않는다
        guard case .outsideAllowedRoots = veto("Library/Containers/com.apple.mail/Data/Library/Mail/V10", .cleanup) else {
            Issue.record("메일 데이터가 열렸다"); return
        }
    }

    @Test("iCloud Drive 휴지통은 하위만 열리고 나머지 iCloud 데이터는 막힌다")
    func iCloudTrashRoot() {
        #expect(veto("Library/Mobile Documents/.Trash/sweep-없는-파일", .cleanup) == nil)
        guard case .allowedRootItself = veto("Library/Mobile Documents/.Trash", .cleanup) else {
            Issue.record("iCloud 휴지통 자체가 allowedRootItself가 아니다"); return
        }
        guard case .outsideAllowedRoots = veto("Library/Mobile Documents/com~apple~CloudDocs/sweep-없는-파일", .cleanup) else {
            Issue.record("iCloud Drive 파일이 열렸다"); return
        }
    }

    @Test("외장 디스크 휴지통은 내 uid 폴더의 하위만 모양으로 연다")
    func volumeTrashShape() {
        let me = String(getuid())
        func shape(_ path: String) -> Bool {
            ProtectedPaths.isVolumeTrashItem(URL(filePath: path).pathComponents)
        }
        #expect(shape("/Volumes/Ext/.Trashes/\(me)/a.mov"))
        #expect(shape("/Volumes/Ext/.Trashes/\(me)/폴더/b"))
        #expect(!shape("/Volumes/Ext/.Trashes/\(me)"))      // 휴지통 자체
        #expect(!shape("/Volumes/Ext/.Trashes/99999/a.mov")) // 남의 휴지통
        #expect(!shape("/Volumes/Ext/a.mov"))                // 디스크의 그냥 파일
        #expect(!shape("/Users/x/.Trashes/\(me)/a/b"))

        // 관문도 같은 모양을 연다 — 디스크가 없어도 경로만으로 판정된다
        #expect(ProtectedPaths.veto(for: URL(filePath: "/Volumes/sweep-없는-디스크/.Trashes/\(me)/a.mov"),
                                    scope: .cleanup) == nil)
        guard case .outsideAllowedRoots = ProtectedPaths.veto(for: URL(filePath: "/Volumes/sweep-없는-디스크/a.mov"),
                                                              scope: .cleanup) else {
            Issue.record("외장 디스크의 그냥 파일이 열렸다"); return
        }
    }

    @Test("isInsideTrash는 세 휴지통 안에서만 참이다")
    func insideTrash() {
        #expect(ProtectedPaths.isInsideTrash(home.appending(path: ".Trash/a")))
        #expect(ProtectedPaths.isInsideTrash(home.appending(path: "Library/Mobile Documents/.Trash/a")))
        #expect(ProtectedPaths.isInsideTrash(URL(filePath: "/Volumes/Ext/.Trashes/\(getuid())/a")))
        #expect(!ProtectedPaths.isInsideTrash(home.appending(path: ".Trash")))
        #expect(!ProtectedPaths.isInsideTrash(home.appending(path: "Downloads/a")))
    }

    @Test("normalize는 휴지통 항목만 크기 0이어도 남긴다")
    func normalizeKeepsZeroSizeTrash() {
        let cloudOnly = CleanupItem(url: home.appending(path: "Library/Mobile Documents/.Trash/sweep-없는-index.html"),
                                    size: 0, category: .trash, safety: .caution)
        let empty = CleanupItem(url: home.appending(path: "Library/Caches/sweep-없는-빈캐시"),
                                size: 0, category: .devCache, safety: .safe)

        #expect(ScanCoordinator.normalize([cloudOnly, empty]).map(\.url) == [cloudOnly.url])
    }

    @Test("normalize는 분류마다 다른 범위로 거른다")
    func normalizeUsesCategoryScope() {
        let url = home.appending(path: "Documents/sweep-없는-영상.mov")
        let large = CleanupItem(url: url, size: 200, category: .largeFile, safety: .caution)
        let wrong = CleanupItem(url: url.appending(path: "x"), size: 200, category: .devCache, safety: .safe)

        let kept = ScanCoordinator.normalize([large, wrong])
        #expect(kept.map(\.category) == [.largeFile])
    }

    @Test("원본이 큰 파일로 함께 올라오면 중복 사본은 '원본이 남아요'라고 하지 않고 자동 선택에서 빠진다")
    func normalizeWarnsWhenOriginalIsListed() {
        let original = home.appending(path: "Downloads/sweep-없는-원본.mov")
        let copy = CleanupItem(url: home.appending(path: "Downloads/sweep-없는-사본.mov"),
                               size: 200, category: .duplicate, safety: .safe,
                               detail: "같은 내용의 원본이 남아요: sweep-없는-원본.mov",
                               originalURL: original)
        let large = CleanupItem(url: original, size: 200, category: .largeFile, safety: .caution)

        let alone = ScanCoordinator.normalize([copy])
        #expect(alone.first?.detail == copy.detail)
        #expect(alone.first?.isSelectedByDefault == true)

        let together = ScanCoordinator.normalize([copy, large])
        let warned = together.first { $0.category == .duplicate }
        #expect(warned?.detail.contains("원본도 정리 목록에 있어요") == true)
        #expect(warned?.isSelectedByDefault == false)
        #expect(together.first { $0.category == .largeFile } == large)
    }

    @Test("보는 곳 목록에 사용자 폴더가 한 번씩 나온다")
    func currentRootsIncludeUserFolders() {
        let paths = ProtectedPaths.currentRoots.map { FolderAccess.components(of: $0) }
        #expect(paths.contains(FolderAccess.components(of: home.appending(path: "Documents"))))
        #expect(paths.count == Set(paths).count, "같은 곳이 두 번 나온다")
    }
}
