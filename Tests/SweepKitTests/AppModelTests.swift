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

    // TC-3 (CPU)
    @Test("탭을 옮겼다 CPU로 돌아와도 같은 모델이다")
    func switchingFeatureKeepsCPUModel() {
        // 새로 만들면 "측정 중…"을 2초 동안 다시 본다.
        let app = AppModel(makeCPU: { CPUModel(sample: { [] }) })
        let first = app.cpu()

        app.selected = .junk
        app.selected = .cpu

        #expect(app.cpu() === first)
    }

    // TC-3 (CPU)
    @Test("CPU를 보고 있으면 걸릴 모델이 없다")
    func cpuHasNoCurrentModel() {
        let app = AppModel(makeCPU: { CPUModel(sample: { [] }) })
        app.selected = .cpu

        // 스캔하지 않는 기능이라 검색·정리 명령이 걸릴 데가 없다
        #expect(app.currentModel == nil)
        // 툴바의 "다시 검색"·"안전 항목 선택"이 스스로 꺼진다
        #expect(app.canScan == false)
        #expect(app.canClean == false)
    }

    // TC-6 (CPU)
    @Test("주입한 CPU 모델을 그대로 돌려준다")
    func cpuModelIsInjectable() {
        // 기본 구성은 실제 syscall을 물고 있다.
        let injected = CPUModel(sample: { [] })
        let app = AppModel(makeCPU: { injected })

        #expect(app.cpu() === injected)
    }

    // TC-6
    @Test("주입한 디스크 맵 모델을 그대로 돌려준다")
    func diskMapModelIsInjectable() {
        // 기본 구성은 실제 순회를 물고 있어 테스트에서 10초를 기다리게 된다.
        let injected = DiskMapModel(countEntries: { _, _, _ in 0 },
                                    buildTree: { url, _, _ in
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
        #expect(badges[.cpu] == nil)
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

    // MARK: - 스마트 스캔 결과 나눠 주기

    private func categorized(_ name: String, _ category: ScanCategory,
                             safety: SafetyLevel = .safe) -> CleanupItem {
        CleanupItem(url: URL(filePath: "/private/tmp/\(name)"),
                    size: 1_000, category: category, safety: safety)
    }

    /// 기능 세 개가 각자 몫을 갖도록 카테고리를 섞은 전체 결과.
    private var mixed: [CleanupItem] {
        [categorized("정크.bin", .devCache),
         categorized("임시", .runawayTemp),
         categorized("큰영상.mov", .largeFile),
         categorized("사본.zip", .duplicate),
         categorized("버린것.dmg", .trash)]
    }

    /// 지우지 않는 테스트용 기록 저장소. 한 번도 쓰지 않으므로 디스크에 남는 것이 없다.
    /// 지우는 테스트는 `isolatedHistory()`를 따로 만들어 정리까지 한다.
    private static let unwrittenHistory = CleanupHistory(
        defaults: UserDefaults(suiteName: "sweep-test-appmodel-unwritten")!)

    /// 격리된 기록 저장소와 그 정리 클로저. 실제 `.standard`에 쓰지 않는다.
    private func isolatedHistory() throws -> (CleanupHistory, () -> Void) {
        let suite = "sweep-test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        return (CleanupHistory(defaults: defaults), { defaults.removePersistentDomain(forName: suite) })
    }

    /// 지정한 기능만 결과를 내고 나머지는 빈 스캔인 앱.
    private func app(scanning feature: Feature, finds found: [CleanupItem],
                     history: CleanupHistory = AppModelTests.unwrittenHistory,
                     removeOne: @escaping @Sendable (CleanupItem) -> RemovalOutcome
                        = { RemovalOutcome(item: $0, failureReason: nil) }) -> AppModel {
        AppModel(makeModel: { f in
            ScanModel(scan: f == feature ? self.finishing(found) : self.finishing([]),
                      removeOne: removeOne)
        }, history: history)
    }

    /// 끝나지 않는 스캔 — 그 탭을 `.scanning`에 붙잡아 둔다.
    private func neverFinishing() -> @Sendable () -> AsyncStream<ScanCoordinator.Progress> {
        { @Sendable in
            AsyncStream { continuation in
                continuation.yield(ScanCoordinator.Progress(
                    items: [], fraction: 0.5, elapsed: .seconds(1),
                    estimatedRemaining: .seconds(1),
                    finishedScanners: 1, totalScanners: 2))
            }
        }
    }

    // TC-2
    @Test("스마트 스캔이 끝나면 기능 탭이 각자 몫으로 채워진다")
    func smartScanSharesResults() async {
        let app = app(scanning: .smartScan, finds: mixed)

        await app.model(for: .smartScan).scan()

        for feature in Feature.summaryCards {
            let mine = feature.items(from: mixed)
            // 몫이 비어 있으면 이 TC는 아무것도 검증하지 못한다
            #expect(!mine.isEmpty, "\(feature) 몫이 비어 TC가 공허하다")
            #expect(app.model(for: feature).items.map(\.url) == mine.map(\.url),
                    "\(feature)에 자기 몫이 안 들어왔다")
        }
    }

    // TC-3
    @Test("배분된 기능 탭은 바로 결과 목록 상태다")
    func sharedTabsLandInResults() async {
        let app = app(scanning: .smartScan, finds: mixed)

        await app.model(for: .smartScan).scan()

        for feature in Feature.summaryCards {
            // `.idle`이면 탭에 들어갔을 때 "검색" 버튼만 뜬다 — 고치기 전 상태다
            #expect(app.model(for: feature).phase == .results, "\(feature)가 결과 상태가 아니다")
        }
    }

    // TC-4
    @Test("기능 탭 스캔 결과는 다른 탭으로 퍼지지 않는다")
    func featureScanDoesNotSpread() async {
        let app = app(scanning: .junk, finds: mixed)

        await app.model(for: .junk).scan()

        // 정크 탭은 자기 몫만 훑는다. 그 결과를 퍼뜨리면 큰 파일 탭이
        // "훑어봤는데 없다"는 거짓말을 하게 된다.
        #expect(app.model(for: .largeFile).items.isEmpty)
        #expect(app.model(for: .duplicate).items.isEmpty)
        #expect(app.model(for: .smartScan).items.isEmpty)
    }

    // TC-5
    @Test("스캔 중인 탭은 배분이 덮지 않는다")
    func sharingSkipsBusyTab() async {
        let app = AppModel(makeModel: { f in
            switch f {
            case .smartScan: ScanModel(scan: self.finishing(self.mixed))
            case .largeFile: ScanModel(scan: self.neverFinishing())
            default: ScanModel(scan: self.finishing([]))
            }
        })
        let big = app.model(for: .largeFile)
        let running = Task { await big.scan() }
        for _ in 0..<50 where !big.isBusy { await Task.yield() }
        #expect(big.isBusy, "큰 파일 탭이 스캔 중이 아니어서 TC가 공허하다")

        await app.model(for: .smartScan).scan()

        // 돌고 있는 스캔을 결과로 덮으면 진행률이 사라지고 화면이 튄다
        #expect(big.isBusy, "스캔 중인 탭이 덮였다")
        #expect(big.items.isEmpty)
        // 나머지 탭은 정상 배분
        #expect(!app.model(for: .junk).items.isEmpty)

        running.cancel()
    }

    @Test("정리 결과를 띄운 탭은 배분이 덮지 않아 되돌릴 수 있다")
    func sharingSkipsTabShowingOutcome() async throws {
        let (history, cleanup) = try isolatedHistory()
        defer { cleanup() }
        let app = app(scanning: .smartScan, finds: mixed, history: history,
                      removeOne: { RemovalOutcome(item: $0, failureReason: nil,
                                                  trashedURL: URL(filePath: "/Users/x/.Trash/\($0.displayName)")) })
        let smart = app.model(for: .smartScan)
        await smart.scan()

        let junk = app.model(for: .junk)
        let target = try #require(junk.items.first, "정크 탭이 비어 배분이 끊겼다")
        junk.selection = [target.url]
        await junk.removeSelected()
        #expect(junk.canUndo, "되돌릴 수 없는 상태라 TC가 공허하다")

        // 다른 탭에서 스마트 스캔을 다시 돌려도 완료 화면과 되돌리기는 남아야 한다
        await smart.scan()

        #expect(junk.phase == .cleaned, "완료 화면이 덮였다")
        #expect(junk.canUndo, "되돌리기 기록이 사라졌다")
        // 나머지 탭은 정상 배분
        #expect(app.model(for: .largeFile).phase == .results)
    }

    // TC-6
    @Test("기능 탭에서 지우면 스마트 스캔 목록에서도 빠진다")
    func removalInFeatureTabPropagatesToSmartScan() async throws {
        let (history, cleanup) = try isolatedHistory()
        defer { cleanup() }
        let app = app(scanning: .smartScan, finds: mixed, history: history)
        await app.model(for: .smartScan).scan()

        let junk = app.model(for: .junk)
        // `items[0]`으로 찌르면 배분이 끊겼을 때 **스위트 전체가 크래시**한다 —
        // 그러면 다른 실패까지 전부 묻힌다. 여기서 깔끔하게 멈춘다.
        let target = try #require(junk.items.first, "정크 탭이 비어 배분이 끊겼다")
        junk.selection = [target.url]
        await junk.removeSelected()

        // 지운 파일이 다른 화면에 남아 있으면 목록도 배지도 거짓말이 된다
        #expect(!app.model(for: .smartScan).items.contains { $0.url == target.url })
    }

    // TC-7
    @Test("스마트 스캔에서 지우면 기능 탭 목록에서도 빠진다")
    func removalInSmartScanPropagatesToFeatureTabs() async throws {
        let (history, cleanup) = try isolatedHistory()
        defer { cleanup() }
        let app = app(scanning: .smartScan, finds: mixed, history: history)
        let smart = app.model(for: .smartScan)
        await smart.scan()

        let junk = app.model(for: .junk)
        let target = try #require(junk.items.first, "정크 탭이 비어 배분이 끊겼다")
        smart.selection = [target.url]
        await smart.removeSelected()

        #expect(!junk.items.contains { $0.url == target.url })
    }

    // MARK: - 정리 기록 (pm #1)

    @Test("기능 탭에서 지우면 앱이 기록을 남기고 요약이 갱신된다")
    func removalIsRecordedInHistory() async throws {
        let (history, cleanup) = try isolatedHistory()
        defer { cleanup() }
        let app = app(scanning: .smartScan, finds: mixed, history: history)
        await app.model(for: .smartScan).scan()
        #expect(app.cleanupSummary == .empty)

        let junk = app.model(for: .junk)
        let target = try #require(junk.items.first, "정크 탭이 비어 배분이 끊겼다")
        junk.selection = [target.url]
        await junk.removeSelected()

        // 어느 기능 모델에서 지웠든 한 곳에 쌓이고, 화면이 보는 관찰 값이 따라온다
        #expect(app.cleanupSummary.totalReclaimedBytes == 1_000)
        #expect(app.cleanupSummary.lastCleanup != nil)
        #expect(history.records.count == 1)
    }

    @Test("기록이 있는 저장소로 만들면 요약이 복원돼 있다")
    func summaryIsRestoredOnLaunch() throws {
        let (history, cleanup) = try isolatedHistory()
        defer { cleanup() }
        let earlier = RemovalReport(outcomes: [
            RemovalOutcome(item: categorized("예전.bin", .devCache), failureReason: nil),
        ])
        history.record(earlier, at: Date(timeIntervalSince1970: 1_000))

        // 앱을 다시 켠 상황
        let app = app(scanning: .smartScan, finds: mixed, history: history)

        #expect(app.cleanupSummary == history.summary)
        #expect(app.cleanupSummary.totalReclaimedBytes == 1_000)
    }

    @Test("전부 실패한 회차는 요약을 바꾸지 않는다")
    func failedRoundLeavesSummaryEmpty() async throws {
        let (history, cleanup) = try isolatedHistory()
        defer { cleanup() }
        let app = app(scanning: .smartScan, finds: mixed, history: history,
                      removeOne: { RemovalOutcome(item: $0, failureReason: "보호된 경로입니다") })
        await app.model(for: .smartScan).scan()

        let junk = app.model(for: .junk)
        let target = try #require(junk.items.first, "정크 탭이 비어 배분이 끊겼다")
        junk.selection = [target.url]
        await junk.removeSelected()

        #expect(app.cleanupSummary == .empty)
        #expect(history.records.isEmpty)
    }

    // TC-8
    @Test("배분해도 배지는 기능별 합 그대로다")
    func sharingDoesNotDoubleCountBadges() async {
        let app = app(scanning: .smartScan, finds: mixed)

        await app.model(for: .smartScan).scan()
        let badges = app.badges

        // 배지는 스마트 스캔 모델만 본다. 배분한 모델까지 합치면 같은 파일을
        // 두 번 세어 총량이 부풀려진다.
        for feature in Feature.summaryCards {
            #expect(badges[feature] == feature.items(from: mixed).formattedTotalSize,
                    "\(feature) 배지가 어긋났다")
        }
        #expect(badges[.smartScan] == mixed.formattedTotalSize)
    }

    // MARK: - 허락이 바뀌어도 보던 자리는 남는다

    /// 진짜 홈과 `.standard`를 건드리지 않는 허락 저장소 하나.
    private func makeGrant() throws
        -> (registry: FolderAccess.Registry, grantable: FolderAccess.Grantable,
            cleanup: () -> Void) {
        let base = URL(filePath: NSTemporaryDirectory())
            .appending(path: "sweep-appmodel-\(UUID().uuidString)")
        let folder = base.appending(path: "Library")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let suite = "sweep-test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        return (FolderAccess.Registry(defaults: defaults),
                .init(folder: folder, label: "~/Library", purpose: "테스트용"),
                {
                    defaults.removePersistentDomain(forName: suite)
                    try? FileManager.default.removeItem(at: base)
                })
    }

    // TC-1
    @Test("폴더를 허락해도 디스크 맵 모델은 그대로다")
    func grantKeepsDiskMapModel() throws {
        let (registry, grantable, cleanup) = try makeGrant()
        defer { cleanup() }
        let app = AppModel(folderAccess: registry, needsFolderAccess: true)
        let before = app.diskMap()

        try app.grantFolderAccess(grantable.folder, as: grantable)

        // 버리면 화면이 "시작 지점을 고르세요"로 되돌아간다 —
        // 디스크 맵 안에서 허락하는 순간 보던 자리가 날아간다는 뜻이다.
        #expect(app.diskMap() === before)
    }

    // TC-2
    @Test("허락하면 화면이 받을 신호가 올라간다")
    func grantRaisesCount() throws {
        let (registry, grantable, cleanup) = try makeGrant()
        defer { cleanup() }
        let app = AppModel(folderAccess: registry, needsFolderAccess: true)
        #expect(app.grantedFolderCount == 0)

        try app.grantFolderAccess(grantable.folder, as: grantable)

        // 화면은 이 값이 바뀌는 것을 보고 제자리에서 다시 읽는다.
        #expect(app.grantedFolderCount == 1)
    }

    // TC-3
    @Test("허락하면 스캔 결과는 여전히 버린다")
    func grantStillForgetsScans() throws {
        let (registry, grantable, cleanup) = try makeGrant()
        defer { cleanup() }
        let app = AppModel(folderAccess: registry, needsFolderAccess: true)
        let before = app.model(for: .junk)

        try app.grantFolderAccess(grantable.folder, as: grantable)

        // 훑을 곳이 달라졌으니 스캔 결과는 낡았다. 디스크 맵과 사정이 다르다.
        #expect(app.model(for: .junk) !== before)
    }

    // TC-4
    @Test("허락을 해제해도 디스크 맵 모델은 그대로다")
    func revokeKeepsDiskMapModel() throws {
        let (registry, grantable, cleanup) = try makeGrant()
        defer { cleanup() }
        let app = AppModel(folderAccess: registry, needsFolderAccess: true)
        try app.grantFolderAccess(grantable.folder, as: grantable)
        let before = app.diskMap()

        app.revokeFolderAccess(grantable)

        #expect(app.diskMap() === before)
    }

    @Test("정리한 것을 되돌리면 누적 용량이 그만큼 줄어든다")
    func undoSubtractsFromSummary() async throws {
        let (history, cleanup) = try isolatedHistory()
        defer { cleanup() }
        let app = AppModel(makeModel: { f in
            ScanModel(scan: f == .smartScan ? self.finishing(self.mixed) : self.finishing([]),
                      removeOne: { RemovalOutcome(item: $0, failureReason: nil,
                                                  trashedURL: URL(filePath: "/Users/x/.Trash/\($0.displayName)")) },
                      restoreOne: { RemovalOutcome(item: $0.item, failure: nil) })
        }, history: history)
        await app.model(for: .smartScan).scan()

        let junk = app.model(for: .junk)
        let target = try #require(junk.items.first)
        junk.selection = [target.url]
        await junk.removeSelected()
        #expect(app.cleanupSummary.totalReclaimedBytes == target.size)

        await junk.undoLastCleanup()

        #expect(app.cleanupSummary.totalReclaimedBytes == 0)
        #expect(history.records.map(\.kind) == [.cleanup, .restore])
    }

    /// 지우면 휴지통 위치를 남기고 되돌리면 성공하는 앱. 스마트 스캔만 결과를 낸다.
    private func undoableApp(history: CleanupHistory) -> AppModel {
        AppModel(makeModel: { f in
            ScanModel(scan: f == .smartScan ? self.finishing(self.mixed) : self.finishing([]),
                      removeOne: { RemovalOutcome(item: $0, failureReason: nil,
                                                  trashedURL: URL(filePath: "/Users/x/.Trash/\($0.displayName)")) },
                      restoreOne: { RemovalOutcome(item: $0.item, failure: nil) })
        }, history: history)
    }

    @Test("스마트 스캔에서 정리한 것을 되돌리면 기능 탭 목록에도 돌아온다")
    func undoInSmartScanReturnsToFeatureTab() async throws {
        let (history, cleanup) = try isolatedHistory()
        defer { cleanup() }
        let app = undoableApp(history: history)
        let smart = app.model(for: .smartScan)
        await smart.scan()

        let junk = app.model(for: .junk)
        let target = try #require(junk.items.first, "정크 탭이 비어 배분이 끊겼다")
        smart.selection = [target.url]
        await smart.removeSelected()
        #expect(!junk.items.contains { $0.url == target.url }, "지운 것이 안 빠져 TC가 공허하다")

        await smart.undoLastCleanup()

        // 파일은 원래 자리에 있는데 탭에서 빠져 있으면 정리 가능한 용량이 틀린다
        #expect(junk.items.filter { $0.url == target.url }.count == 1)
        #expect(!junk.isSelected(target), "되돌린 것이 골라져 있으면 다음 정리에 다시 휩쓸린다")
        // 다른 탭 몫은 끼어들지 않는다
        #expect(!app.model(for: .largeFile).items.contains { $0.url == target.url })
    }

    @Test("기능 탭에서 정리한 것을 되돌리면 스마트 스캔과 배지에도 돌아온다")
    func undoInFeatureTabReturnsToSmartScan() async throws {
        let (history, cleanup) = try isolatedHistory()
        defer { cleanup() }
        let app = undoableApp(history: history)
        let smart = app.model(for: .smartScan)
        await smart.scan()
        let badgesBefore = app.badges

        let junk = app.model(for: .junk)
        let target = try #require(junk.items.first, "정크 탭이 비어 배분이 끊겼다")
        junk.selection = [target.url]
        await junk.removeSelected()
        await junk.undoLastCleanup()

        #expect(smart.items.filter { $0.url == target.url }.count == 1)
        #expect(app.badges == badgesBefore)
    }

    @Test("스마트 스캔이 완료 화면이어도 기능 탭에서 되돌린 항목은 목록과 배지에 돌아온다")
    func undoReachesSmartScanShowingOutcome() async throws {
        let (history, cleanup) = try isolatedHistory()
        defer { cleanup() }
        let app = undoableApp(history: history)
        let smart = app.model(for: .smartScan)
        await smart.scan()

        // 스마트 스캔에서 먼저 하나 정리해 완료 화면을 띄운다
        let first = try #require(smart.items.first, "스마트 스캔이 비어 배분이 끊겼다")
        smart.selection = [first.url]
        await smart.removeSelected()
        #expect(smart.phase == .cleaned)
        let badgesBefore = app.badges

        let junk = app.model(for: .junk)
        let target = try #require(junk.items.first, "정크 탭이 비어 배분이 끊겼다")
        junk.selection = [target.url]
        await junk.removeSelected()
        #expect(!smart.items.contains { $0.url == target.url })

        await junk.undoLastCleanup()

        #expect(smart.items.filter { $0.url == target.url }.count == 1, "완료 화면 탭이 되돌린 항목을 못 받았다")
        #expect(smart.phase == .cleaned, "완료 화면이 덮였다")
        #expect(app.badges == badgesBefore, "배지가 되돌린 용량을 반영하지 않는다")
    }

    @Test("되돌린 항목은 완료 화면을 띄운 탭의 화면을 덮지 않고 자기 몫만 넣는다")
    func undoKeepsOutcomeScreen() async throws {
        let (history, cleanup) = try isolatedHistory()
        defer { cleanup() }
        let app = undoableApp(history: history)
        let smart = app.model(for: .smartScan)
        await smart.scan()

        let junk = app.model(for: .junk)
        let target = try #require(junk.items.first, "정크 탭이 비어 배분이 끊겼다")
        junk.selection = [target.url]
        await junk.removeSelected()
        #expect(smart.phase == .results)

        let big = app.model(for: .largeFile)
        let other = try #require(big.items.first, "큰 파일 탭이 비어 배분이 끊겼다")
        big.selection = [other.url]
        await big.removeSelected()
        #expect(big.phase == .cleaned)

        await junk.undoLastCleanup()

        #expect(big.phase == .cleaned, "완료 화면이 덮였다")
        #expect(big.canUndo)
        #expect(!big.items.contains { $0.url == target.url }, "남의 몫이 끼어들었다")
    }

    // MARK: - 휴지통 비우기는 합계에 넣지 않는다

    @Test("휴지통 항목을 지운 양은 '휴지통으로 옮김' 합계에 더해지지 않는다")
    func emptyingTrashIsNotCounted() async throws {
        let (history, cleanup) = try isolatedHistory()
        defer { cleanup() }
        let found = [
            CleanupItem(url: URL(filePath: "/Users/x/.Trash/a.zip"), size: 2_000, category: .trash, safety: .caution),
            CleanupItem(url: URL(filePath: "/Users/x/.Trash/b.zip"), size: 3_000, category: .trash, safety: .caution),
        ]
        let app = app(scanning: .trash, finds: found, history: history)
        let trash = app.model(for: .trash)
        await trash.scan()
        trash.selection = Set(found.map(\.url))
        await trash.removeSelected()

        #expect(trash.report?.succeeded.count == 2, "지우기 자체는 성공해야 한다")
        #expect(app.cleanupSummary.totalReclaimedBytes == 0)
        #expect(history.records.isEmpty)
    }

    @Test("섞인 회차에서는 휴지통 몫만 빼고 기록한다")
    func mixedReportRecordsOnlyMovedItems() async throws {
        let (history, cleanup) = try isolatedHistory()
        defer { cleanup() }
        let found = [
            CleanupItem(url: URL(filePath: "/Users/x/.Trash/a.zip"), size: 2_000, category: .trash, safety: .caution),
            CleanupItem(url: URL(filePath: "/Users/x/Library/Caches/pip"), size: 500, category: .devCache, safety: .safe),
        ]
        let app = app(scanning: .smartScan, finds: found, history: history)
        let smart = app.model(for: .smartScan)
        await smart.scan()
        smart.selection = Set(found.map(\.url))
        await smart.removeSelected()

        #expect(app.cleanupSummary.totalReclaimedBytes == 500)
    }

    // MARK: - 디스크 사용량

    /// 읽을 때마다 사용 가능 용량이 1000씩 느는 가짜 볼륨.
    private final class GrowingVolume: @unchecked Sendable {
        private let lock = NSLock()
        private var reads = 0
        func read() -> VolumeUsage? {
            lock.lock(); defer { lock.unlock() }
            reads += 1
            return VolumeUsage(total: 100_000, available: Int64(reads) * 1_000)
        }
    }

    private func volumeApp(_ volume: GrowingVolume, history: CleanupHistory) -> AppModel {
        AppModel(makeModel: { f in
            ScanModel(scan: f == .smartScan ? self.finishing(self.mixed) : self.finishing([]),
                      removeOne: { RemovalOutcome(item: $0, failureReason: nil,
                                                  trashedURL: URL(filePath: "/Users/x/.Trash/\($0.displayName)")) },
                      restoreOne: { RemovalOutcome(item: $0.item, failure: nil) })
        }, history: history, readVolumeUsage: { volume.read() })
    }

    @Test("디스크 사용량은 처음 한 번 읽어 둔다")
    func readsVolumeUsageOnce() throws {
        let (history, cleanup) = try isolatedHistory()
        defer { cleanup() }
        let app = volumeApp(GrowingVolume(), history: history)
        #expect(app.volumeUsage?.available == 1_000)
        // 다시 묻지 않으면 그대로다 — 화면이 그릴 때마다 볼륨을 조회하지 않는다
        #expect(app.volumeUsage?.available == 1_000)
    }

    @Test("지우거나 되돌리면 디스크 사용량을 바로 다시 읽는다")
    func refreshesVolumeUsageAfterRemovalAndRestore() async throws {
        let (history, cleanup) = try isolatedHistory()
        defer { cleanup() }
        let app = volumeApp(GrowingVolume(), history: history)
        await app.model(for: .smartScan).scan()
        // 스캔만으로는 다시 읽지 않는다
        #expect(app.volumeUsage?.available == 1_000)

        let junk = app.model(for: .junk)
        let target = try #require(junk.items.first)
        junk.selection = [target.url]
        await junk.removeSelected()
        let afterRemoval = try #require(app.volumeUsage?.available)
        #expect(afterRemoval > 1_000)

        await junk.undoLastCleanup()
        #expect(try #require(app.volumeUsage?.available) > afterRemoval)
    }

    @Test("디스크를 읽지 못하면 nil이다 — 0을 지어내지 않는다")
    func unreadableVolumeIsNil() throws {
        let (history, cleanup) = try isolatedHistory()
        defer { cleanup() }
        let app = AppModel(history: history, readVolumeUsage: { nil })
        #expect(app.volumeUsage == nil)
        app.refreshVolumeUsage()
        #expect(app.volumeUsage == nil)
    }
}
