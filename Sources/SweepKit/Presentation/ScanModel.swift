import Foundation
import Observation

/// 화면에 보여줄 카테고리 섹션 하나.
public struct ScanGroup: Identifiable, Sendable, Hashable {
    /// 이 묶음을 무엇으로 나눴는가.
    ///
    /// 기능 화면은 **판단 기준**으로 나눈다 — `Xcode_26.0.xip`(다시 받으면 된다)와
    /// `제주 여행 원본.mov`(없으면 끝)가 같은 카테고리라고 한 덩어리에 섞이면,
    /// 크기는 비슷한데 판단이 정반대인 것들을 하나씩 열어 봐야 한다.
    ///
    /// 스마트 스캔만 카테고리로 나눈다. 거기서는 기능별로 갈리는 것이 정보다.
    public enum Kind: Sendable, Hashable {
        case category(ScanCategory)
        case safety(SafetyLevel)
    }

    public let kind: Kind
    public let items: [CleanupItem]

    public var id: Kind { kind }
    public var formattedTotalSize: String { items.formattedTotalSize }

    /// 화면에 쓰는 이름.
    public var displayName: String {
        switch kind {
        case .category(let category): category.displayName
        case .safety(let level): level.groupLabel
        }
    }

    /// 예전 API. 카테고리로 나눈 묶음에서만 뜻이 있다.
    public var category: ScanCategory? {
        if case .category(let category) = kind { return category }
        return nil
    }
}

extension SafetyLevel {
    /// 묶음 머리에 쓰는 이름. 등급 이름("안전")이 아니라 **무엇을 뜻하는지**를 적는다.
    public var groupLabel: String {
        switch self {
        case .safe: String(localized: "다시 만들 수 있음")
        case .caution: String(localized: "확인 필요")
        case .danger: String(localized: "되돌릴 수 없음")
        }
    }
}

/// 스캔 → 선택 → 삭제 흐름의 상태를 들고 있는다.
///
/// SwiftUI를 import하지 않는다. 화면 구성과 무관한 순수 상태 관리라
/// 뷰 없이 단위 테스트할 수 있어야 하기 때문이다.
@MainActor
@Observable
public final class ScanModel {

    public enum Phase: Equatable, Sendable {
        case idle
        /// 스캔 중. 개수가 아니라 **실측 시간 가중 진행률**을 담는다.
        /// 스캐너 6개 중 5개가 끝나도 작업은 6%만 끝난 경우가 있다.
        case scanning(percent: Int, remainingSeconds: Int?)
        case results
        case removing(done: Int, total: Int)
        /// 정리가 끝난 직후. 목록이 아니라 "얼마를 비웠다"만 보여준다.
        case cleaned
        /// 방금 정리한 것을 휴지통에서 원래 자리로 되돌리는 중.
        case restoring(done: Int, total: Int)
        /// 되돌리기가 끝난 직후. 무엇을 되돌렸고 무엇을 못 했는지 보여준다.
        case restored
    }

    public private(set) var phase: Phase = .idle
    public private(set) var items: [CleanupItem] = []
    /// 직전 삭제 회차의 결과. 아직 삭제한 적이 없으면 nil이다.
    public private(set) var report: RemovalReport?
    /// 직전 되돌리기의 결과. `succeeded`는 "되돌림 성공"이다.
    public private(set) var restoreReport: RemovalReport?
    public var selection: Set<URL> = []

    /// 스캔 도중 다른 화면에서 지워진 경로.
    ///
    /// 스트림이 주는 결과는 훑은 시점의 스냅샷이라, 그사이 지워진 파일이 다음
    /// 스냅샷에 다시 실려 온다. 걸러 내지 않으면 사라진 파일이 선택된 채 목록에
    /// 되살아나고, 정리하면 '실패'로 남는다.
    private var removedDuringScan: Set<URL> = []

    private let scanStream: @Sendable () -> AsyncStream<ScanCoordinator.Progress>
    private let performRemove: @Sendable (CleanupItem) -> RemovalOutcome
    private let performRestore: @Sendable (RemovalOutcome) -> RemovalOutcome

    /// 스캔이 끝나면 결과를 알린다. 같은 결과를 다른 화면이 그대로 쓸 수 있다.
    public var onScanFinished: (@MainActor ([CleanupItem]) -> Void)?

    /// 삭제가 끝나면 지워진 경로를 알린다. 같은 파일을 다른 화면도 목록에 들고 있다.
    public var onRemoved: (@MainActor ([URL]) -> Void)?

    /// 삭제 한 회차의 결과를 알린다. 기록은 모델이 아니라 앱이 남긴다 —
    /// 모델은 폴더 허락이 바뀌면 버려지고, 삭제는 어느 기능 모델에서든 일어난다.
    /// **이번 회차 몫만** 넘긴다(재시도 때 이전 성공분을 다시 세지 않게).
    public var onReport: (@MainActor (RemovalReport) -> Void)?

    /// 되돌린 회차를 알린다. 누적 용량에서 빼는 일은 앱이 한다 — `onReport`와 같은 이유다.
    public var onRestored: (@MainActor (RemovalReport) -> Void)?

    /// 스캔·삭제 동작을 주입할 수 있게 열어 둔다.
    /// 실제 스캔은 17초 이상 걸리고 실제 삭제는 되돌릴 수 없어 테스트에 쓸 수 없다.
    public init(
        scan: @escaping @Sendable () -> AsyncStream<ScanCoordinator.Progress>
            = { ScanCoordinator.standard().stream() },
        removeOne: @escaping @Sendable (CleanupItem) -> RemovalOutcome
            = { Remover().removeOne($0) },
        restoreOne: @escaping @Sendable (RemovalOutcome) -> RemovalOutcome
            = { Restorer().restoreOne($0) }
    ) {
        self.scanStream = scan
        self.performRemove = removeOne
        self.performRestore = restoreOne
    }

    /// 기능 하나에 묶인 모델. 그 기능의 스캐너만 돌린다.
    public convenience init(feature: Feature) {
        self.init(scan: { feature.coordinator.stream() })
    }

    // MARK: - 파생 상태

    public var selectedItems: [CleanupItem] { items.filter { selection.contains($0.url) } }
    public var formattedSelectedSize: String { selectedItems.formattedTotalSize }
    public var hasSelection: Bool { !selection.isEmpty }

    /// 스캔이나 삭제가 도는 중.
    ///
    /// 이때는 새 명령을 받으면 안 된다. 메뉴와 하단 바가 **같은 값**을 보고
    /// 잠겨야 한다 — 각자 판단하면 한쪽만 눌리는 상태가 생긴다.
    public var isBusy: Bool {
        switch phase {
        case .scanning, .removing, .restoring: true
        case .idle, .results, .cleaned, .restored: false
        }
    }

    /// 정리·되돌리기 결과 화면을 보여 주는 중.
    ///
    /// 바쁘지는 않지만 되돌리기를 기다릴 수 있는 상태라, 다른 화면이 결과를
    /// 나눠 줄 때 덮으면 안 된다 — 덮으면 `report`가 사라져 되돌릴 수 없게 된다.
    public var isShowingOutcome: Bool {
        phase == .cleaned || phase == .restored
    }

    /// 완료 화면에서 되돌릴 수 있는가. 휴지통 위치를 아는 성공분이 있어야 한다.
    /// 한 번 되돌리면 `report`가 비어 다시 되돌릴 수 없다.
    public var canUndo: Bool {
        phase == .cleaned && !(report?.restorable.isEmpty ?? true)
    }

    /// 찾아낸 전체 용량. 이게 안 보이면 사용자는 자기가 뭘 얻을 수 있는지 모른 채
    /// 선택량만 보게 된다 — 6.9GB를 찾아놓고 111KB만 보이는 일이 생긴다.
    public var formattedTotalSize: String { items.formattedTotalSize }

    /// 한 번에 고르는 방법. 안전도 기준이라 결과를 예측할 수 있다.
    public enum SelectionPreset: String, CaseIterable, Sendable {
        case safeOnly = "안전만"
        /// 되돌릴 수 없는 것(danger)만 뺀다. 실질적인 기본 추천.
        case recommended = "권장"
        case all = "전체"
        case none = "해제"

        /// 화면에 보이는 이름. rawValue는 리터럴이라 현지화할 수 없다.
        public var title: String {
            switch self {
            case .safeOnly: String(localized: "안전만")
            case .recommended: String(localized: "권장")
            case .all: String(localized: "selection.all", defaultValue: "전체")
            case .none: String(localized: "해제")
            }
        }
    }

    public func apply(_ preset: SelectionPreset) {
        let chosen: [CleanupItem]
        switch preset {
        case .safeOnly: chosen = items.filter { $0.safety == .safe }
        case .recommended: chosen = items.filter { $0.safety != .danger }
        case .all: chosen = items
        case .none: chosen = []
        }
        selection = Set(chosen.map(\.url))
    }

    /// 섹션 헤더 체크박스가 그릴 세 가지 상태.
    public enum SectionSelection: String, CaseIterable, Sendable {
        case none, partial, all

        /// 부분 선택은 빼기 기호로 그린다. 체크와 빈 칸만으로는 구분되지 않는다.
        public var symbolName: String {
            switch self {
            case .none: "square"
            case .partial: "minus.square.fill"
            case .all: "checkmark.square.fill"
            }
        }

        /// 하나라도 선택돼 있으면 강조색을 쓴다.
        public var isEmphasized: Bool { self != .none }
    }

    public func selectionState(of group: ScanGroup) -> SectionSelection {
        let picked = group.items.filter { selection.contains($0.url) }.count
        if picked == 0 { return .none }
        return picked == group.items.count ? .all : .partial
    }

    /// 접어 둔 묶음.
    ///
    /// 뷰가 들면 탭을 옮겼다 돌아올 때 초기화된다 — 스무 줄을 도로 펼쳐 놓고
    /// 다시 접게 만든다. 선택과 같은 수명을 가져야 하므로 모델이 소유한다.
    public private(set) var collapsedGroups: Set<ScanGroup.Kind> = []

    public func isCollapsed(_ group: ScanGroup) -> Bool {
        collapsedGroups.contains(group.kind)
    }

    /// 이 묶음에서 화면에 그릴 행. **접혀 있으면 비어 있다.**
    ///
    /// 화면이 `if !isCollapsed { ForEach(items) }`로 감싸면 목록의 **구조**가 바뀌어
    /// SwiftUI가 view list를 통째로 다시 만든다 — 실측에서 스크롤 중 메인 스레드를
    /// 그 작업이 차지했다. 구조는 그대로 두고 **내용만** 비우는 것이 요점이라
    /// 판단을 모델에 둔다.
    public func visibleRows(of group: ScanGroup) -> [CleanupItem] {
        isCollapsed(group) ? [] : group.items
    }

    public func toggleCollapsed(_ group: ScanGroup) {
        if collapsedGroups.contains(group.kind) {
            collapsedGroups.remove(group.kind)
        } else {
            collapsedGroups.insert(group.kind)
        }
    }

    /// 부분 선택이면 전체 선택으로 올린다. 이미 전체면 해제한다.
    public func toggleAll(in group: ScanGroup) {
        let urls = group.items.map(\.url)
        if selectionState(of: group) == .all {
            selection.subtract(urls)
        } else {
            selection.formUnion(urls)
        }
    }

    /// 표 정렬. 헤더를 누르면 바뀐다. 묶음은 그대로 두고 묶음 **안**을 정렬한다.
    ///
    /// `Dictionary(grouping:)`은 원본 순서를 물려준다. 스캔 결과는 카테고리 우선이라
    /// 판단 기준으로 다시 묶으면 순서가 깨진다 — 묶을 때마다 다시 정렬해야 한다.
    public var sort: ItemSort = .default

    public func toggleSort(_ key: ItemSort.Key) { sort = sort.toggled(key) }

    /// 카테고리별 섹션. 위험한 카테고리가 위로 온다.
    ///
    /// 스마트 스캔이 쓴다 — 거기서는 기능별로 갈리는 것이 정보다.
    public var groups: [ScanGroup] {
        Dictionary(grouping: items, by: \.category)
            .map { ScanGroup(kind: .category($0.key), items: sort.sorted($0.value)) }
            .sorted { ($0.category?.sortOrder ?? 0) < ($1.category?.sortOrder ?? 0) }
    }

    /// 판단 기준별 섹션. **다시 만들 수 있는 것부터** 위로 온다.
    ///
    /// 기능 화면이 쓴다. 같은 카테고리라도 판단이 정반대인 것들이 섞여 있다 —
    /// `Xcode_26.0.xip`(다시 받으면 된다)와 `제주 여행 원본.mov`(없으면 끝)가
    /// 한 덩어리에 있으면 하나씩 열어 봐야 고를 수 있다.
    public var safetyGroups: [ScanGroup] {
        Dictionary(grouping: items, by: \.safety)
            .map { ScanGroup(kind: .safety($0.key), items: sort.sorted($0.value)) }
            .sorted { lhs, rhs in
                guard case .safety(let l) = lhs.kind, case .safety(let r) = rhs.kind
                else { return false }
                // 안전도로 거꾸로 정렬하면 묶음 순서를 뒤집는다 — 여기서는 묶음이 곧 안전도다.
                return sort.key == .safety && !sort.ascending ? l > r : l < r
            }
    }

    public func isSelected(_ item: CleanupItem) -> Bool { selection.contains(item.url) }

    public func setSelection(_ isOn: Bool, for item: CleanupItem) {
        if isOn { selection.insert(item.url) } else { selection.remove(item.url) }
    }

    // MARK: - 동작

    public func scan() async {
        phase = .scanning(percent: 0, remainingSeconds: nil)
        report = nil
        restoreReport = nil
        items = []
        selection = []
        removedDuringScan = []

        for await progress in scanStream() {
            items = progress.items.filter { !removedDuringScan.contains($0.url) }
            // safe만 미리 체크한다. 사용자가 "전체 선택 → 삭제"를 눌러도
            // 되돌릴 수 없는 것(Archives 등)은 빠져 있어야 한다.
            //
            // 중간 결과마다 갱신하는 이유: 끝나고 한꺼번에 체크되면 화면이 튄다.
            selection = Set(items.filter(\.isSelectedByDefault).map(\.url))
            phase = .scanning(percent: progress.percent,
                              remainingSeconds: progress.estimatedRemaining
                                  .map { Int($0.components.seconds) })
        }
        phase = .results
        onScanFinished?(items)
    }

    public func removeSelected() async {
        await remove(selectedItems, keeping: [])
    }

    /// 직전 회차에서 실패한 것만 다시 지운다.
    ///
    /// 성공분은 그대로 두고 결과를 합친다 — 재시도로 지워진 용량이 완료 화면의
    /// "확보" 합계에 더해져야 한다. 앞 회차 성공분을 버리면 재시도 후 숫자가 줄어든다.
    public func retryFailed() async {
        guard let previous = report else { return }
        await remove(previous.failed.map(\.item), keeping: previous.succeeded)
    }

    /// `earlier`는 같은 완료 화면에 이어 붙일 앞 회차의 성공분이다.
    private func remove(_ targets: [CleanupItem], keeping earlier: [RemovalOutcome]) async {
        guard !targets.isEmpty else { return }

        let remove = performRemove
        var outcomes: [RemovalOutcome] = []
        for (index, item) in targets.enumerated() {
            phase = .removing(done: index, total: targets.count)
            // 파일 I/O가 메인 액터를 막지 않도록 떼어낸다.
            outcomes.append(await Task.detached { remove(item) }.value)
        }

        let round = RemovalReport(outcomes: outcomes)
        // 지워진 것만 목록에서 뺀다. 실패한 항목은 남겨야 사용자가 사유를 보고 다시 시도한다.
        let removed = Set(round.succeeded.map(\.item.url))
        items.removeAll { removed.contains($0.url) }
        selection.subtract(removed)

        report = RemovalReport(outcomes: earlier + outcomes)
        phase = .cleaned
        // 기록에는 이번 회차 몫만 넘긴다. 합친 결과를 넘기면 앞 회차 성공분이 두 번 세어진다.
        onReport?(round)
        // **성공한 것만** 알린다. 실패한 항목까지 넘기면 다른 화면에서
        // 멀쩡히 남아 있는 파일이 목록에서 사라진다.
        onRemoved?(Array(removed))
    }

    /// 방금 정리한 회차를 원래 자리로 되돌린다.
    ///
    /// 재시도로 합쳐진 회차면 합쳐진 성공분 전체가 대상이다. 확인을 묻지 않는다 —
    /// 파일을 지우지 않고 원래 자리로 옮기기만 하는 동작이라, 이것 자체가 되돌릴 수 있다.
    public func undoLastCleanup() async {
        guard canUndo, let targets = report?.restorable else { return }

        let restore = performRestore
        var outcomes: [RemovalOutcome] = []
        for (index, outcome) in targets.enumerated() {
            phase = .restoring(done: index, total: targets.count)
            outcomes.append(await Task.detached { restore(outcome) }.value)
        }

        let round = RemovalReport(outcomes: outcomes)
        // 되돌린 것은 다시 목록에 넣되 **고르지 않는다.** 방금 되돌린 것이 선택된 채로
        // 있으면 다음 정리에 그대로 다시 휩쓸린다.
        items.append(contentsOf: round.succeeded.map(\.item))

        restoreReport = round
        // 같은 회차를 두 번 되돌리지 못하게 비운다.
        report = nil
        phase = .restored
        onRestored?(round)
    }

    /// 다른 화면이 이미 찾아낸 결과를 그대로 받는다.
    ///
    /// 스마트 스캔이 전부 훑었으면 기능 탭이 같은 43초를 다시 돌 이유가 없다.
    /// 스캔이 막 끝났을 때와 **같은 상태**로 놓는다 — 선택 기본값까지 같아야
    /// 어느 화면에서 왔는지에 따라 다른 것을 지우게 되지 않는다.
    ///
    /// 결과가 비어 있어도 `.results`다. `.idle`로 두면 "검색" 버튼이 떠서,
    /// 이미 훑어서 없다는 걸 아는데도 43초를 다시 기다리게 된다.
    public func adopt(_ found: [CleanupItem]) {
        items = found
        selection = Set(found.filter(\.isSelectedByDefault).map(\.url))
        report = nil
        restoreReport = nil
        phase = .results
    }

    /// 다른 화면에서 지워진 파일을 내 목록에서도 뺀다.
    ///
    /// 지운 파일이 다른 탭에 남아 있으면 목록도 사이드바 배지도 거짓말을 한다.
    /// `phase`는 건드리지 않는다 — 남은 것이 없으면 `.results`의 빈 화면
    /// ("정리할 항목이 없음")이 뜨는데, 그게 사실이다.
    public func forget(_ urls: [URL]) {
        let gone = Set(urls)
        // 스캔 중이면 아직 목록에 없는 것도 기억한다. 다음 스냅샷에 실려 올 수 있다.
        if case .scanning = phase { removedDuringScan.formUnion(gone) }
        guard items.contains(where: { gone.contains($0.url) }) else { return }
        items.removeAll { gone.contains($0.url) }
        selection.subtract(gone)
    }

    /// 완료 화면을 닫는다.
    ///
    /// 남은 항목이 없으면 결과 목록을 띄울 이유가 없어 시작 화면으로 돌아간다.
    public func dismissReport() {
        restoreReport = nil
        phase = items.isEmpty ? .idle : .results
    }
}
