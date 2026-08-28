import Testing
import Foundation
@testable import SweepKit

@Suite("ScanCategory")
struct ScanCategoryTests {

    // TC-1
    @Test("카테고리는 6종이다")
    func hasSixCases() {
        #expect(ScanCategory.allCases.count == 6)
    }

    // TC-2
    @Test("모든 카테고리가 표시명과 아이콘을 가진다")
    func everyCaseHasDisplayInfo() {
        for category in ScanCategory.allCases {
            #expect(!category.displayName.isEmpty, "\(category) 표시명 없음")
            #expect(!category.systemImageName.isEmpty, "\(category) 아이콘 없음")
        }
    }

    // TC-3
    @Test("sortOrder가 중복 없이 0부터 연속이다")
    func sortOrdersAreUniqueAndContiguous() {
        let orders = ScanCategory.allCases.map(\.sortOrder)

        #expect(Set(orders).count == orders.count, "중복된 sortOrder가 있다")
        #expect(Set(orders) == Set(0..<ScanCategory.allCases.count))
    }

    // TC-4
    @Test("신규 두 카테고리의 표시 정보가 의도대로다")
    func newCategoriesAreLabelled() {
        #expect(ScanCategory.staleCache.displayName == "묵은 캐시")
        #expect(ScanCategory.largeFile.displayName == "대용량 파일")
        #expect(ScanCategory.staleCache.systemImageName == "clock.arrow.circlepath")
        #expect(ScanCategory.largeFile.systemImageName == "arrow.down.doc.fill")
    }

    // TC-5
    @Test("기존 4종의 상대 순서가 유지된다")
    func existingRelativeOrderIsPreserved() {
        #expect(ScanCategory.runawayTemp.sortOrder < ScanCategory.xcode.sortOrder)
        #expect(ScanCategory.xcode.sortOrder < ScanCategory.devCache.sortOrder)
        #expect(ScanCategory.devCache.sortOrder < ScanCategory.duplicate.sortOrder)
        #expect(ScanCategory.runawayTemp.sortOrder == 0)
    }

    // TC-6
    @Test("sortOrder로 정렬하면 재생성 쉬움에서 판단 필요 순으로 늘어선다")
    func sortedOrderIsMeaningful() {
        let sorted = ScanCategory.allCases.sorted { $0.sortOrder < $1.sortOrder }

        #expect(sorted == [.runawayTemp, .xcode, .devCache, .staleCache, .largeFile, .duplicate])
    }

    // TC-7
    @Test("기존 rawValue가 바뀌지 않았다")
    func rawValuesAreStable() {
        // --scan-only 출력과 e2e 스크립트가 이 문자열에 의존한다
        #expect(ScanCategory.runawayTemp.rawValue == "runawayTemp")
        #expect(ScanCategory.xcode.rawValue == "xcode")
        #expect(ScanCategory.devCache.rawValue == "devCache")
        #expect(ScanCategory.duplicate.rawValue == "duplicate")
        #expect(ScanCategory.staleCache.rawValue == "staleCache")
        #expect(ScanCategory.largeFile.rawValue == "largeFile")
    }
}
