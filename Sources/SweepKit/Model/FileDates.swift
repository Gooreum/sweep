import Foundation

/// 항목의 시간 정보. 만든 날과 마지막으로 쓰인 날.
///
/// **마지막 사용은 하위 "일반 파일"의 최신 수정 시각이다.** 다른 두 후보는 실측에서
/// 탈락했다.
///
/// 하나는 **접근 시각(atime)**이다. 스캐너는 후보 폴더를 전부 `opendir`로 여는데,
/// 그것만으로 디렉토리의 atime이 갱신된다(실측: 22:57:12 → `ls` 한 번 → 22:57:14).
/// 쓰면 **모든 폴더 항목이 "방금 사용"으로 찍힌다** — 우리 스캔이 스스로 답을 망친다.
///
/// 다른 하나는 **디렉토리 자신의 mtime**이다. 하위가 추가·삭제되기만 해도 갱신돼서,
/// 이 프로젝트는 이미 한 번 당했다 — 331일 묵은 캐시가 "오늘 쓴 것"으로 보여
/// 묵은 캐시 검출이 통째로 실패했다. 그래서 `DirectorySize.summary(at:)`는
/// 일반 파일의 mtime만 센다.
public struct FileDates: Sendable, Hashable {
    /// 만든 날. 앱이라면 설치한 날이 된다.
    public let created: Date?
    /// 마지막으로 쓰인 날. 하위 일반 파일 중 가장 최근 수정 시각.
    public let lastUsed: Date?

    public init(created: Date? = nil, lastUsed: Date? = nil) {
        self.created = created
        self.lastUsed = lastUsed
    }

    /// 아직 읽지 못했거나 읽을 수 없는 항목.
    public static let unknown = FileDates()

    /// "2026.05.18 만듦". 모르면 nil — **빈 칸을 지어내지 않는다.**
    ///
    /// 만든 날은 "언제부터 쌓였나"라 상대 표현("1년 전")보다 실제 날짜가 쓸모 있다.
    public func createdLabel(calendar: Calendar = .current) -> String? {
        guard let created else { return nil }
        return Self.dateText(created, calendar: calendar).map { "\($0) 만듦" }
    }

    /// "6개월 전 사용". 모르면 nil.
    ///
    /// 마지막 사용은 반대로 **얼마나 됐나**가 판단 근거라 상대 표현을 쓴다.
    /// 문구 계단은 `LargeFileScanner.detail(modified:now:)`와 맞췄다 —
    /// 한 화면에서 두 가지 말투가 섞이면 같은 뜻인지 헷갈린다.
    public func lastUsedLabel(now: Date = Date()) -> String? {
        guard let lastUsed else { return nil }
        let days = Int(now.timeIntervalSince(lastUsed) / 86_400)
        switch days {
        // 시계가 어긋났거나 스캔 도중에 쓰인 경우다. "-3일 전"이라고 쓰지 않는다.
        case ..<0: return "방금 사용"
        case 0: return "오늘 사용"
        case ..<30: return "\(days)일 전 사용"
        case ..<365: return "\(days / 30)개월 전 사용"
        default: return "\(days / 365)년 전 사용"
        }
    }

    /// 툴팁에 넣을 정확한 값. "만든 날 2026.05.18 · 마지막 사용 2026.05.19"
    ///
    /// 목록에는 짧은 말로 쓰고, 정확한 날짜는 마우스를 올린 사람에게만 준다.
    public func tooltipLine(calendar: Calendar = .current) -> String? {
        let parts = [
            created.flatMap { Self.dateText($0, calendar: calendar) }.map { "만든 날 \($0)" },
            lastUsed.flatMap { Self.dateText($0, calendar: calendar) }
                .map { "마지막 사용 \($0)" },
        ].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// "2026.05.18". `DateFormatter`를 쓰지 않는다 — 로캘에 따라 형식이 흔들리고,
    /// 여기서 필요한 건 어느 나라에서 보든 같은 자릿수의 날짜다.
    private static func dateText(_ date: Date, calendar: Calendar) -> String? {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day
        else { return nil }
        return String(format: "%04d.%02d.%02d", year, month, day)
    }
}
