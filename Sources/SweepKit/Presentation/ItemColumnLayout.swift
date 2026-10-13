import Foundation

/// 결과 목록에서 폭이 정해진 열들. 이름 열은 남는 폭을 채우므로 여기에 없다.
///
/// 폭이 고정이던 때는 영어 설명·날짜가 잘려도 볼 방법이 없었다.
/// 열 머리 경계를 끌어 폭을 바꾸고, 바꾼 폭은 `rawValue`로 저장한다.
public struct ItemColumnLayout: Equatable, Sendable, RawRepresentable {

    public enum Column: Int, CaseIterable, Sendable {
        case detail, dates, size, safety
    }

    public static let defaults: [Double] = [200, 150, 80, 80]
    /// 안전도는 위험 칩(76pt)이 들어가야 한다.
    public static let minimums: [Double] = [80, 70, 60, 80]
    public static let nameMinimum: Double = 120

    public private(set) var widths: [Double] = defaults

    public init() {}

    public func width(_ column: Column) -> Double { widths[column.rawValue] }

    /// `column`의 **왼쪽 경계**를 `delta`만큼 끈다(오른쪽이 +). 경계 양옆 두 열이 폭을 주고받는다.
    ///
    /// 왼쪽 이웃이 이름 열이면 이 열만 늘고 준다 — 이름 열은 남는 폭이라 따라서 바뀐다.
    /// 다만 이름 열이 `nameMinimum` 아래로 내려가도록 내주지는 않는다.
    public mutating func dragLeadingEdge(of column: Column, by delta: Double,
                                         visible: [Column], nameWidth: Double) {
        guard let index = visible.firstIndex(of: column) else { return }
        let me = column.rawValue
        if index == 0 {
            // 경계를 왼쪽으로(-) 끌면 이 열이 넓어진다.
            let grown = min(-delta, max(0, nameWidth - Self.nameMinimum))
            widths[me] = max(Self.minimums[me], widths[me] + grown)
        } else {
            let left = visible[index - 1].rawValue
            // 두 열 모두 최소 폭을 지키는 범위로 자른다.
            let d = min(max(delta, Self.minimums[left] - widths[left]),
                        widths[me] - Self.minimums[me])
            widths[left] += d
            widths[me] -= d
        }
    }

    /// "200,150,80,80". 숫자 네 개가 아니면 버린다 — 열이 바뀐 옛 저장값일 수 있다.
    public init?(rawValue: String) {
        let values = rawValue.split(separator: ",").compactMap { Double($0) }
        guard values.count == Self.defaults.count,
              rawValue.split(separator: ",").count == values.count
        else { return nil }
        widths = zip(values, Self.minimums).map { max($0, $1) }
    }

    public var rawValue: String {
        widths.map { String(Int($0.rounded())) }.joined(separator: ",")
    }
}
