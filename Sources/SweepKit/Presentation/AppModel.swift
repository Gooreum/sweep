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

    /// 기능 모델을 만드는 방법을 주입할 수 있게 열어 둔다.
    ///
    /// `ScanModel(scan:removeOne:)`과 같은 이유다 — 기본 구성은 실제 스캐너를
    /// 물고 있어 테스트에서 43초를 기다리게 된다. **테스트 전용 전역 상태를
    /// 두지 않는다**: 이 프로젝트에서 그런 훅(`additionalRootsForTesting`)이
    /// 병렬 스위트끼리 서로를 덮어써 한 번 제거된 적이 있다.
    public init(makeModel: @escaping @MainActor (Feature) -> ScanModel
                    = { ScanModel(feature: $0) },
                makeDiskMap: @escaping @MainActor () -> DiskMapModel
                    = { DiskMapModel() }) {
        self.makeModel = makeModel
        self.makeDiskMap = makeDiskMap
    }

    /// 기능마다 모델을 하나씩만 만들어 재사용한다.
    ///
    /// 호출할 때마다 새로 만들면 사이드바를 옮겼다 돌아올 때 스캔 결과가 사라진다.
    /// 43초를 다시 기다리게 하는 셈이다.
    public func model(for feature: Feature) -> ScanModel {
        if let existing = models[feature] { return existing }
        let created = makeModel(feature)
        models[feature] = created
        return created
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
        selected.isScannable ? model(for: selected) : nil
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
