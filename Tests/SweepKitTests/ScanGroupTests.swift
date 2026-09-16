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
    @Test("ScanGroup은 나눈 기준을 id로 삼아 ForEach에 바로 쓸 수 있다")
    func groupIsIdentifiableByKind() {
        let group = ScanGroup(kind: .category(.xcode),
                              items: [item("a", size: 1, category: .xcode)])
        #expect(group.id == .category(.xcode))
        #expect(group.category == ScanCategory.xcode)
        #expect(group.displayName == ScanCategory.xcode.displayName)
    }

    // TC-3b
    @Test("판단 기준으로 묶으면 이름이 등급이 아니라 뜻으로 나온다")
    func safetyGroupNamesTheJudgement() {
        let group = ScanGroup(kind: .safety(.safe),
                              items: [item("a", size: 1, category: .xcode)])
        // "안전 4개"보다 "다시 만들 수 있음 4개"가 고를 때 쓸모 있다.
        #expect(group.displayName == "다시 만들 수 있음")
        #expect(group.category == nil)
    }

    // TC-4
    @Test("섹션 헤더용 합계가 사람이 읽는 단위로 나온다")
    func groupTotalIsFormatted() {
        let group = ScanGroup(kind: .category(.devCache), items: [
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
