import Foundation
import Testing
@testable import SweepKit

/// 목록에 보여줄 경로 줄임.
///
/// 이 스위트의 핵심은 TC-4다. **접두사만 겹치는 경로를 줄이면 남의 홈이 내 홈으로 보인다.**
@Suite("경로 줄임")
struct DisplayPathTests {

    private let home = "/Users/tester"

    // TC-1
    @Test("홈 하위는 ~로 줄인다")
    func insideHome() {
        #expect(CleanupItem.abbreviating("/Users/tester/Library/Caches/Anki", home: home)
                == "~/Library/Caches/Anki")
    }

    // TC-2
    @Test("홈 자신은 ~ 하나다")
    func homeItself() {
        #expect(CleanupItem.abbreviating(home, home: home) == "~")
    }

    // TC-3
    @Test("홈 밖은 그대로 둔다")
    func outsideHome() {
        // `/Library`를 `~`로 줄이면 사용자 것으로 잘못 읽힌다.
        #expect(CleanupItem.abbreviating("/Library/Caches/A", home: home) == "/Library/Caches/A")
        #expect(CleanupItem.abbreviating("/private/tmp/x", home: home) == "/private/tmp/x")
    }

    // TC-4
    @Test("접두사만 겹치는 경로는 줄이지 않는다")
    func prefixCollision() {
        // `/` 없이 비교하면 `/Users/tester2`가 `/Users/tester`에 걸린다.
        #expect(CleanupItem.abbreviating("/Users/tester2/Downloads", home: home)
                == "/Users/tester2/Downloads")
        #expect(CleanupItem.abbreviating("/Users/testerX", home: home) == "/Users/testerX")
    }

    // TC-5
    @Test("홈이 비어 있어도 터지지 않는다")
    func emptyHome() {
        #expect(CleanupItem.abbreviating("/Users/tester/x", home: "") == "/Users/tester/x")
    }

    // TC-6
    @Test("한글과 공백이 든 경로도 원문을 지킨다")
    func unicodePath() {
        let path = "/Users/tester/내 문서/보관 자료"

        let shortened = CleanupItem.abbreviating(path, home: home)

        // 퍼센트 인코딩이 끼면 사람이 읽을 수 없다.
        #expect(shortened == "~/내 문서/보관 자료")
        #expect(!shortened.contains("%20"))
    }

    // TC-7
    @Test("항목에서 바로 읽을 수 있다")
    func itemDisplayPath() {
        let url = Sandbox.userHome.appending(path: "Library/Caches/Example")
        let item = CleanupItem(url: url, size: 1, category: .appCache, safety: .safe)

        #expect(item.displayPath == "~/Library/Caches/Example")
    }
}
