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
}
