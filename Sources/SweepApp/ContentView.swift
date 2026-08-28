import SwiftUI
import SweepKit

struct ContentView: View {
    @State private var model = ScanModel()

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            footer
        }
    }

    // MARK: - 상태별 본문

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .idle:
            placeholder(
                icon: "sparkles",
                title: "정리할 것을 찾아봅니다",
                message: "Xcode 산출물, 개발 캐시, 폭주 중인 임시 파일, 중복 내려받기를 훑습니다.")

        case .scanning:
            VStack(spacing: 12) {
                ProgressView()
                Text("스캔 중…").foregroundStyle(.secondary)
                // 실측 17초 이상 걸린다. 왜 오래 걸리는지 알려줘야 사용자가 기다린다.
                Text("임시 파일이 커지고 있는지 보려고 두 번 측정합니다.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

        case .removing(let done, let total):
            VStack(spacing: 12) {
                ProgressView(value: Double(done), total: Double(total))
                    .frame(maxWidth: 320)
                Text("삭제 중 \(done)/\(total)").foregroundStyle(.secondary)
            }

        case .results:
            if model.items.isEmpty {
                placeholder(
                    icon: "checkmark.circle",
                    title: "정리할 것이 없습니다",
                    message: "회수할 만한 크기의 항목을 찾지 못했습니다.")
            } else {
                resultList
            }
        }
    }

    private var resultList: some View {
        List {
            ForEach(model.groups) { group in
                Section {
                    ForEach(group.items) { item in
                        ItemRow(item: item, isOn: binding(for: item))
                    }
                } header: {
                    HStack {
                        Label(group.category.displayName,
                              systemImage: group.category.systemImageName)
                        Spacer()
                        Text(group.formattedTotalSize)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func placeholder(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    // MARK: - 하단 바

    private var footer: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("선택 \(model.selectedItems.count)개 · \(model.formattedSelectedSize)")
                    .monospacedDigit()
                if let report = model.report {
                    Text(summary(of: report))
                        .font(.caption)
                        .foregroundStyle(report.failed.isEmpty ? Color.secondary : Color.red)
                }
            }

            Spacer()

            Button("다시 스캔") {
                Task { await model.scan() }
            }
            .disabled(isBusy)

            Button("휴지통으로 이동") {
                Task { await model.removeSelected() }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(isBusy || !model.hasSelection)
        }
        .padding(12)
    }

    private var isBusy: Bool {
        switch model.phase {
        case .scanning, .removing: true
        case .idle, .results: false
        }
    }

    private func summary(of report: RemovalReport) -> String {
        report.failed.isEmpty
            ? "\(report.succeeded.count)개 이동 · \(report.formattedReclaimed) 확보"
            : "\(report.succeeded.count)개 이동 · \(report.failed.count)개 실패 — "
                + (report.failed.first?.failureReason ?? "")
    }

    /// `selection`(Set<URL>)을 체크박스가 쓰는 Bool 바인딩으로 잇는다.
    private func binding(for item: CleanupItem) -> Binding<Bool> {
        Binding(
            get: { model.isSelected(item) },
            set: { model.setSelection($0, for: item) })
    }
}
