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

    public init() {}

    /// 기능마다 모델을 하나씩만 만들어 재사용한다.
    ///
    /// 호출할 때마다 새로 만들면 사이드바를 옮겼다 돌아올 때 스캔 결과가 사라진다.
    /// 43초를 다시 기다리게 하는 셈이다.
    public func model(for feature: Feature) -> ScanModel {
        if let existing = models[feature] { return existing }
        let created = ScanModel(feature: feature)
        models[feature] = created
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
}
