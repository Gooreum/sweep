import Foundation
import Testing
@testable import SweepKit

/// Finder에서 보기 · 경로 복사.
///
/// Finder를 실제로 열어 볼 수는 없다. 대신 **무엇을 넘겼는지**를 본다 —
/// 화면에서 엉뚱한 URL을 넘기는 실수는 여기서 잡힌다.
@Suite("ItemActions", .serialized)
struct ItemActionsTests {

    /// 원래 구현을 되돌려 놓는다. 안 그러면 다른 스위트가 스텁을 물려받는다.
    private func withStubs(
        _ body: (_ revealed: @escaping () -> [[URL]], _ copied: @escaping () -> [String]) -> Void
    ) {
        let revealBox = Box<[URL]>()
        let copyBox = Box<String>()
        let originalReveal = ItemActions.revealInFinder
        let originalCopy = ItemActions.writeToPasteboard
        defer {
            ItemActions.revealInFinder = originalReveal
            ItemActions.writeToPasteboard = originalCopy
        }

        ItemActions.revealInFinder = { revealBox.append($0) }
        ItemActions.writeToPasteboard = { copyBox.append($0) }
        body({ revealBox.value }, { copyBox.value })
    }

    private final class Box<Element>: @unchecked Sendable {
        private let lock = NSLock()
        private var stored: [Element] = []
        func append(_ element: Element) {
            lock.lock(); defer { lock.unlock() }
            stored.append(element)
        }
        var value: [Element] {
            lock.lock(); defer { lock.unlock() }
            return stored
        }
    }

    // TC-1
    @Test("reveal은 그 URL 하나만 넘긴다")
    func revealPassesSingleURL() {
        let url = URL(filePath: "/Users/tester/Library/Caches/Anki")

        withStubs { revealed, _ in
            ItemActions.reveal(url)

            #expect(revealed() == [[url]])
        }
    }

    // TC-2
    @Test("copyPath는 파일 시스템 경로를 넘긴다")
    func copyPassesPath() {
        let url = URL(filePath: "/Users/tester/Downloads/big.bin")

        withStubs { _, copied in
            ItemActions.copyPath(url)

            #expect(copied() == ["/Users/tester/Downloads/big.bin"])
        }
    }

    // TC-3
    @Test("공백과 한글이 든 경로도 원문 그대로 간다")
    func copyKeepsRawPath() {
        let url = URL(filePath: "/Users/tester/내 문서/보관 자료.zip")

        withStubs { _, copied in
            ItemActions.copyPath(url)

            // 터미널에 붙여 넣을 값이다. %20으로 바뀌면 쓸 수 없다.
            #expect(copied() == ["/Users/tester/내 문서/보관 자료.zip"])
            #expect(!(copied().first?.contains("%20") ?? true))
        }
    }

    // TC-4
    @Test("없는 경로도 막지 않고 그대로 넘긴다")
    func revealMissingPath() {
        let ghost = URL(filePath: "/private/tmp/sweep-없음-\(UUID().uuidString)")

        withStubs { revealed, _ in
            ItemActions.reveal(ghost)

            // 존재 여부는 Finder가 판단한다. 우리가 삼키면 아무 일도 안 일어난 것처럼 보인다.
            #expect(revealed() == [[ghost]])
        }
    }
}
