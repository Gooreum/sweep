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
}

extension CleanupScanner {
    /// 디렉토리 바로 아래 항목들. 없는 경로면 빈 배열이다.
    public func children(of url: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
    }
}
