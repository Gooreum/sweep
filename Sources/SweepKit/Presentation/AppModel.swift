import Foundation
import Observation

/// 어느 기능을 보고 있는지와 기능별 스캔 상태를 들고 있는다.
///
/// SwiftUI를 import하지 않는다. 뷰 없이 탭 전환과 모델 재사용을 검증할 수 있어야 한다.
@MainActor
@Observable
public final class AppModel {

    /// 앱을 열면 스마트 스캔부터 본다 — Cleaner One과 같은 첫 화면.
    public var selected: Feature = .smartScan

    private var models: [Feature: ScanModel] = [:]
    private let makeModel: @MainActor (Feature) -> ScanModel

    private var diskMapModel: DiskMapModel?
    private let makeDiskMap: @MainActor () -> DiskMapModel

    private var cpuModel: CPUModel?
    private let makeCPU: @MainActor () -> CPUModel

    /// 샌드박스에서 정크 파일은 폴더를 하나라도 열어 줘야 동작한다.
    /// 허락하면 false가 되고, 정크 탭이 허락 화면에서 검색 화면으로 바뀐다.
    ///
    /// 허락 상태 자체는 `FolderAccess`가 들고 있다. 그건 관찰되지 않는 저장소라
    /// 화면이 바뀌려면 여기 관찰되는 값이 하나 있어야 한다.
    public private(set) var needsFolderAccess: Bool

    /// 허락한 폴더 수. 화면이 "보는 곳" 목록을 다시 읽을 시점을 아는 데 쓴다.
    ///
    /// `needsFolderAccess`로는 부족하다 — 그건 첫 허락에 한 번 false가 되고 끝이라,
    /// 두 번째·세 번째 허락을 화면이 알아챌 수 없다.
    public private(set) var grantedFolderCount: Int = 0
    private let folderAccess: FolderAccess.Registry

    /// 사용자가 스마트 스캔에 추가한 폴더 수. "보는 곳" 카드가 다시 읽을 시점이다 —
    /// `grantedFolderCount`는 샌드박스 밖에서 늘 0이라 이걸 따로 둔다.
    public private(set) var scanFolderCount: Int = 0
    private let userFolders: UserFolders.Registry

    /// 등록한 프로젝트 폴더 수. 개발 프로젝트 화면이 빈 상태와 목록을 가르는 데 쓴다.
    public private(set) var projectFolderCount: Int = 0
    private let projectFolders: ProjectFolders.Registry

    /// 이 앱이 폴더 허락을 요구하는 환경인가(= 샌드박스인가).
    ///
    /// 허락을 거둘 때 다시 물어야 하므로 판정을 기억해 둔다. 그때마다
    /// `Sandbox.isActive`를 다시 읽으면 주입으로 샌드박스를 흉내 낸 테스트가
    /// 거둔 직후 "허락이 필요 없다"고 답한다.
    private let requiresFolderAccess: Bool

    /// 전체 디스크 접근. 시스템 설정에서 켜고 돌아오면 `refreshPermissions()`로 다시 잰다.
    ///
    /// 판정(`FullDiskAccess`)은 관찰되지 않는 값이라, 화면이 따라오려면 여기 하나 있어야 한다.
    public private(set) var hasFullDiskAccess: Bool
    private let fullDiskAccessProbe: @MainActor () -> Bool

    /// 지금까지 얼마를 비웠고 마지막이 언제였는지.
    ///
    /// 저장소(`CleanupHistory`)는 관찰되지 않으므로 화면이 따라오려면
    /// 여기 관찰되는 값이 하나 있어야 한다 — `needsFolderAccess`와 같은 이유다.
    public private(set) var cleanupSummary: CleanupSummary

    /// 홈 볼륨의 사용량. 화면 셋(사이드바·스마트 스캔·메뉴바)이 이것 하나를 본다.
    ///
    /// 예전엔 화면마다 만들어질 때 한 번 읽어 두어, 휴지통을 비워도 숫자가 그대로였다.
    /// 정리·되돌리기 직후 다시 읽는다 — 파일을 다시 훑는 게 아니라 볼륨에 한 번 묻는 것이다.
    public private(set) var volumeUsage: VolumeUsage?

    /// 테스트가 갈아끼운다 — 진짜 디스크 용량은 테스트에서 바꿀 수 없다.
    private let readVolumeUsage: @Sendable () -> VolumeUsage?
    private let history: CleanupHistory

    /// 기능 모델을 만드는 방법을 주입할 수 있게 열어 둔다.
    ///
    /// `ScanModel(scan:removeOne:)`과 같은 이유다 — 기본 구성은 실제 스캐너를
    /// 물고 있어 테스트에서 43초를 기다리게 된다. **테스트 전용 전역 상태를
    /// 두지 않는다**: 이 프로젝트에서 그런 훅(`additionalRootsForTesting`)이
    /// 병렬 스위트끼리 서로를 덮어써 한 번 제거된 적이 있다.
    /// 허락 저장소도 같은 이유로 주입한다 — 테스트가 `.shared`를 건드리지 않게.
    /// 정리 기록 저장소도 마찬가지다 — 테스트의 가짜 삭제가 실제 기록에 쌓이면 안 된다.
    public init(makeModel: @escaping @MainActor (Feature) -> ScanModel
                    = { ScanModel(feature: $0) },
                makeDiskMap: @escaping @MainActor () -> DiskMapModel
                    = { DiskMapModel() },
                makeCPU: @escaping @MainActor () -> CPUModel
                    = { CPUModel() },
                folderAccess: FolderAccess.Registry = FolderAccess.shared,
                userFolders: UserFolders.Registry = UserFolders.shared,
                projectFolders: ProjectFolders.Registry = ProjectFolders.shared,
                history: CleanupHistory = .shared,
                needsFolderAccess: Bool? = nil,
                fullDiskAccess: @escaping @MainActor () -> Bool = { !FullDiskAccess.isMissing() },
                readVolumeUsage: @escaping @Sendable () -> VolumeUsage? = { VolumeUsage.current() }) {
        self.makeModel = makeModel
        self.makeDiskMap = makeDiskMap
        self.makeCPU = makeCPU
        self.folderAccess = folderAccess
        self.userFolders = userFolders
        self.projectFolders = projectFolders
        self.history = history
        self.cleanupSummary = history.summary
        self.readVolumeUsage = readVolumeUsage
        self.volumeUsage = readVolumeUsage()
        // 주입값이 있으면 그것이 "허락을 요구하는 환경인가"를 대신한다 — 테스트·데모용.
        self.requiresFolderAccess = needsFolderAccess ?? Sandbox.isActive
        self.needsFolderAccess = self.requiresFolderAccess && !folderAccess.hasAny
        self.grantedFolderCount = folderAccess.urls.count
        self.scanFolderCount = userFolders.custom.count
        self.projectFolderCount = projectFolders.custom.count
        self.fullDiskAccessProbe = fullDiskAccess
        self.hasFullDiskAccess = fullDiskAccess()
    }

    /// 앱이 다시 앞으로 올 때 부른다. 바뀌었을 때만 결과를 버린다 — 전체 디스크 접근이 없어
    /// 빈 결과로 끝난 휴지통을 켠 뒤에 다시 찾게.
    public func refreshPermissions() {
        let now = fullDiskAccessProbe()
        guard now != hasFullDiskAccess else { return }
        hasFullDiskAccess = now
        forgetScans()
    }

    /// 전체 디스크 접근을 지금 잴 수 있는가. 샌드박스에서 홈이나 ~/Library를 허락하기 전에는 못 잰다.
    /// 권한 탭이 "확인 불가"와 "꺼짐"을 가르는 데 쓴다.
    public var canMeasureFullDiskAccess: Bool {
        _ = grantedFolderCount
        return FullDiskAccess.isMeasurable(sandboxed: requiresFolderAccess, granted: folderAccess.urls)
    }

    /// 이 화면을 쓰려면 켜야 하는 것. 화면 위 안내 줄이 읽는다.
    public func permissionNeeds(for feature: Feature) -> [PermissionNeed] {
        // 허락이 바뀌면 이 값이 바뀐다. 읽어 둬야 안내 줄이 허락 뒤에 사라진다.
        _ = grantedFolderCount
        return feature.permissionNeeds(sandboxed: requiresFolderAccess, granted: folderAccess.urls,
                                       fullDiskAccess: hasFullDiskAccess)
    }

    /// 등록한 프로젝트 폴더. 「보는 폴더」 줄이 읽는다.
    public var projectFolderURLs: [URL] { projectFolders.custom }

    /// 등록한 프로젝트 폴더를 지금 읽을 수 있는가. 샌드박스에서 북마크를 되살리지 못했으면 false다.
    /// 화면이 `Sandbox.isActive`를 직접 보지 않고 이것을 본다 — 주입한 모델(데모·테스트)과 어긋나지 않게.
    public func isProjectFolderReachable(_ url: URL) -> Bool {
        !requiresFolderAccess || folderAccess.isGranted(ProjectFolders.grantable(for: url))
    }

    /// 개발 프로젝트를 찾을 폴더를 등록한다. 안 되는 폴더면 이유를 던지고 상태는 그대로다.
    ///
    /// `addScanFolder`와 같은 순서다 — 검증·저장 뒤 샌드박스면 북마크를 저장하고,
    /// 실패하면 목록에서도 뺀다.
    public func addProjectFolder(_ url: URL) throws(UserFolders.Rejection) {
        try projectFolders.add(url)
        if requiresFolderAccess {
            do {
                try folderAccess.grant(url, as: ProjectFolders.grantable(for: url))
            } catch {
                projectFolders.remove(url)
                throw .bookmark(error.message)
            }
        }
        refreshFolderState()
    }

    /// 등록한 프로젝트 폴더를 뺀다. 샌드박스에서는 그 폴더의 북마크도 거둔다.
    ///
    /// 같은 폴더를 큰 파일 폴더나 고정 허락으로도 열어 두었으면 북마크만 지우고 접근은 둔다 —
    /// 접근까지 닫으면 그쪽 탭이 앱을 다시 켤 때까지 그 폴더를 못 읽는다.
    public func removeProjectFolder(_ url: URL) {
        projectFolders.remove(url)
        if requiresFolderAccess {
            let grantable = ProjectFolders.grantable(for: url)
            if isFolderOpenedElsewhere(url) {
                folderAccess.forgetBookmark(grantable)
            } else {
                folderAccess.revoke(grantable)
            }
        }
        refreshFolderState()
    }

    /// 프로젝트 폴더 말고 다른 곳(큰 파일 폴더·고정 허락)도 같은 폴더를 열어 두었는가.
    private func isFolderOpenedElsewhere(_ url: URL) -> Bool {
        let target = FolderAccess.components(of: url)
        let others = FolderAccess.grantables.map(\.folder) + userFolders.custom
        return others.contains { FolderAccess.components(of: $0) == target }
    }

    /// 큰 파일·중복 파일을 찾을 폴더를 더한다. 안 되는 폴더면 이유를 던지고 상태는 그대로다.
    ///
    /// 샌드박스에서는 열기 대화상자로 고른 그 폴더의 북마크도 함께 저장한다 —
    /// 목록에만 넣으면 다음 실행에서 읽지 못한다. 저장에 실패하면 목록에서도 뺀다.
    public func addScanFolder(_ url: URL) throws(UserFolders.Rejection) {
        let current = UserFolders.roots(custom: [], sandboxed: requiresFolderAccess,
                                        granted: folderAccess.urls)
        try userFolders.add(url, existing: current)
        if requiresFolderAccess {
            do {
                try folderAccess.grant(url, as: UserFolders.grantable(for: url))
            } catch {
                userFolders.remove(url)
                throw .bookmark(error.message)
            }
        }
        refreshFolderState()
    }

    /// 추가했던 폴더를 뺀다. 샌드박스에서는 그 폴더의 북마크도 거둔다.
    public func removeScanFolder(_ url: URL) {
        userFolders.remove(url)
        if requiresFolderAccess {
            folderAccess.revoke(UserFolders.grantable(for: url))
        }
        refreshFolderState()
    }

    private func refreshFolderState() {
        grantedFolderCount = folderAccess.urls.count
        scanFolderCount = userFolders.custom.count
        projectFolderCount = projectFolders.custom.count
        needsFolderAccess = requiresFolderAccess && !folderAccess.hasAny
        forgetScans()
    }

    /// 열기 대화상자에서 고른 폴더로 허락을 받는다. 틀린 폴더면 던지고 상태는 그대로다.
    public func grantFolderAccess(_ picked: URL,
                                  as grantable: FolderAccess.Grantable)
        throws(FolderAccess.Failure) {
        try folderAccess.grant(picked, as: grantable)
        needsFolderAccess = false
        grantedFolderCount = folderAccess.urls.count
        // 홈을 허락하는 순간 샌드박스에서도 전체 디스크 접근을 잴 수 있게 된다.
        hasFullDiskAccess = fullDiskAccessProbe()
        forgetScans()
    }

    /// 허락을 거둔다. 화면이 즉시 따라오도록 관찰 값도 함께 되돌린다.
    ///
    /// 마지막 하나를 거두면 허락 화면으로 돌아간다 — 훑을 곳이 없는 상태이므로
    /// 검색 버튼을 두면 늘 "정리할 항목 없음"만 나온다.
    public func revokeFolderAccess(_ grantable: FolderAccess.Grantable) {
        folderAccess.revoke(grantable)
        grantedFolderCount = folderAccess.urls.count
        needsFolderAccess = requiresFolderAccess && !folderAccess.hasAny
        hasFullDiskAccess = fullDiskAccessProbe()
        forgetScans()
    }

    /// 허락이 바뀌면 훑을 곳이 달라진다. 낡은 결과를 남겨 두면
    /// 사용자 눈에는 "허락했는데 그대로"로 보인다 — 실제로 그렇게 보였다.
    ///
    /// **디스크 맵 모델은 버리지 않는다.** 버리면 `ContentView`가 새 모델을 만들어
    /// 화면이 "시작 지점을 고르세요"로 되돌아간다 — 디스크 맵 안에서 막힌 폴더를
    /// 허락하는 순간 보던 자리가 통째로 날아간다는 뜻이다. 허락은 읽을 수 있는
    /// 범위를 **넓히기만** 하므로, 같은 모델에게 다시 읽으라고 하면 된다.
    /// 그 신호가 `grantedFolderCount`이고 화면이 받아 `reload()`를 부른다.
    private func forgetScans() {
        models.removeAll()
    }

    /// 이 폴더가 이미 열려 있는가. 허락 화면이 체크 표시를 그린다.
    public func isGranted(_ grantable: FolderAccess.Grantable) -> Bool {
        // 허락이 바뀌면 이 값이 바뀐다. 읽어 둬야 이걸 부른 뷰가 다시 그려진다 —
        // 레지스트리는 관찰 대상이 아니라서 그것만 읽으면 배너가 허락 뒤에도 남는다.
        _ = grantedFolderCount
        return folderAccess.isGranted(grantable)
    }

    /// 기능마다 모델을 하나씩만 만들어 재사용한다.
    ///
    /// 호출할 때마다 새로 만들면 사이드바를 옮겼다 돌아올 때 스캔 결과가 사라진다.
    /// 43초를 다시 기다리게 하는 셈이다.
    public func model(for feature: Feature) -> ScanModel {
        if let existing = models[feature] { return existing }
        let created = makeModel(feature)
        wire(created, as: feature)
        models[feature] = created
        return created
    }

    // MARK: - 화면끼리 결과 나누기

    /// 모델 하나를 나머지 모델과 이어 준다.
    ///
    /// 화면마다 모델이 따로인 것은 기능별로 따로 훑기 위해서지, 서로 모르는
    /// 척하기 위해서가 아니다. 같은 파일을 두 화면이 들고 있으면 한쪽에서
    /// 일어난 일이 다른 쪽에도 보여야 한다.
    private func wire(_ model: ScanModel, as feature: Feature) {
        model.onScanFinished = { [weak self] items in
            self?.share(items, from: feature)
        }
        model.onRemoved = { [weak self] urls in
            self?.forget(urls, except: feature)
            self?.refreshVolumeUsageAfterChange()
        }
        model.onReport = { [weak self] report in
            self?.record(report)
        }
        model.onRestored = { [weak self] report in
            self?.recordRestore(report)
            self?.refreshVolumeUsageAfterChange()
        }
        model.onRestoredItems = { [weak self] items in
            self?.reinstate(items, except: feature)
        }
    }

    /// 디스크 사용량을 지금 값으로 다시 읽는다. 메뉴바 패널이 열릴 때도 부른다.
    public func refreshVolumeUsage() {
        volumeUsage = readVolumeUsage()
    }

    /// 지운 직후 한 번, 잠시 뒤 한 번 더. APFS는 돌려받은 공간을 몇 초 늦게 반영하기도 한다.
    private func refreshVolumeUsageAfterChange() {
        refreshVolumeUsage()
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            self?.refreshVolumeUsage()
        }
    }

    /// 되돌린 만큼 누적 용량에서 뺀다.
    private func recordRestore(_ report: RemovalReport) {
        history.recordRestore(report)
        cleanupSummary = history.summary
    }

    /// 회차 결과를 기록하고 관찰 값을 갱신한다.
    ///
    /// 어느 기능 모델에서 지웠든 한 곳에 쌓인다. 모델 안에 두면 폴더 허락이
    /// 바뀔 때 `forgetScans()`가 모델과 함께 기록도 버린다.
    ///
    /// 휴지통 비우기는 기록하지 않는다. 합계 문구가 "휴지통으로 옮김"이라 이미 휴지통에 있던 것을
    /// 지운 양을 더하면 거짓말이 되고, 되돌릴 수도 없다. 남는 성공분이 없으면 기록이 건너뛴다.
    private func record(_ report: RemovalReport) {
        history.record(RemovalReport(outcomes: report.outcomes.filter {
            !$0.item.category.removesPermanently
        }))
        cleanupSummary = history.summary
    }

    /// 스마트 스캔 결과를 기능 탭에 나눠 준다.
    ///
    /// `badges`는 이미 이 결과로 그린다 — 사이드바에 "정크 파일 6.9 GB"라고
    /// 써 놓고 그 탭에 들어가면 빈 시작 화면이 뜨는 것이 고치기 전 상태였다.
    /// 데이터를 손에 쥐고 있으면서 없는 척한 셈이다.
    ///
    /// **스마트 스캔만 나눠 준다.** 기능 탭은 자기 몫만 훑으므로, 그 결과를
    /// 전체로 퍼뜨리면 다른 탭이 "훑어봤는데 없다"는 거짓말을 하게 된다.
    private func share(_ items: [CleanupItem], from feature: Feature) {
        guard feature == .smartScan else { return }

        for target in Feature.summaryCards {
            let model = self.model(for: target)
            // 그 탭이 자기 스캔을 도는 중이거나, 정리 결과를 띄워 되돌리기를
            // 기다리는 중이면 덮지 않는다
            guard !model.isBusy, !model.isShowingOutcome else { continue }
            model.adopt(target.items(from: items))
        }
    }

    /// 한 화면에서 지운 파일을 나머지 화면의 목록에서도 뺀다.
    ///
    /// 나눠 준 뒤에는 같은 파일을 여러 화면이 들고 있다. 한쪽에서 지웠는데
    /// 다른 쪽에 남아 있으면 목록도 사이드바 배지도 거짓말이 된다.
    private func forget(_ urls: [URL], except owner: Feature) {
        for (feature, model) in models where feature != owner {
            model.forget(urls)
        }
    }

    /// 한 화면에서 되돌린 파일을 나머지 화면의 목록에도 돌려준다. `forget`의 짝이다.
    ///
    /// 각 탭에는 `share`와 같은 기준으로 자기 몫만 넣는다.
    private func reinstate(_ items: [CleanupItem], except owner: Feature) {
        for (feature, model) in models where feature != owner {
            model.reinstate(feature.items(from: items))
        }
    }

    /// 디스크 맵 모델. `model(for:)`과 **같은 이유로** 여기서 소유한다.
    ///
    /// 뷰가 `@State`로 들고 있으면 사이드바를 옮기는 순간 죽고, 돌아올 때
    /// 10초짜리 순회를 다시 돈다. 스캔 모델이 아니라고 규칙이 달라지지 않는다.
    public func diskMap() -> DiskMapModel {
        if let existing = diskMapModel { return existing }
        let created = makeDiskMap()
        diskMapModel = created
        return created
    }

    /// CPU 모델. 디스크 맵과 **같은 이유로** 여기서 소유한다.
    ///
    /// 저쪽이 10초짜리 순회라면 이쪽은 2초짜리 준비다. 뷰가 들고 있으면
    /// 탭을 옮겼다 돌아올 때마다 "측정 중…"을 다시 본다.
    public func cpu() -> CPUModel {
        if let existing = cpuModel { return existing }
        let created = makeCPU()
        cpuModel = created
        return created
    }

    // MARK: - 메뉴가 물어보는 것

    /// 지금 보고 있는 기능의 모델. 디스크 맵·CPU는 스캔하지 않으므로 nil이다.
    public var currentModel: ScanModel? {
        // 허락 여부를 먼저 읽는다. 스캐너 목록은 관찰되지 않는 저장소를 봐서,
        // 이 값을 읽지 않으면 허락한 뒤에도 메뉴(⌘R)가 잠긴 채로 남는다 — 실측.
        if selected == .junk && needsFolderAccess { return nil }
        return selected.isScannable ? model(for: selected) : nil
    }

    /// 검색을 시작할 수 있는가. 이미 도는 중이면 안 된다.
    public var canScan: Bool {
        guard let model = currentModel else { return false }
        return !model.isBusy
    }

    /// 정리할 수 있는가. 고른 것이 있어야 한다.
    public var canClean: Bool {
        guard let model = currentModel else { return false }
        return !model.isBusy && model.hasSelection
    }

    /// 사이드바 배지 전체. 아직 훑지 않았거나 0이면 그 기능은 빠진다 —
    /// "0바이트" 배지는 알려줄 것이 아니라 자리만 차지한다.
    ///
    /// 행마다 따로 물으면 같은 항목 목록을 기능 수만큼 훑는다.
    /// 카테고리 → 기능 대응표를 먼저 만들고 항목을 **한 번만** 지나간다.
    public var badges: [Feature: String] {
        let items = model(for: .smartScan).items
        guard !items.isEmpty else { return [:] }

        var owner: [ScanCategory: Feature] = [:]
        for feature in Feature.summaryCards {
            for category in feature.categories { owner[category] = feature }
        }

        var bytes: [Feature: Int64] = [:]
        for item in items {
            if let feature = owner[item.category] { bytes[feature, default: 0] += item.size }
            // 스마트 스캔은 전체를 대표한다. 담당 기능이 없는 카테고리가 생겨도
            // 전체 합에서는 빠지지 않는다.
            bytes[.smartScan, default: 0] += item.size
        }

        return bytes.mapValues { Self.compactSize($0) }
    }

    /// 사이드바 배지용 짧은 용량. 좁은 칸이라 "26.88 GB"를 "26.9 GB"로 줄인다.
    ///
    /// `ByteCountFormatter`가 말한 것을 기준으로 하고, 숫자가 10 이상일 때만 소수 자리를 줄인다
    /// (10 이상이면 소수 첫째 자리, 100 이상이면 정수). 그 아래와 "512 bytes"·"Zero KB"는
    /// 포맷터의 말 그대로 둔다 — 다른 화면과 같은 말이어야 한다.
    nonisolated static func compactSize(_ bytes: Int64) -> String {
        compact(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
    }

    /// 포맷터가 말한 글자("26.88 GB", 한국어는 "26.88GB")에서 숫자 부분만 줄인다.
    /// 숫자와 단위 사이의 공백은 언어마다 달라서, 글자(단위)가 시작하는 곳을 기준으로 나눈다.
    nonisolated static func compact(_ full: String) -> String {
        guard let unitStart = full.firstIndex(where: \.isLetter) else { return full }
        let numberPart = String(full[..<unitStart])
        let numberText = numberPart.trimmingCharacters(in: .whitespaces)
        let separator = numberPart.dropFirst(numberText.count)   // 숫자 뒤의 공백(있으면)
        let unit = String(full[unitStart...])

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        guard let value = formatter.number(from: numberText)?.doubleValue, value >= 10 else { return full }
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = value >= 100 ? 0 : 1
        guard let short = formatter.string(from: NSNumber(value: value)) else { return full }
        return "\(short)\(separator)\(unit)"
    }

    // MARK: - 상태 아이콘이 물어보는 것

    /// 메뉴 막대 패널이 보여줄 요약.
    ///
    /// **스마트 스캔 모델 하나만 본다.** 기능별 모델을 합치면 같은 파일이
    /// 여러 번 세어져 총량이 부풀려진다 — 지금 구성에서는 겹치지 않지만
    /// 합산은 그 전제에 기대는 계산이라 스캐너가 바뀌면 조용히 틀린다.
    public var menuBarSummary: MenuBarSummary {
        model(for: .smartScan).summary
    }
}

/// 메뉴 막대 패널 한 장에 들어갈 값들.
///
/// 뷰가 아니라 여기서 만든다 — 숫자가 맞는지 뷰 없이 확인할 수 있어야 한다.
@MainActor
public struct MenuBarSummary: Sendable {

    /// 기능 하나의 발견량.
    public struct Row: Identifiable, Sendable {
        public let feature: Feature
        public let bytes: Int64
        public let count: Int

        public var id: Feature { feature }
        public var formattedSize: String {
            ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        }
    }

    /// 회수 가능 총량. 아직 아무것도 못 찾았으면 nil이다.
    ///
    /// **"0바이트"가 아니다.** 스캔한 적이 없는 것과 스캔했는데 0인 것을
    /// 화면에서 구분해야 한다 — `VolumeUsage.current()`에서 한 판단과 같다.
    public let reclaimable: String?
    public let reclaimableBytes: Int64

    /// 기능별 발견량. 0인 기능은 빠진다 — "중복 0개"는 알려줄 것이 아니다.
    public let breakdown: [Row]

    public let isScanning: Bool
    /// 스캔 중일 때만 값이 있다.
    public let scanPercent: Int?

    fileprivate init(model: ScanModel) {
        isScanning = model.isBusy
        if case let .scanning(percent, _) = model.phase {
            scanPercent = percent
        } else {
            scanPercent = nil
        }

        let items = model.items
        reclaimableBytes = items.totalSize
        reclaimable = items.isEmpty ? nil : items.formattedTotalSize

        // 발견량이 큰 것부터. 같은 크기 칸에 나열하면 5.6GB와 104MB가
        // 같은 무게로 읽힌다 — 어디에 용량이 묶여 있는지가 첫 정보다.
        breakdown = Feature.summaryCards.compactMap { feature -> Row? in
            let matched = feature.items(from: items)
            guard !matched.isEmpty else { return nil }
            return Row(feature: feature, bytes: matched.totalSize, count: matched.count)
        }
        .sorted { $0.bytes > $1.bytes }
    }
}


extension ScanModel {
    /// 이 모델 하나가 만들어내는 요약.
    ///
    /// 뷰는 **자기가 받은 모델**에서 요약을 뽑아야 한다. `AppModel`을 거쳐
    /// 다른 모델을 보면 실앱에서는 같은 객체라 안 드러나지만, 모델을 주입해
    /// 그리는 화면(단계 하니스)에서는 빈 결과가 나온다.
    public var summary: MenuBarSummary { MenuBarSummary(model: self) }
}

// MARK: - 상태바

/// 창 아래 상태바 세 칸. 디스크 맵·폴더 허락 화면처럼 스캔 모델이 없는 화면도
/// 지금 하는 일을 같은 자리에 보여준다.
public struct StatusLine: Equatable, Sendable {
    public let status: String
    public let count: String
    public let size: String

    static let empty = "—"

    @MainActor
    static func scan(_ model: ScanModel?) -> StatusLine {
        let status: String
        switch model?.phase {
        case .idle, .none: status = String(localized: "시작 전")
        case let .scanning(percent, _): status = String(localized: "찾는 중… \(percent)%")
        case .results: status = String(localized: "찾기 완료")
        case .removing: status = String(localized: "정리 중…")
        case .cleaned: status = String(localized: "정리 완료")
        case .restoring: status = String(localized: "복구 중…")
        case .restored: status = String(localized: "복구 완료")
        }
        return StatusLine(
            status: status,
            count: model.map { String(localized: "항목 \($0.items.count)개") } ?? empty,
            size: model.flatMap { $0.items.isEmpty ? nil : String(localized: "정리 대상 \($0.formattedTotalSize)") } ?? empty)
    }

    /// CPU 탭은 스캔을 하지 않는다. 스캔 모델 기준으로 그리면 "시작 전"이 떠서
    /// 이미 실시간으로 돌고 있는 화면이 아직 안 켜진 것처럼 보인다.
    @MainActor
    static func cpu(model: CPUModel?) -> StatusLine {
        guard let model, !model.isWarmingUp else {
            return StatusLine(status: String(localized: "측정 중…"), count: empty, size: empty)
        }
        return StatusLine(status: String(localized: "실시간으로 보는 중"),
                          count: String(localized: "프로그램 \(model.usage.count)개"), size: empty)
    }

    static func diskMap(loadPhase: DiskMapModel.LoadPhase?, current: DiskUsageNode?) -> StatusLine {
        let status: String
        switch loadPhase {
        case let .counting(scanned): status = String(localized: "\(scanned.formatted())개 확인 중…")
        case let .measuring(percent): status = String(localized: "크기 확인 중… \(percent)%")
        case .none: status = current == nil ? String(localized: "시작 전") : String(localized: "확인 완료")
        }
        // 재는 중에는 이전 트리 숫자를 보여주지 않는다 — 곧 바뀔 값이다.
        guard loadPhase == nil, let current else {
            return StatusLine(status: status, count: empty, size: empty)
        }
        return StatusLine(status: status,
                          count: String(localized: "항목 \(current.children.count)개"),
                          size: String(localized: "크기 \(current.formattedSize)"))
    }
}

/// 사이드바 줄 오른쪽에 붙는 진행 상태. 검색 중이면 모래시계, 끝났으면 체크.
public enum FeatureStatus: Equatable, Sendable {
    /// 아직 찾지 않았다.
    case idle
    case loading
    /// 찾기(공간 보기는 읽기)가 끝났다.
    case done
}

extension AppModel {
    /// 기능의 진행 상태. 모델을 **만들지 않는다** — 사이드바는 body에서 기능 수만큼 읽는다.
    public func status(of feature: Feature) -> FeatureStatus {
        switch feature {
        case .cpu:
            return .idle
        case .diskMap:
            guard let model = diskMapModel else { return .idle }
            if model.isScanning { return .loading }
            return model.completedAt == nil ? .idle : .done
        default:
            switch models[feature]?.phase {
            case .scanning, .removing, .restoring: return .loading
            case .results, .cleaned, .restored: return .done
            default: return .idle
            }
        }
    }

    public var diskMapStatus: FeatureStatus { status(of: .diskMap) }
}

extension AppModel {
    /// 디스크 맵 모델은 **만들지 않는다.** 상태바는 body에서 읽히므로,
    /// 여기서 만들면 관찰 중인 값을 그리는 도중에 바꾸게 된다.
    public var statusLine: StatusLine {
        switch selected {
        case .diskMap:
            StatusLine.diskMap(loadPhase: diskMapModel?.loadPhase, current: diskMapModel?.current)
        case .junk where needsFolderAccess:
            StatusLine(status: String(localized: "폴더 선택 필요"), count: StatusLine.empty, size: StatusLine.empty)
        case .cpu:
            // CPU 모델도 만들지 않는다 — 화면이 처음 열릴 때 만든다.
            StatusLine.cpu(model: cpuModel)
        default:
            StatusLine.scan(currentModel)
        }
    }
}
