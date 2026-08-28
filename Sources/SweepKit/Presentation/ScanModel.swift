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
        case scanning
        case results
        case removing(done: Int, total: Int)
    }

    public private(set) var phase: Phase = .idle
    public private(set) var items: [CleanupItem] = []
    /// 직전 삭제 회차의 결과. 아직 삭제한 적이 없으면 nil이다.
    public private(set) var report: RemovalReport?
    public var selection: Set<URL> = []

    private let performScan: @Sendable () async -> [CleanupItem]
    private let performRemove: @Sendable (CleanupItem) -> RemovalOutcome

    /// 스캔·삭제 동작을 주입할 수 있게 열어 둔다.
    /// 실제 스캔은 17초 이상 걸리고 실제 삭제는 되돌릴 수 없어 테스트에 쓸 수 없다.
    public init(
        scan: @escaping @Sendable () async -> [CleanupItem]
            = { await ScanCoordinator.standard().scan() },
        removeOne: @escaping @Sendable (CleanupItem) -> RemovalOutcome
            = { Remover().removeOne($0) }
    ) {
        self.performScan = scan
        self.performRemove = removeOne
    }

    // MARK: - 파생 상태

    public var selectedItems: [CleanupItem] { items.filter { selection.contains($0.url) } }
    public var formattedSelectedSize: String { selectedItems.formattedTotalSize }
    public var hasSelection: Bool { !selection.isEmpty }

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
        phase = .scanning
        report = nil
        items = await performScan()
        // safe만 미리 체크한다. 사용자가 "전체 선택 → 삭제"를 눌러도
        // 되돌릴 수 없는 것(Archives 등)은 빠져 있어야 한다.
        selection = Set(items.filter(\.isSelectedByDefault).map(\.url))
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
        phase = .results
    }
}
