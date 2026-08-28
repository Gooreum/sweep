import Testing
import Foundation
@testable import SweepKit

@Suite("Model")
struct ModelTests {

    // TC-2
    @Test("CleanupItem은 전달받은 필드를 그대로 보존한다")
    func cleanupItemPreservesFields() {
        let url = URL(filePath: "/private/tmp/runaway.mov")
        let item = CleanupItem(
            url: url,
            size: 163_507_260_057,
            category: .runawayTemp,
            safety: .caution,
            detail: "Simulator (PID 81652)가 쓰는 중"
        )

        #expect(item.url == url)
        #expect(item.size == 163_507_260_057)
        #expect(item.category == .runawayTemp)
        #expect(item.safety == .caution)
        #expect(item.detail == "Simulator (PID 81652)가 쓰는 중")
        #expect(item.displayName == "runaway.mov")
    }

    // TC-3
    @Test("safe만 기본 선택되고 caution·danger는 선택되지 않는다")
    func onlySafeIsSelectedByDefault() {
        #expect(SafetyLevel.safe.isSelectedByDefault == true)
        #expect(SafetyLevel.caution.isSelectedByDefault == false)
        #expect(SafetyLevel.danger.isSelectedByDefault == false)
    }

    @Test("SafetyLevel은 위험도 순으로 비교된다")
    func safetyLevelOrdering() {
        #expect(SafetyLevel.safe < SafetyLevel.caution)
        #expect(SafetyLevel.caution < SafetyLevel.danger)
    }

    // TC-4
    @Test("크기 0과 1TB가 사람이 읽는 문자열로 표시된다")
    func formattedSizeHandlesBoundaries() {
        let zero = CleanupItem(url: URL(filePath: "/private/tmp/empty"),
                               size: 0, category: .devCache, safety: .safe)
        let huge = CleanupItem(url: URL(filePath: "/private/tmp/huge"),
                               size: 1_099_511_627_776, category: .runawayTemp, safety: .caution)

        #expect(!zero.formattedSize.isEmpty)
        #expect(zero.formattedSize.contains("0") || zero.formattedSize.lowercased().contains("zero"))
        // 1TB는 바이트 숫자가 그대로 노출되면 안 된다
        #expect(!huge.formattedSize.contains("1099511627776"))
        #expect(huge.formattedSize.contains("TB") || huge.formattedSize.contains("GB"))
    }

    // TC-5
    @Test("ScanCategory는 6종이며 모두 표시명을 가진다")
    func scanCategoryHasSixCasesWithNames() {
        #expect(ScanCategory.allCases.count == 6)
        for category in ScanCategory.allCases {
            #expect(!category.displayName.isEmpty)
            #expect(!category.systemImageName.isEmpty)
        }
        // 폭주 임시파일이 항상 최상단
        #expect(ScanCategory.runawayTemp.sortOrder == 0)
    }

    // TC-6
    @Test("같은 url을 가진 항목은 Set에서 하나로 합쳐진다")
    func cleanupItemIsHashable() {
        let url = URL(filePath: "/private/tmp/dup.bin")
        let a = CleanupItem(url: url, size: 100, category: .duplicate, safety: .safe)
        let b = CleanupItem(url: url, size: 100, category: .duplicate, safety: .safe)

        #expect(Set([a, b]).count == 1)
    }

    @Test("항목 배열의 총 용량이 합산된다")
    func totalSizeSumsItems() {
        let items = [
            CleanupItem(url: URL(filePath: "/private/tmp/a"), size: 1_000,
                        category: .devCache, safety: .safe),
            CleanupItem(url: URL(filePath: "/private/tmp/b"), size: 2_500,
                        category: .devCache, safety: .safe),
        ]

        #expect(items.totalSize == 3_500)
        #expect(!items.formattedTotalSize.isEmpty)
    }
}
