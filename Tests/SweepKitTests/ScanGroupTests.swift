import Testing
import Foundation
@testable import SweepKit

/// 뷰가 `ScanGroup`을 소비할 수 있는 형태인지 확인한다.
/// SwiftUI 뷰 자체는 SweepApp 타깃에 있어 `swift build`로 컴파일 검증한다.
@Suite("ScanGroup")
struct ScanGroupTests {

    private func item(_ name: String, size: Int64, category: ScanCategory,
                      detail: String = "") -> CleanupItem {
        CleanupItem(url: URL(filePath: "/private/tmp/\(name)"),
                    size: size, category: category, safety: .safe, detail: detail)
    }

    // TC-3
    @Test("ScanGroup은 category를 id로 삼아 ForEach에 바로 쓸 수 있다")
    func groupIsIdentifiableByCategory() {
        let group = ScanGroup(category: .xcode,
                              items: [item("a", size: 1, category: .xcode)])
        #expect(group.id == .xcode)
    }

    // TC-4
    @Test("섹션 헤더용 합계가 사람이 읽는 단위로 나온다")
    func groupTotalIsFormatted() {
        let group = ScanGroup(category: .devCache, items: [
            item("a", size: 3_000_000_000, category: .devCache),
            item("b", size: 2_000_000_000, category: .devCache),
        ])

        let text = group.formattedTotalSize
        #expect(!text.contains("5000000000"))
        #expect(text.contains("GB"))
    }

    // TC-5
    @Test("detail이 빈 항목과 채워진 항목을 구분할 수 있다")
    func detailEmptinessIsDistinguishable() {
        let bare = item("bare", size: 1, category: .devCache)
        let described = item("described", size: 1, category: .devCache,
                             detail: "Homebrew 내려받기 캐시")

        #expect(bare.detail.isEmpty)            // 뷰가 설명 줄을 그리지 않는 조건
        #expect(!described.detail.isEmpty)
    }
}
