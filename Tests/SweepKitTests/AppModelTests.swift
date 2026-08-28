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
}
