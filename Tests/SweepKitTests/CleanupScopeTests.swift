import Testing
import Foundation
@testable import SweepKit

@Suite("CleanupScope")
struct CleanupScopeTests {

    @Test("보는 곳 목록이 안전 게이트의 허용 루트에서 나온다")
    func derivedFromAllowedRoots() {
        let scopes = CleanupScope.all
        let roots = Set(ProtectedPaths.allowedRoots.map(\.path))

        #expect(!scopes.isEmpty)
        // 손으로 적은 경로가 섞이면 화면이 안전 게이트와 어긋난다
        for scope in scopes {
            #expect(roots.contains(scope.url.path), "허용 루트에 없는 경로: \(scope.url.path)")
        }
    }

    @Test("임시 컨테이너는 하나로 묶인다")
    func temporaryContainersCollapse() {
        let scopes = CleanupScope.all
        // 접두사를 한 곳에서만 판단한다. 테스트가 코드와 다른 접두사를 쓰면
        // 둘 다 틀려도 공허하게 통과한다 — 실제로 한 번 그랬다.
        func isTemporary(_ path: String) -> Bool {
            path.hasPrefix("/var/folders/") || path.hasPrefix("/private/var/folders/")
        }
        let temps = scopes.filter { isTemporary($0.url.path) }

        // `/private/var/folders/<해시>/C`와 `/T` 둘 다 허용 루트지만
        // 화면에 원시 경로를 두 줄 쓰면 읽히지 않는다
        #expect(temps.count <= 1)
        let rawTemps = ProtectedPaths.allowedRoots.filter { isTemporary($0.path) }
        // 허용 루트에 임시 컨테이너가 실제로 있어야 이 TC가 의미를 갖는다
        #expect(!rawTemps.isEmpty, "임시 컨테이너가 허용 루트에 없다 — TC가 공허하다")
        if !rawTemps.isEmpty {
            #expect(temps.count == 1)
            #expect(temps[0].label == "앱 임시 폴더")
        }
    }

    @Test("홈 아래 경로는 물결로 줄인다")
    func homePathsAreShortened() {
        let scopes = CleanupScope.all
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        for scope in scopes where scope.url.path.hasPrefix(home) {
            #expect(scope.label.hasPrefix("~"))
            // 홈 전체 경로가 그대로 노출되면 화면이 넘친다
            #expect(!scope.label.contains(home))
        }
    }

    @Test("모든 항목이 설명을 갖는다")
    func namedRootsHaveDetail() {
        let named = ["~/Library/Developer", "~/Library/Caches",
                     "~/Library/Logs", "~/Downloads", "/private/tmp"]
        let scopes = CleanupScope.all

        for label in named {
            guard let scope = scopes.first(where: { $0.label == label }) else { continue }
            #expect(!scope.detail.isEmpty, "\(label)에 설명이 없다")
        }
        // 설명 없는 항목은 화면에서 미완성으로 읽힌다
        for scope in scopes {
            #expect(!scope.detail.isEmpty, "\(scope.label)에 설명이 없다")
        }
    }

    @Test("같은 경로가 두 번 나오지 않는다")
    func noDuplicates() {
        let ids = CleanupScope.all.map(\.id)
        #expect(ids.count == Set(ids).count)
    }
}
