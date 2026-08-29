import Foundation
import Observation

/// 화면에 보여줄 카테고리 섹션 하나.
public struct ScanGroup: Identifiable, Sendable, Hashable {
    public let category: ScanCategory
    public let items: [CleanupItem]

    public var id: ScanCategory { category }
    public var formattedTotalSize: String { items.formattedTotalSize }
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
    public var groups: [ScanGroup] {
        Dictionary(grouping: items, by: \.category)
            .map { ScanGroup(category: $0.key, items: $0.value) }
            .sorted { $0.category.sortOrder < $1.category.sortOrder }
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
    }

    /// 완료 화면을 닫는다.
    ///
    /// 남은 항목이 없으면 결과 목록을 띄울 이유가 없어 시작 화면으로 돌아간다.
    public func dismissReport() {
        phase = items.isEmpty ? .idle : .results
    }
}
