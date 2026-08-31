import Testing
import Foundation
@testable import SweepKit

@Suite("DiskMapRoot")
struct DiskMapRootTests {

    private var home: URL { FileManager.default.homeDirectoryForCurrentUser }

    // TC-2
    @Test("홈·볼륨 루트·응용 프로그램이 시작 지점에 있다")
    func coversWholeMachine() {
        let paths = Set(DiskMapRoot.all.map { $0.url.standardizedFileURL.path })

        // 정리 루트만 보여주던 시절엔 홈 87GB 중 18GB만 훑었다
        #expect(paths.contains(home.standardizedFileURL.path), "홈이 없다")
        #expect(paths.contains("/"), "볼륨 루트가 없다")
        #expect(paths.contains("/Applications"), "응용 프로그램이 없다")
    }

    // TC-3
    @Test("정리 루트도 전부 남아 있다")
    func keepsCleanupRoots() {
        let paths = Set(DiskMapRoot.all.map { $0.url.standardizedFileURL.path })

        // 범위를 넓히면서 기존 시작점을 잃으면 안 된다.
        // 그룹은 달라도 된다 — `~/Downloads`는 "홈 안"으로 올라간다.
        for root in ProtectedPaths.allowedRoots {
            #expect(paths.contains(root.standardizedFileURL.path),
                    "정리 루트가 빠졌다: \(root.path)")
        }
    }

    // TC-4
    @Test("같은 경로가 두 번 나오지 않는다")
    func hasNoDuplicates() {
        let paths = DiskMapRoot.all.map { $0.url.standardizedFileURL.path }

        // `~/Downloads`는 홈이자 정리 대상이다. 같은 줄이 두 번 보이면 고를 때 헷갈린다.
        #expect(paths.count == Set(paths).count, "중복: \(paths)")
        // id도 마찬가지 — Picker의 ForEach가 같은 id를 두 번 만나면 안 된다
        let ids = DiskMapRoot.all.map(\.id)
        #expect(ids.count == Set(ids).count)
    }

    // TC-5
    @Test("실재하지 않는 경로는 목록에 없다")
    func onlyExistingPaths() {
        let roots = DiskMapRoot.all
        #expect(!roots.isEmpty)

        // 없는 경로를 Picker에 올리면 고른 뒤에야 빈 화면이 뜬다
        for root in roots {
            #expect(FileManager.default.fileExists(atPath: root.url.path),
                    "없는 경로가 올라왔다: \(root.url.path)")
        }
    }

    // TC-5
    @Test("없는 폴더는 실제로 걸러진다")
    func missingFoldersAreDropped() {
        // 이 기계엔 홈 폴더가 전부 있어서 위 TC만으로는 검사를 지워도 통과한다.
        // 실재 판정을 흔들어 성질 자체를 고정한다.
        let desktop = home.appending(path: "Desktop").standardizedFileURL.path
        let filtered = DiskMapRoot.roots(home: home) { $0 != desktop }

        #expect(!filtered.contains { $0.url.standardizedFileURL.path == desktop })
        // 나머지는 그대로 남아야 한다 — 하나 뺀다고 목록이 무너지면 안 된다
        #expect(filtered.contains { $0.url.standardizedFileURL.path == "/" })
    }

    // TC-5
    @Test("아무것도 실재하지 않으면 목록이 빈다")
    func nothingExistsYieldsEmpty() {
        #expect(DiskMapRoot.roots(home: home) { _ in false }.isEmpty)
    }

    // TC-6
    @Test("첫 진입에 훑을 곳은 홈이다")
    func initialIsHome() {
        #expect(DiskMapRoot.initial?.url.standardizedFileURL
                == home.standardizedFileURL)
    }

    // TC-7
    @Test("그룹마다 항목이 있다")
    func everyGroupIsPopulated() {
        let roots = DiskMapRoot.all

        // 빈 섹션이 있으면 Picker에 제목만 뜬다
        for group in DiskMapRoot.Group.allCases {
            #expect(roots.contains { $0.group == group },
                    "\(group.rawValue) 그룹이 비었다")
        }
    }

    @Test("라벨이 비어 있지 않고 홈 경로를 그대로 노출하지 않는다")
    func labelsAreReadable() {
        let homePath = home.path

        for root in DiskMapRoot.all {
            #expect(!root.label.isEmpty, "\(root.url.path)에 라벨이 없다")
            // 홈 전체 경로가 그대로 들어가면 Picker가 넘친다
            #expect(!root.label.contains(homePath),
                    "라벨에 홈 경로가 그대로 있다: \(root.label)")
        }
    }
}
