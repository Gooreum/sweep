import Foundation

/// 정리 후보를 찾아내는 하나의 스캔 전략.
///
/// 이름이 `Scanner`가 아닌 이유는 `Foundation.Scanner`(구 NSScanner)와 충돌하기 때문이다.
/// `import Foundation`과 함께 쓰면 타입 이름이 모호해져 컴파일되지 않는다.
public protocol CleanupScanner: Sendable {
    var category: ScanCategory { get }

    /// 후보 목록. 실패해도 던지지 않고 빈 배열을 돌려준다 —
    /// 스캐너 하나가 죽어도 나머지 결과는 사용자에게 보여줘야 한다.
    func scan() async -> [CleanupItem]

    /// 전체 스캔 시간에서 이 스캐너가 차지하는 몫. 실측 초 단위 기준의 상대값이다.
    ///
    /// 개수로 진행률을 세면 안 된다. 실측에서 `RunawayTempScanner` 하나가
    /// 전체 시간의 94%를 썼다 — 6개 중 5개가 끝나도 작업은 6%만 끝난 것이다.
    var progressWeight: Double { get }

    /// 진행률(0~1)을 보고하며 스캔한다.
    ///
    /// 오래 걸리는 스캐너는 이걸 직접 구현해 중간 진행을 알려야 한다.
    /// 그렇지 않으면 그 스캐너가 도는 동안 진행률이 멈춰 보인다.
    func scan(onProgress: @escaping @Sendable (Double) -> Void) async -> [CleanupItem]
}

extension CleanupScanner {
    /// 1초 안에 끝나는 스캐너들의 기본값. 실측 기준 대부분이 여기 해당한다.
    public var progressWeight: Double { 1 }

    /// 기본 구현은 중간 보고 없이 끝에 한 번만 알린다.
    /// 짧게 끝나는 스캐너는 이것으로 충분하다.
    public func scan(onProgress: @escaping @Sendable (Double) -> Void) async -> [CleanupItem] {
        let items = await scan()
        onProgress(1)
        return items
    }
}

extension CleanupScanner {
    /// 디렉토리 바로 아래 항목들. 없는 경로면 빈 배열이다.
    public func children(of url: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
    }
}
