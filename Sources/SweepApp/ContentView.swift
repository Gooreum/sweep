import SwiftUI
import SweepKit

struct ContentView: View {
    /// 정리와 디스크 맵은 성격이 다르다. 맵은 읽기 전용이라 삭제 바를 숨긴다.
    private enum Tab: String, CaseIterable, Identifiable {
        case cleanup = "정리"
        case diskMap = "디스크 맵"
        var id: Self { self }
    }

    @State private var model = ScanModel()
    @State private var tab: Tab = .cleanup

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 260)
            .padding(.vertical, 8)

            Divider()

            switch tab {
            case .cleanup:
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                footer
            case .diskMap:
                DiskMapView()
            }
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

        case .scanning(let percent, let remaining):
            VStack(spacing: 0) {
                scanBanner(percent: percent, remainingSeconds: remaining)
                Divider()
                // 이미 찾은 것이 있으면 기다리는 동안 보여준다
                if model.items.isEmpty {
                    placeholder(icon: "magnifyingglass", title: "훑는 중입니다",
                                message: "찾는 대로 여기에 쌓입니다.")
                } else {
                    resultList
                }
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

    private func scanBanner(percent: Int, remainingSeconds: Int?) -> some View {
        HStack(spacing: 10) {
            ProgressView(value: Double(percent), total: 100)
                .frame(width: 160)
            Text("\(percent)%")
                .monospacedDigit()
                .frame(width: 44, alignment: .leading)
            if let remainingSeconds {
                Text("약 \(Self.readable(seconds: remainingSeconds)) 남음")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    /// "45초" / "1분 20초". 분 단위가 넘어가면 초만 보여주는 건 읽기 나쁘다.
    static func readable(seconds: Int) -> String {
        seconds < 60 ? "\(seconds)초" : "\(seconds / 60)분 \(seconds % 60)초"
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
