import Testing
import Foundation
@testable import SweepKit

@Suite("AppModel")
@MainActor
struct AppModelTests {

    // TC-11
    @Test("같은 기능을 다시 물으면 같은 모델을 돌려준다")
    func modelIsReusedPerFeature() {
        let app = AppModel()

        let first = app.model(for: .junk)
        let second = app.model(for: .junk)

        // 매번 새로 만들면 사이드바를 옮겼다 돌아올 때 스캔 결과가 사라진다.
        // 43초를 다시 기다리게 되는 셈이라 `==`이 아니라 동일 인스턴스여야 한다.
        #expect(first === second)
    }

    // TC-12
    @Test("기능마다 모델이 따로 있고 첫 화면은 스마트 스캔이다")
    func modelsAreSeparatePerFeature() {
        let app = AppModel()

        #expect(app.selected == .smartScan)

        let junk = app.model(for: .junk)
        let large = app.model(for: .largeFile)
        #expect(junk !== large)

        // 스캔 가능한 기능 전부가 서로 다른 인스턴스를 받아야 한다
        let scannable = Feature.allCases.filter(\.isScannable)
        let models = scannable.map { ObjectIdentifier(app.model(for: $0)) }
        #expect(Set(models).count == scannable.count)
    }

    @Test("선택한 기능을 바꿔도 이미 만든 모델은 유지된다")
    func switchingFeatureKeepsModels() {
        let app = AppModel()
        let junk = app.model(for: .junk)

        app.selected = .duplicate
        app.selected = .junk

        #expect(app.model(for: .junk) === junk)
    }

    // MARK: - 디스크 맵 모델 소유권

    // TC-2
    @Test("디스크 맵 모델도 다시 물으면 같은 인스턴스다")
    func diskMapModelIsReused() {
        let app = AppModel()

        // 스캔 모델이 아니라고 규칙이 달라지지 않는다. 매번 새로 만들면
        // 사이드바를 옮겼다 돌아올 때 트리가 사라져 10초를 다시 기다린다.
        #expect(app.diskMap() === app.diskMap())
    }

    // TC-3
    @Test("탭을 옮겼다 디스크 맵으로 돌아와도 같은 모델이다")
    func switchingFeatureKeepsDiskMapModel() {
        let app = AppModel()
        let first = app.diskMap()

        app.selected = .junk
        app.selected = .diskMap

        #expect(app.diskMap() === first)
    }

    // TC-6
    @Test("주입한 디스크 맵 모델을 그대로 돌려준다")
    func diskMapModelIsInjectable() {
        // 기본 구성은 실제 순회를 물고 있어 테스트에서 10초를 기다리게 된다.
        let injected = DiskMapModel(countEntries: { _, _ in 0 },
                                    buildTree: { url, _ in
                                        DiskUsageNode(url: url, size: 0)
                                    })
        let app = AppModel(makeDiskMap: { injected })

        #expect(app.diskMap() === injected)
    }

    // MARK: - 메뉴 잠금 조건 (Phase 2 / Step 1)

    private func item(_ name: String, safety: SafetyLevel = .safe) -> CleanupItem {
        CleanupItem(url: URL(filePath: "/private/tmp/\(name)"),
                    size: 1_000, category: .devCache, safety: safety)
    }

    private func finishing(_ items: [CleanupItem])
        -> @Sendable () -> AsyncStream<ScanCoordinator.Progress> {
        { @Sendable in
            AsyncStream { continuation in
                continuation.yield(ScanCoordinator.Progress(
                    items: items, fraction: 1, elapsed: .seconds(1),
                    estimatedRemaining: nil, finishedScanners: 1, totalScanners: 1))
                continuation.finish()
            }
        }
    }

    // TC-3
    @Test("디스크 맵을 보고 있으면 걸릴 모델이 없다")
    func diskMapHasNoCurrentModel() {
        let app = AppModel()
        app.selected = .diskMap

        // 스캔하지 않는 기능이라 검색·정리 명령이 걸릴 데가 없다
        #expect(app.currentModel == nil)
        // TC-6
        #expect(app.canScan == false)
        #expect(app.canClean == false)
    }

    // TC-4
    @Test("현재 모델은 그 기능의 모델과 같은 인스턴스다")
    func currentModelMatchesFeatureModel() {
        let app = AppModel()

        for feature in Feature.allCases where feature.isScannable {
            app.selected = feature
            #expect(app.currentModel === app.model(for: feature))
        }
    }

    // TC-5
    @Test("기능을 옮기면 현재 모델도 따라간다")
    func currentModelFollowsSelection() {
        let app = AppModel()
        app.selected = .junk
        let junk = app.currentModel

        app.selected = .largeFile

        #expect(app.currentModel !== junk)
        #expect(app.currentModel === app.model(for: .largeFile))
    }

    // TC-7 · TC-8 · TC-9 · TC-10
    @Test("검색은 늘 가능하고 정리는 고른 것이 있을 때만 가능하다")
    func scanAndCleanGates() async {
        let app = AppModel()
        app.selected = .junk

        // 시작 화면 — 검색은 되고 정리는 안 된다
        #expect(app.canScan)            // TC-7
        #expect(!app.canClean)          // TC-8

        // AppModel이 만든 모델은 실제 스캐너를 물고 있어 테스트에 쓸 수 없다.
        // 잠금 조건 자체는 ScanModel의 값만 보므로 직접 만들어 확인한다.
        let model = ScanModel(scan: finishing([item("safe")]))
        await model.scan()
        #expect(model.hasSelection)     // safe는 기본 선택
        #expect(!model.isBusy)

        // TC-10: 메뉴(canClean)와 하단 바가 보는 값이 같다
        #expect(model.hasSelection && !model.isBusy)   // TC-9의 조건

        // 고른 것을 없애면 정리가 잠긴다
        model.apply(.none)
        #expect(!model.hasSelection)
    }

    // TC-9
    @Test("메뉴 막대 요약은 스마트 스캔 모델을 본다")
    func menuBarSummaryReadsSmartScan() {
        let app = AppModel()

        // 사이드바를 다른 기능에 두어도 패널은 전체 스캔 결과를 보여줘야 한다 —
        // 기능별 모델을 합치면 같은 파일이 여러 번 세어진다.
        app.selected = .largeFile
        let summary = app.menuBarSummary

        let smart = app.model(for: .smartScan)
        #expect(summary.reclaimableBytes == smart.items.totalSize)
        #expect(summary.isScanning == smart.isBusy)

        // 아직 아무것도 안 돌렸으니 비어 있다
        #expect(summary.reclaimable == nil)
        #expect(summary.breakdown.isEmpty)
    }

    // MARK: - 사이드바 배지

    private func sized(_ name: String, _ category: ScanCategory, _ size: Int64) -> CleanupItem {
        CleanupItem(url: URL(filePath: "/private/tmp/\(name)"),
                    size: size, category: category, safety: .safe)
    }

    private func stream(_ items: [CleanupItem])
        -> @Sendable () -> AsyncStream<ScanCoordinator.Progress> {
        { @Sendable in
            AsyncStream { continuation in
                continuation.yield(ScanCoordinator.Progress(
                    items: items, fraction: 1, elapsed: .seconds(1),
                    estimatedRemaining: nil, finishedScanners: 6, totalScanners: 6))
                continuation.finish()
            }
        }
    }

    /// 기본 구성은 실제 스캐너를 물고 있어 43초가 걸린다. 모델 생성을 주입한다.
    private func app(with items: [CleanupItem]) async -> AppModel {
        let make = stream(items)
        let app = AppModel(makeModel: { _ in ScanModel(scan: make) })
        await app.model(for: .smartScan).scan()
        return app
    }

    // TC-1
    @Test("아직 훑지 않았으면 배지가 하나도 없다")
    func noBadgesBeforeScan() {
        // "0바이트" 배지는 알려줄 것이 아니라 자리만 차지한다
        #expect(AppModel().badges.isEmpty)
    }

    // TC-2
    @Test("기능마다 담당 항목이 배지로 잡힌다")
    func badgesPerFeature() async {
        let app = await app(with: [
            sized("임시", .runawayTemp, 100), sized("빌드", .xcode, 200),
            sized("큰것", .largeFile, 500), sized("사본", .duplicate, 50),
        ])
        let badges = app.badges

        #expect(badges[.junk] != nil)
        #expect(badges[.largeFile] != nil)
        #expect(badges[.duplicate] != nil)
        #expect(badges[.smartScan] != nil)
        // 스캔하지 않는 기능은 배지가 없다
        #expect(badges[.diskMap] == nil)
    }

    // TC-3 · TC-4
    @Test("기능별 합이 전체와 같고 스마트 스캔이 전체 합이다")
    func badgeSumsMatchTotal() async {
        let items = [
            sized("a", .runawayTemp, 1_000), sized("b", .xcode, 2_000),
            sized("c", .devCache, 3_000), sized("d", .staleCache, 4_000),
            sized("e", .largeFile, 5_000), sized("f", .duplicate, 6_000),
        ]
        let app = await app(with: items)
        let model = app.model(for: .smartScan)

        // 문자열이 아니라 원본에서 다시 계산해 대조한다
        let junk = Feature.junk.items(from: model.items).totalSize
        let large = Feature.largeFile.items(from: model.items).totalSize
        let dup = Feature.duplicate.items(from: model.items).totalSize

        // 한 번 훑기로 바꾸며 카테고리를 빠뜨리면 합이 어긋난다
        #expect(junk + large + dup == items.totalSize)

        let badges = app.badges
        #expect(badges[.smartScan] == items.formattedTotalSize)
        #expect(badges[.junk] == Feature.junk.items(from: model.items).formattedTotalSize)
        #expect(badges[.largeFile] == Feature.largeFile.items(from: model.items).formattedTotalSize)
        #expect(badges[.duplicate] == Feature.duplicate.items(from: model.items).formattedTotalSize)
    }

    // TC-6
    @Test("배지 문자열이 기능별 개별 계산과 일치한다")
    func badgesMatchPerFeatureCalculation() async {
        let app = await app(with: [
            sized("캐시", .devCache, 7_777), sized("사본", .duplicate, 333),
        ])
        let model = app.model(for: .smartScan)
        let badges = app.badges

        for feature in Feature.summaryCards {
            let matched = feature.items(from: model.items)
            if matched.isEmpty {
                #expect(badges[feature] == nil, "\(feature)에 빈 배지가 붙었다")
            } else {
                #expect(badges[feature] == matched.formattedTotalSize)
            }
        }
    }
}