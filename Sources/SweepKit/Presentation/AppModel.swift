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

    /// ⌘F가 눌린 횟수. 화면이 이 값의 변화를 보고 검색창에 포커스를 준다.
    ///
    /// 메뉴는 뷰가 아니라 `@FocusState`에 손댈 수 없다. 모델을 통해 **신호만** 보내고
    /// 실제로 잡는 것은 화면의 몫이다 — `grantedFolderCount`로 디스크 맵을 다시 읽게 한
    /// 것과 같은 수법이다.
    ///
    /// Bool로 두면 두 번째 ⌘F가 안 먹는다 — 이미 true라 값이 안 바뀐다.
    public private(set) var searchFocusRequest = 0

    /// 검색창에 포커스를 달라고 알린다.
    public func requestSearchFocus() { searchFocusRequest += 1 }
    private let folderAccess: FolderAccess.Registry

    /// 이 앱이 폴더 허락을 요구하는 환경인가(= 샌드박스인가).
    ///
    /// 허락을 거둘 때 다시 물어야 하므로 판정을 기억해 둔다. 그때마다
    /// `Sandbox.isActive`를 다시 읽으면 주입으로 샌드박스를 흉내 낸 테스트가
    /// 거둔 직후 "허락이 필요 없다"고 답한다.
    private let requiresFolderAccess: Bool

    /// 기능 모델을 만드는 방법을 주입할 수 있게 열어 둔다.
    ///
    /// `ScanModel(scan:removeOne:)`과 같은 이유다 — 기본 구성은 실제 스캐너를
    /// 물고 있어 테스트에서 43초를 기다리게 된다. **테스트 전용 전역 상태를
    /// 두지 않는다**: 이 프로젝트에서 그런 훅(`additionalRootsForTesting`)이
    /// 병렬 스위트끼리 서로를 덮어써 한 번 제거된 적이 있다.
    /// 허락 저장소도 같은 이유로 주입한다 — 테스트가 `.shared`를 건드리지 않게.
    public init(makeModel: @escaping @MainActor (Feature) -> ScanModel
                    = { ScanModel(feature: $0) },
                makeDiskMap: @escaping @MainActor () -> DiskMapModel
                    = { DiskMapModel() },
                folderAccess: FolderAccess.Registry = FolderAccess.shared,
                needsFolderAccess: Bool? = nil) {
        self.makeModel = makeModel
        self.makeDiskMap = makeDiskMap
        self.folderAccess = folderAccess
        // 주입값이 있으면 그것이 "허락을 요구하는 환경인가"를 대신한다 — 테스트·데모용.
        self.requiresFolderAccess = needsFolderAccess ?? Sandbox.isActive
        self.needsFolderAccess = self.requiresFolderAccess && !folderAccess.hasAny
        self.grantedFolderCount = folderAccess.urls.count
    }

    /// 열기 대화상자에서 고른 폴더로 허락을 받는다. 틀린 폴더면 던지고 상태는 그대로다.
    public func grantFolderAccess(_ picked: URL,
                                  as grantable: FolderAccess.Grantable)
        throws(FolderAccess.Failure) {
        try folderAccess.grant(picked, as: grantable)
        needsFolderAccess = false
        grantedFolderCount = folderAccess.urls.count
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
        folderAccess.isGranted(grantable)
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
        }
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
            // 그 탭이 자기 스캔을 도는 중이면 덮지 않는다
            guard !model.isBusy else { continue }
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

    // MARK: - 메뉴가 물어보는 것

    /// 지금 보고 있는 기능의 모델. 디스크 맵은 스캔하지 않으므로 nil이다.
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

    /// 지금 화면에 검색창이 떠 있는가. ⌘F를 켜고 끄는 데 쓴다.
    ///
    /// 툴바가 검색창을 그리는 조건과 **같은 식**을 쓴다. 두 벌로 두면
    /// 창이 없는데 ⌘F만 켜져 있는 상태가 생긴다.
    public var canSearchList: Bool {
        // 걸러져 0개가 된 상태에서도 살아 있어야 한다 — 검색어를 지울 길이 막히면 갇힌다.
        if selected == .diskMap {
            let map = diskMap()
            return !map.tiles.isEmpty || map.isFiltered
        }
        guard let model = currentModel else { return false }
        return !model.items.isEmpty
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

        return bytes.mapValues {
            ByteCountFormatter.string(fromByteCount: $0, countStyle: .file)
        }
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
