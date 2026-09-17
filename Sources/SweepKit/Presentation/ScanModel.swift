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

extension Array where Element == CleanupItem {
    /// 큰 것부터. **묶음 안에서는 크기가 유일한 정렬 기준이다.**
    ///
    /// `Dictionary(grouping:)`은 원본 순서를 그대로 물려준다. 스캔 결과는
    /// 카테고리 우선으로 정렬돼 있어서, 판단 기준으로 다시 묶으면 여러 카테고리가
    /// 한 묶음에 섞이며 크기순이 깨진다 — 5GB 아래에 200MB가 오고 그 아래 3GB가 온다.
    var sortedBySize: [CleanupItem] {
        sorted { $0.size > $1.size }
    }
}

extension SafetyLevel {
    /// 묶음 머리에 쓰는 이름. 등급 이름("안전")이 아니라 **무엇을 뜻하는지**를 적는다.
    public var groupLabel: String {
        switch self {
        case .safe: "다시 만들 수 있음"
        case .caution: "확인 필요"
        case .danger: "되돌릴 수 없음"
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
    }

    public private(set) var phase: Phase = .idle
    public private(set) var items: [CleanupItem] = []
    /// 직전 삭제 회차의 결과. 아직 삭제한 적이 없으면 nil이다.
    public private(set) var report: RemovalReport?
    public var selection: Set<URL> = []

    private let scanStream: @Sendable () -> AsyncStream<ScanCoordinator.Progress>
    private let performRemove: @Sendable (CleanupItem) -> RemovalOutcome

    /// 스캔이 끝나면 결과를 알린다. 같은 결과를 다른 화면이 그대로 쓸 수 있다.
    public var onScanFinished: (@MainActor ([CleanupItem]) -> Void)?

    /// 삭제가 끝나면 지워진 경로를 알린다. 같은 파일을 다른 화면도 목록에 들고 있다.
    public var onRemoved: (@MainActor ([URL]) -> Void)?

    /// 스캔·삭제 동작을 주입할 수 있게 열어 둔다.
    /// 실제 스캔은 17초 이상 걸리고 실제 삭제는 되돌릴 수 없어 테스트에 쓸 수 없다.
    public init(
        scan: @escaping @Sendable () -> AsyncStream<ScanCoordinator.Progress>
            = { ScanCoordinator.standard().stream() },
        removeOne: @escaping @Sendable (CleanupItem) -> RemovalOutcome
            = { Remover().removeOne($0) }
    ) {
        self.scanStream = scan
        self.performRemove = removeOne
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
        case .scanning, .removing: true
        case .idle, .results, .cleaned: false
        }
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

    /// 카테고리별 섹션. 위험한 카테고리가 위로 온다.
    ///
    /// 스마트 스캔이 쓴다 — 거기서는 기능별로 갈리는 것이 정보다.
    public var groups: [ScanGroup] {
        Dictionary(grouping: items, by: \.category)
            .map { ScanGroup(kind: .category($0.key), items: $0.value.sortedBySize) }
            .sorted { ($0.category?.sortOrder ?? 0) < ($1.category?.sortOrder ?? 0) }
    }

    /// 판단 기준별 섹션. **다시 만들 수 있는 것부터** 위로 온다.
    ///
    /// 기능 화면이 쓴다. 같은 카테고리라도 판단이 정반대인 것들이 섞여 있다 —
    /// `Xcode_26.0.xip`(다시 받으면 된다)와 `제주 여행 원본.mov`(없으면 끝)가
    /// 한 덩어리에 있으면 하나씩 열어 봐야 고를 수 있다.
    public var safetyGroups: [ScanGroup] {
        Dictionary(grouping: items, by: \.safety)
            .map { ScanGroup(kind: .safety($0.key), items: $0.value.sortedBySize) }
            .sorted { lhs, rhs in
                guard case .safety(let l) = lhs.kind, case .safety(let r) = rhs.kind
                else { return false }
                return l < r
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
        items = []
        selection = []

        for await progress in scanStream() {
            items = progress.items
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
        let targets = selectedItems
        guard !targets.isEmpty else { return }

        let remove = performRemove
        var outcomes: [RemovalOutcome] = []
        for (index, item) in targets.enumerated() {
            phase = .removing(done: index, total: targets.count)
            // 파일 I/O가 메인 액터를 막지 않도록 떼어낸다.
            outcomes.append(await Task.detached { remove(item) }.value)
        }

        let result = RemovalReport(outcomes: outcomes)
        // 지워진 것만 목록에서 뺀다. 실패한 항목은 남겨야 사용자가 사유를 보고 다시 시도한다.
        let removed = Set(result.succeeded.map(\.item.url))
        items.removeAll { removed.contains($0.url) }
        selection.subtract(removed)

        report = result
        phase = .cleaned
        // **성공한 것만** 알린다. 실패한 항목까지 넘기면 다른 화면에서
        // 멀쩡히 남아 있는 파일이 목록에서 사라진다.
        onRemoved?(Array(removed))
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
        phase = .results
    }

    /// 다른 화면에서 지워진 파일을 내 목록에서도 뺀다.
    ///
    /// 지운 파일이 다른 탭에 남아 있으면 목록도 사이드바 배지도 거짓말을 한다.
    /// `phase`는 건드리지 않는다 — 남은 것이 없으면 `.results`의 빈 화면
    /// ("정리할 항목이 없음")이 뜨는데, 그게 사실이다.
    public func forget(_ urls: [URL]) {
        let gone = Set(urls)
        guard items.contains(where: { gone.contains($0.url) }) else { return }
        items.removeAll { gone.contains($0.url) }
        selection.subtract(gone)
    }

    /// 완료 화면을 닫는다.
    ///
    /// 남은 항목이 없으면 결과 목록을 띄울 이유가 없어 시작 화면으로 돌아간다.
    public func dismissReport() {
        phase = items.isEmpty ? .idle : .results
    }
}
