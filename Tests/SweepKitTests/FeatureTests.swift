import Testing
import Foundation
@testable import SweepKit

@Suite("Feature")
struct FeatureTests {

    // TC-1
    @Test("5개 기능 전부 표시명·아이콘·설명을 가진다")
    func everyFeatureIsPresentable() {
        #expect(Feature.allCases.count == 5)
        for feature in Feature.allCases {
            #expect(!feature.displayName.isEmpty)
            #expect(!feature.systemImageName.isEmpty)
            #expect(!feature.summary.isEmpty)
        }
        // 표시명이 겹치면 사이드바에서 같은 줄이 두 번 보인다
        #expect(Set(Feature.allCases.map(\.displayName)).count == 5)
    }

    // TC-2
    @Test("정크 파일은 임시·Xcode·개발 캐시·묵은 캐시 4종을 돌린다")
    func junkRunsFourScanners() {
        let categories = Feature.junk.categories
        #expect(Feature.junk.scanners.count == 4)
        #expect(Set(categories) == [.runawayTemp, .xcode, .devCache, .staleCache])
        // 큰 파일·중복은 별도 기능이므로 정크에 섞이면 안 된다
        #expect(!categories.contains(.largeFile))
        #expect(!categories.contains(.duplicate))
    }

    // TC-3
    @Test("디스크 맵은 읽기 전용이라 스캐너가 없다")
    func diskMapHasNoScanners() {
        #expect(Feature.diskMap.scanners.isEmpty)
        #expect(Feature.diskMap.categories.isEmpty)
        #expect(Feature.diskMap.isScannable == false)

        // 나머지는 전부 스캔 가능해야 한다
        for feature in Feature.allCases where feature != .diskMap {
            #expect(feature.isScannable, "\(feature)가 스캔 불가로 나온다")
        }
    }

    // TC-4
    @Test("스마트 스캔은 기본 구성과 같은 6종을 돌린다")
    func smartScanCoversEveryCategory() {
        // 스캐너를 추가하고 Feature에 넣는 것을 잊으면 여기서 걸린다.
        // 카테고리 전수와 맞춰 두면 목록이 어긋난 채로 지나가지 않는다.
        #expect(Feature.smartScan.scanners.count == 6)
        #expect(Set(Feature.smartScan.categories) == Set(ScanCategory.allCases))
    }

    @Test("스캔 가능한 기능들의 카테고리를 합치면 스마트 스캔과 같다")
    func featuresPartitionAllCategories() {
        let byFeature = Feature.allCases
            .filter { $0 != .smartScan }
            .flatMap(\.categories)

        // 어느 카테고리도 사이드바에서 갈 곳이 없으면 안 된다
        #expect(Set(byFeature) == Set(ScanCategory.allCases))
        // 같은 카테고리가 두 기능에 걸치면 결과가 중복 집계된다
        #expect(byFeature.count == Set(byFeature).count)
    }

    // TC-5
    @Test("큰 파일과 중복 파일은 자기 스캐너 하나씩만 갖는다")
    func singleScannerFeatures() {
        #expect(Feature.largeFile.scanners.count == 1)
        #expect(Feature.largeFile.categories == [.largeFile])

        #expect(Feature.duplicate.scanners.count == 1)
        #expect(Feature.duplicate.categories == [.duplicate])
    }

    // TC-6
    @Test("스캐너가 없는 기능의 coordinator는 즉시 빈 결과를 준다")
    func emptyCoordinatorFinishesImmediately() async {
        // 실제 스캔은 43초라 TC로 쓸 수 없다. 0개 구성으로 흐름만 확인한다.
        let items = await Feature.diskMap.coordinator.scan()
        #expect(items.isEmpty)
    }

    // MARK: - 스마트 스캔 요약 (Phase 4 / Step 1)

    private func item(_ name: String, _ category: ScanCategory, _ size: Int64) -> CleanupItem {
        CleanupItem(url: URL(filePath: "/private/tmp/\(name)"),
                    size: size, category: category, safety: .safe)
    }

    // TC-2 (Step 1)
    @Test("요약 카드는 자기 자신과 읽기 전용을 뺀 기능들이다")
    func summaryCardsExcludeSelfAndReadOnly() {
        let cards = Feature.summaryCards

        #expect(!cards.contains(.smartScan))   // 자기를 가리키는 카드는 뜻이 없다
        #expect(!cards.contains(.diskMap))     // 스캔하지 않으니 발견량도 없다
        #expect(cards == [.junk, .largeFile, .duplicate])
        // 손으로 나열하지 않았으므로 스캔 가능한 기능 수와 맞아야 한다
        #expect(cards.count == Feature.allCases.filter(\.isScannable).count - 1)
    }

    // TC-4
    @Test("스캔 결과가 기능별로 빠짐없이, 겹침 없이 갈린다")
    func itemsPartitionAcrossFeatures() {
        let all = [
            item("임시", .runawayTemp, 100),
            item("빌드", .xcode, 200),
            item("캐시", .devCache, 300),
            item("묵은", .staleCache, 400),
            item("큰것", .largeFile, 500),
            item("사본", .duplicate, 600),
        ]

        let split = Feature.summaryCards.map { $0.items(from: all) }

        // 합이 전체와 같아야 한다 — 어느 항목도 어느 카드에도 안 잡히면 안 된다
        #expect(split.flatMap { $0 }.count == all.count)
        #expect(split.reduce(0) { $0 + $1.totalSize } == all.totalSize)

        // 같은 항목이 두 카드에 걸치면 총합이 부풀려진다
        let urls = split.flatMap { $0 }.map(\.url)
        #expect(urls.count == Set(urls).count)

        #expect(Feature.junk.items(from: all).count == 4)
        #expect(Feature.largeFile.items(from: all).map(\.displayName) == ["큰것"])
        #expect(Feature.duplicate.items(from: all).map(\.displayName) == ["사본"])
    }

    // TC-5
    @Test("담당 항목이 없는 기능은 빈 배열을 준다")
    func featureWithNoMatchesIsEmpty() {
        let onlyJunk = [item("캐시", .devCache, 300)]

        // 카드를 비활성으로 만드는 근거. 누르면 빈 결과 화면으로 떨어진다.
        #expect(Feature.largeFile.items(from: onlyJunk).isEmpty)
        #expect(Feature.duplicate.items(from: onlyJunk).isEmpty)
        #expect(!Feature.junk.items(from: onlyJunk).isEmpty)

        // 아무것도 못 찾은 경우
        for feature in Feature.summaryCards {
            #expect(feature.items(from: []).isEmpty)
        }
    }

    // MARK: - 기능 색 (design-bounce)

    private func rgb(_ h: UInt32) -> (Double, Double, Double) {
        (Double((h >> 16) & 0xFF), Double((h >> 8) & 0xFF), Double(h & 0xFF))
    }

    private func luminance(_ c: (Double, Double, Double)) -> Double {
        func f(_ v: Double) -> Double {
            let s = v / 255
            return s <= 0.03928 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * f(c.0) + 0.7152 * f(c.1) + 0.0722 * f(c.2)
    }

    private func contrast(_ a: (Double, Double, Double), _ b: (Double, Double, Double)) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// sRGB → 색상각(0~360).
    private func hue(_ c: (Double, Double, Double)) -> Double {
        let r = c.0 / 255, g = c.1 / 255, b = c.2 / 255
        let mx = max(r, g, b), mn = min(r, g, b), d = mx - mn
        guard d > 0 else { return 0 }
        let h: Double
        if mx == r { h = (g - b) / d }
        else if mx == g { h = 2 + (b - r) / d }
        else { h = 4 + (r - g) / d }
        return (h * 60).truncatingRemainder(dividingBy: 360) + (h < 0 ? 360 : 0)
    }

    @Test("기능 색이 양쪽 모드의 표면 위에서 AA를 넘는다")
    func featureTintsPassContrast() {
        // 표면 토큰 실측값 (Theme와 같은 값 — 여기가 틀리면 화면에서 글자가 무너진다)
        let darkSurface = (42.0, 44.0, 46.0)     // #2A2C2E
        let darkRaised  = (52.0, 54.0, 58.0)     // #34363A
        let lightSurface = (255.0, 255.0, 255.0)
        let lightRaised  = (232.0, 232.0, 234.0) // #E8E8EA

        for feature in Feature.allCases {
            guard let tint = feature.tintHex else { continue }
            let d = rgb(tint.dark), l = rgb(tint.light)
            for (label, pair) in [("다크 본문", (d, darkSurface)), ("다크 카드", (d, darkRaised)),
                                  ("라이트 본문", (l, lightSurface)), ("라이트 카드", (l, lightRaised))] {
                let r = contrast(pair.0, pair.1)
                #expect(r >= 4.5, "\(feature) \(label) \(r)")
            }
        }
    }

    @Test("기능 색끼리 색상각이 충분히 벌어져 있다")
    func featureTintsAreDistinguishable() {
        let hues = Feature.allCases.compactMap { $0.tintHex }.map { hue(rgb($0.dark)) }.sorted()
        #expect(hues.count == 4, "고유색을 가진 기능이 4개여야 한다")

        // 색상각이 붙어 있으면 사이드바에서 두 기능이 같은 색으로 읽힌다
        for (a, b) in zip(hues, hues.dropFirst()) {
            #expect(b - a >= 30, "색상각 간격 \(b - a)°가 너무 좁다")
        }
    }

    @Test("스마트 스캔은 고유색을 갖지 않는다")
    func smartScanHasNoTint() {
        // 전체를 대표하는 화면이라 고유색을 주면 정크와 겹친다
        #expect(Feature.smartScan.tintHex == nil)
        for feature in Feature.allCases where feature != .smartScan {
            #expect(feature.tintHex != nil, "\(feature)에 색이 없다")
        }
    }
}
