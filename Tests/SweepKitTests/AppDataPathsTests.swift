import Foundation
import Testing
@testable import SweepKit

/// "다른 앱의 데이터" 보호 구역 판정.
///
/// 이 판정이 헐거우면 프롬프트가 새고, 빡빡하면 볼 수 있는 곳까지 가린다.
@Suite("앱 데이터 보호 구역")
struct AppDataPathsTests {

    private let home = URL(filePath: "/Users/tester")

    private func url(_ relative: String) -> URL {
        home.appending(path: relative)
    }

    // TC-1
    @Test("컨테이너 안의 앱 폴더는 보호 구역이다")
    func insideContainers() {
        #expect(AppDataPaths.isInside(url("Library/Containers/com.apple.Notes"), home: home))
    }

    // TC-2
    @Test("구역 자신은 보호 대상이 아니다")
    func rootItself() {
        // 목록에는 보여야 한다. 여는 것 자체는 묻지 않는다.
        for root in AppDataPaths.roots(home: home) {
            #expect(!AppDataPaths.isInside(root, home: home),
                    "구역 자신이 가려졌다: \(root.path)")
        }
    }

    // TC-3
    @Test("더 깊은 곳도 보호 구역이다")
    func deeperPath() {
        #expect(AppDataPaths.isInside(
            url("Library/Application Support/Google/Chrome/Default/Cache"), home: home))
    }

    // TC-4
    @Test("캐시는 보호 구역이 아니다")
    func cachesAreOpen() {
        // `~/Library/Caches`는 앱 데이터 보호 대상이 아니다 — 여기까지 가리면
        // 정작 지울 수 있는 것을 못 찾는다.
        #expect(!AppDataPaths.isInside(url("Library/Caches/Google"), home: home))
        #expect(!AppDataPaths.isInside(url("Library/Logs/foo"), home: home))
    }

    // TC-5
    @Test("이름이 같아도 위치가 다르면 아니다")
    func nameCollision() {
        #expect(!AppDataPaths.isInside(url("Downloads/Containers/x"), home: home))
        #expect(!AppDataPaths.isInside(URL(filePath: "/Library/Containers/x"), home: home))
    }

    // TC-6
    @Test("세 구역이 모두 걸린다")
    func allThreeRoots() {
        #expect(AppDataPaths.roots(home: home).count == 3)
        #expect(AppDataPaths.isInside(url("Library/Group Containers/group.x"), home: home))
    }
}
