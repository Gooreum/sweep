import Foundation

/// 진행 상태를 사람이 읽는 형태로 바꾸는 계산들.
///
/// 뷰 안에 두면 테스트할 수 없다. 경계값이 틀리면 화면에서만 티가 나는데,
/// 화면은 자동으로 확인할 방법이 없어 조용히 지나간다.
public enum ProgressDisplay {

    /// "45초" / "1분 20초".
    ///
    /// 1분을 넘겨도 초만 보여주면 "125초 남음"처럼 읽기 나빠진다.
    /// 음수가 들어오면 0으로 본다 — 남은 시간이 음수일 수는 없다.
    public static func readable(seconds: Int) -> String {
        let clamped = max(0, seconds)
        return clamped < 60
            ? "\(clamped)초"
            : "\(clamped / 60)분 \(clamped % 60)초"
    }

    /// 링 게이지가 그릴 호의 끝점. 0~1.
    ///
    /// 자르지 않으면 100을 넘는 값에서 링이 두 바퀴를 돌아 겹쳐 그려지고,
    /// 음수에서는 `trim(from:to:)`가 아무것도 그리지 않는다.
    public static func ringFraction(percent: Int) -> Double {
        min(1, max(0, Double(percent) / 100))
    }
}
