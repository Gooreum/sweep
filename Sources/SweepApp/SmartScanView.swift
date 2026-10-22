import SwiftUI
import SweepKit

/// 첫 화면. 한 번에 전체를 훑고 기능별로 얼마가 나왔는지 보여준다.
///
/// 사이드바를 하나씩 눌러 보지 않아도 어디에 용량이 묶여 있는지 알 수 있어야 한다.
struct SmartScanView: View {
    @Bindable var app: AppModel
    @Bindable var model: ScanModel

    /// 샌드박스에서는 폴더를 **여러 번** 허락할 수 있다. 생성 때 한 번만 읽으면
    /// 두 번째 허락이 목록에 반영되지 않는다 — 예전에는 허락이 한 번뿐이라
    /// `let`으로 두고 부모가 다시 그리는 것에 기댔다.
    ///
    /// 그렇다고 `body`에서 매번 부르면 스캔 진행률이 바뀔 때마다 루트를 다시 계산한다.
    /// 허락한 폴더 수가 바뀔 때만 다시 읽는다.
    @State private var scopes = CleanupScope.all

    /// 틀린 폴더를 골랐을 때 알려줄 말. nil이면 닫혀 있다.
    @State private var grantFailure: String?

    /// 추가할 수 없는 폴더를 골랐을 때 알려줄 말. 허락 실패와 제목이 달라 따로 둔다.
    @State private var addFailure: String?

    /// 보는 곳마다 지금 읽을 수 있는지. 줄마다 디스크를 두드리지 않도록 한 번에 만든다.
    ///
    /// 권한은 실행 중에 막히거나 풀린다 — TCC 프롬프트를 거부하거나, 시스템 설정에서
    /// 켜고 돌아오거나. 화면이 그것을 반영하지 못하면 사용자는 "정리할 항목 없음"만 본다.
    @State private var readability: [String: FolderReadability] = [:]

    var body: some View {
        Group {
            switch model.phase {
            case .idle:
                welcome
            case let .scanning(percent, _):
                scanning(percent: percent)
            case let .removing(done, total):
                Retro95ScanPanel(
                    title: String(localized: "정리 중"), headline: String(localized: "정리하는 중"), detail: nil,
                    fraction: total > 0 ? Double(done) / Double(total) : nil,
                    percentText: total > 0 ? "\(done * 100 / total)%" : nil,
                    leftFooter: "\(done)개 완료, 전체 \(total)개", rightFooter: nil)
                    .padding(10)
            case let .restoring(done, total):
                Retro95ScanPanel(
                    title: String(localized: "복구 중"), headline: String(localized: "파일을 원래 자리에 놓고 있어요"), detail: nil,
                    fraction: total > 0 ? Double(done) / Double(total) : nil,
                    percentText: total > 0 ? "\(done * 100 / total)%" : nil,
                    leftFooter: "\(done)개 완료, 전체 \(total)개", rightFooter: nil)
                    .padding(10)
            case .results, .cleaned, .restored:
                summary
            }
        }
        .background(R95.gray)
        .foregroundStyle(R95.black)
        // 폴더를 새로 허락하면 "보는 곳" 목록이 늘고, 읽기 상태도 달라진다.
        .onChange(of: app.grantedFolderCount) { refreshReadability() }
        .onChange(of: app.scanFolderCount) { refreshReadability() }
    }


    /// 스캔 전 화면. **빈 판을 두지 않는다.**
    ///
    /// 열자마자 보여줄 게 있어야 한다 — 디스크 현황은 스캔 없이 즉시 알 수 있고,
    /// "무엇을 건드리는지"는 파일을 지우는 앱에서 첫 화면에 있을 값이다.
    private var welcome: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                // 검색 버튼이 이 화면에 없었다. 명령줄의 작은 버튼이 유일해서
                // 사용자가 "어디서 검색하냐"고 물었다 — 첫 화면 맨 위에 둔다.
                scanHero

                // 요약을 한 번만 만들어 넘긴다. 화면 안에서 두 번 부르면
                // 그때마다 전체 항목을 기능 수만큼 필터링한다.
                diskCard

                // 지금까지 얼마를 비웠는지. 기록이 없으면 줄 자체가 없다 —
                // "0 B 확보"는 알려줄 것이 아니라 자리만 차지한다.
                if let line = app.cleanupSummary.statusLine() {
                    Text(line)
                        .font(Theme.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .monospacedDigit()
                }

                scopeCard
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 첫 화면의 주 동작. 무엇을 훑는지 한 줄로 말하고 바로 누르게 한다.
    ///
    /// 정리 독(`SelectionDock`)과 같은 구성 — 48px 아이콘 · 두 줄 설명 · 오른쪽 주 버튼.
    /// 앱 안에서 이미 익숙한 모양이라 "여기가 주 동작"으로 바로 읽힌다.
    private var scanHero: some View {
        HStack(spacing: 12) {
            PixelIcon(art: .magnifier, size: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text("정리할 파일, 여기서 한번에 찾아보세요")
                    .font(R95.ui(14, bold: true))
                Text("앱을 만들며 쌓인 파일, 앱이 다시 쓰려고 저장한 파일, 큰 파일과 중복 파일을 찾아요. 결과에서 필요 없는 것만 골라 정리하면 돼요.")
                    .font(R95.ui(11))
                    .foregroundStyle(R95.deep)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            ScanButton(model: model, title: String(localized: "전체 검색"), showsShortcut: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(R95.gray)
        .retroRaised()
    }

    /// 전체 디스크는 작은 미터로 보여줘 권한 목록과 결과에 공간을 남긴다.
    @ViewBuilder
    private var diskCard: some View {
        // 디스크 용량은 `AppModel`이 들고 있다가 정리·되돌리기 직후 다시 읽는다.
        // 여기서 볼륨을 조회하지 않는다 — body는 스캔 진행률마다 다시 돈다.
        if let usage = app.volumeUsage {
            Retro95GroupBox(title: String(localized: "디스크 정보")) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 16) {
                        PixelIcon(art: .hardDrive, size: 48)
                        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                            diskValue(String(localized: "사용 가능"), usage.formattedAvailable)
                            diskValue(String(localized: "사용됨"), usage.formattedUsed)
                            diskValue(String(localized: "전체"), usage.formattedTotal)
                        }
                        Spacer(minLength: 0)
                    }
                    HStack(spacing: 8) {
                        Retro95ProgressBar(fraction: usage.usedFraction)
                        Text("\(Int(usage.usedFraction * 100))% 사용됨")
                            .font(R95.mono())
                    }
                }
            }
        }
    }

    private func diskValue(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).font(R95.ui())
            Text(value).font(R95.mono()).gridColumnAlignment(.trailing)
        }
    }

    /// Sweep이 들여다보는 곳. 목록은 안전 게이트의 허용 루트에서 유도된다.
    private var scopeCard: some View {
        Retro95GroupBox(title: String(localized: "찾아볼 곳")) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("아래에 있는 곳만 찾아봐요")
                        .font(R95.ui(11))
                        .foregroundStyle(R95.deep)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)

                R95.light.frame(height: 1)

                ForEach(Array(scopes.enumerated()), id: \.element.id) { index, scope in
                    let blocked = readability[scope.id] == .denied

                    // 탐색기 상세 보기처럼 경로와 설명을 한 줄에 둔다. 두 줄로 쌓으면
                    // 일곱 줄이 창을 다 차지해 아래 내용이 밀려난다.
                    HStack(spacing: 8) {
                        PixelIcon(art: .folder, size: 16)
                        Text(scope.label)
                            .font(R95.mono(12))
                            .foregroundStyle(R95.black)
                            .lineLimit(1)
                            .frame(width: 220, alignment: .leading)
                        // 막혔으면 무엇을 찾는 곳인지보다 왜 비어 있는지가 먼저다.
                        Group {
                            if blocked {
                                Text("폴더를 허용하면 여기서도 찾을 수 있어요").foregroundStyle(R95.danger)
                            } else {
                                Text(scope.detail).foregroundStyle(R95.deep)
                            }
                        }
                        .font(R95.ui(11))
                        .lineLimit(1)
                        Spacer(minLength: 8)

                        if blocked {
                            Button("열기…") { unblock(scope) }
                        } else if scope.isCustom {
                            Button("빼기") { app.removeScanFolder(scope.url) }
                        }
                    }
                    .padding(.horizontal, 8)
                    .frame(minHeight: R95.compactRowHeight)

                    if index < scopes.count - 1 {
                        R95.light.frame(height: 1)
                    }
                }

                addFolderRow
                folderAccessRows
                blockedFooter

                // 전체 디스크 접근은 **한 번 켜면 끝나는 스위치**다. 앱 폴더마다 따로 묻는
                // "다른 앱의 데이터" 물음을 통째로 없앤다 — 늘 보이는 자리에 둔다.
                if !app.hasFullDiskAccess {
                    Divider().overlay(Theme.border)
                    FullDiskAccessBanner()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(R95.white)
            .retroSunken()
        }
        .buttonStyle(Retro95ButtonStyle())
        .task { refreshReadability() }
        .alert("필요한 폴더와 달라요",
               isPresented: Binding(get: { grantFailure != nil },
                                    set: { if !$0 { grantFailure = nil } })) {
            Button("확인") { grantFailure = nil }
        } message: {
            Text(grantFailure ?? "")
        }
        .alert("찾을 곳에 넣지 못했어요",
               isPresented: Binding(get: { addFailure != nil },
                                    set: { if !$0 { addFailure = nil } })) {
            Button("확인") { addFailure = nil }
        } message: {
            Text(addFailure ?? "")
        }
    }

    /// 큰 파일·중복 파일을 찾을 폴더를 더하는 줄. 홈 아래 보이는 폴더는 이미 다 보므로
    /// 외장 디스크처럼 홈 밖을 더하는 입구다 — 샌드박스에서는 홈 안 폴더를 여는 길도 된다.
    private var addFolderRow: some View {
        VStack(spacing: 0) {
            Divider().overlay(Theme.border)

            HStack(spacing: 12) {
                PixelIcon(art: .folder, size: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text("폴더 추가")
                        .font(Theme.bodyText)
                        .foregroundStyle(Theme.textPrimary)
                    Text("외장 디스크 같은 다른 곳도 찾으려면 폴더를 추가해 주세요. 그 안의 큰 파일과 중복 파일을 찾아요.")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 12)

                Button("추가…") { addFolder() }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
    }

    private func addFolder() {
        guard let picked = FolderPicker.askAnyFolder() else { return }
        do {
            try app.addScanFolder(picked)
        } catch {
            addFailure = error.message
        }
    }

    /// 폴더를 더 열거나 거두는 줄. **샌드박스에서만 보인다.**
    ///
    /// 이 허락은 시스템 설정 어디에도 나타나지 않는다. 앱이 입구를 주지 않으면
    /// 사용자는 마음을 바꿀 방법이 없다 — 여기가 그 유일한 곳이다.
    ///
    /// 얼마나 더 찾을 수 있는지(용량)는 보여줄 수 없다. 크기를 재려면 그 폴더를
    /// 읽어야 하는데 허락 전에는 읽지 못한다. 대신 무엇이 있는지를 말한다.
    @ViewBuilder
    private var folderAccessRows: some View {
        if Sandbox.isActive {
            Divider().overlay(Theme.border)

            ForEach(FolderAccess.grantables) { grantable in
                let granted = app.isGranted(grantable)

                HStack(spacing: 12) {
                    PixelIcon(art: .folder, size: 16)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(grantable.label)
                            .font(Theme.bodyMono)
                            .foregroundStyle(Theme.textPrimary)
                        Text(grantable.purpose)
                            .font(Theme.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer(minLength: 12)

                    if granted {
                        // "해제"는 선택 프리셋에도 있다. 영어로는 다른 말이라 키를 나눈다.
                        Button(String(localized: "folderAccess.revoke", defaultValue: "해제")) { app.revokeFolderAccess(grantable) }
                    } else {
                        Button("열기…") { grant(grantable) }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            // 링크 글자로 두니 누르는 것인지 몰랐다. 사이드바와 같은 볼록 버튼으로 둔다.
            HStack {
                Spacer(minLength: 0)
                SettingsLink { Text("권한 모두 보기").padding(.horizontal, 8) }
                    .buttonStyle(Retro95ButtonStyle())
            }
            .padding(8)
        }
    }

    private func grant(_ grantable: FolderAccess.Grantable) {
        guard let picked = FolderPicker.ask(for: grantable) else { return }
        do {
            try app.grantFolderAccess(picked, as: grantable)
            refreshReadability()
        } catch {
            grantFailure = error.message
        }
    }

    /// 막힌 폴더가 하나라도 있으면 보인다.
    ///
    /// 열기 대화상자로 고르면 대개 풀리지만, TCC가 이미 거부를 기록했다면
    /// 시스템 설정에서 되돌리는 것이 확실한 길이다. 둘 다 준다.
    @ViewBuilder
    private var blockedFooter: some View {
        if readability.values.contains(.denied) {
            Divider().overlay(Theme.border)

            HStack(spacing: 12) {
                Text("일부 폴더는 볼 수 없어요. 시스템 설정에서 Sweep의 폴더 접근을 허용해 주세요.")
                    .font(Theme.caption)
                    .foregroundStyle(R95.danger)
                Spacer(minLength: 12)
                Button("시스템 설정 열기") { PrivacySettings.openFilesAndFolders() }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
    }

    /// 막힌 폴더를 열기 대화상자로 직접 고르게 한다.
    ///
    /// TCC 거부는 "앱이 알아서 여는 것"을 막는 것이라, 사용자가 명시적으로 고른
    /// 폴더는 보안 범위 접근이 따로 부여된다. 그것으로도 안 풀리면 시스템 설정이 남는다.
    private func unblock(_ scope: CleanupScope) {
        // 홈 묶음 줄은 홈 허락과 같은 것이다. 같은 키로 저장해야 다음 실행에 복원된다.
        let grantable = scope.url.path == Sandbox.userHome.path ? FolderAccess.home : FolderAccess.Grantable(folder: scope.url,
                                               label: scope.label,
                                               purpose: scope.detail.isEmpty
                                                   ? String(localized: "정리 대상") : scope.detail)
        guard let picked = FolderPicker.ask(for: grantable) else { return }
        do {
            try app.grantFolderAccess(picked, as: grantable)
        } catch let failure as FolderAccess.Failure {
            grantFailure = failure.message
        } catch {
            grantFailure = error.localizedDescription
        }
        // 허락에 실패해도 다시 읽어 본다 — 사용자가 그 사이 설정에서 풀었을 수 있다.
        refreshReadability()
    }

    /// 보는 곳의 읽기 상태를 다시 계산한다. 권한은 실행 중에 바뀐다.
    private func refreshReadability() {
        scopes = CleanupScope.all
        readability = CleanupScope.readabilityMap(of: scopes)
    }

    private func scanning(percent: Int) -> some View {
        VStack(spacing: 0) {
            Retro95ScanPanel(
                title: String(localized: "검색 중"), headline: String(localized: "정리할 파일을 찾고 있어요…"), detail: nil,
                fraction: Double(percent) / 100, percentText: "\(percent)%",
                leftFooter: model.items.isEmpty ? nil : String(localized: "찾은 파일 \(model.items.count)개, \(model.formattedTotalSize)"),
                // 남은 시간은 넣지 않는다. 스캐너마다 속도가 달라 어림값이 크게 틀렸다.
                rightFooter: nil)
            Spacer()
        }
        .padding(10)
    }

    private var summary: some View {
        let summary = model.summary
        let largest = summary.breakdown.first?.bytes ?? 0

        return ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                diskCard
                if let line = app.cleanupSummary.statusLine() {
                    Text(line).font(R95.ui(11)).monospacedDigit()
                }
                Retro95GroupBox(title: String(localized: "찾은 파일")) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(model.formattedTotalSize).font(R95.ui(20, bold: true)).monospacedDigit()
                            Text("정리 후보").font(R95.ui())
                            Spacer()
                            Text("\(summary.breakdown.reduce(0) { $0 + $1.count })개 항목").font(R95.mono())
                        }
                        ReclaimBar(rows: summary.breakdown)
                        ReclaimLegend(rows: summary.breakdown)
                        VStack(spacing: 0) {
                            Retro95TableHeader(columns: SmartSummaryColumns.headers)
                            ForEach(summary.breakdown) { row in
                                breakdownRow(row, largest: largest)
                                Retro95Separator()
                            }
                        }
                        .background(R95.white)
                        .retroSunken()
                    }
                }

                // 오래 정리하지 않았고 지금 지워도 되는 것이 있을 때만 권한다.
                if let nudge = app.cleanupSummary.nudgeLine(
                    safeBytes: model.items.filter(\.isSelectedByDefault).totalSize) {
                    Text(nudge).font(R95.ui()).foregroundStyle(R95.navy)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 헤더와 행의 열 폭을 공유해 용량과 항목 수를 세로로 비교하게 한다.
    private func breakdownRow(_ row: MenuBarSummary.Row, largest: Int64) -> some View {
        Button {
            app.selected = row.feature
        } label: {
            HStack(spacing: 0) {
                HStack(spacing: 6) {
                    PixelIcon(art: row.feature.pixelArt, size: 16)
                    Text(row.feature.displayName).font(R95.ui(12, bold: true))
                }
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                Text("\(row.count)개").font(R95.mono())
                    .padding(.horizontal, 6)
                    .frame(width: SmartSummaryColumns.count, alignment: .trailing)
                Text(row.formattedSize).font(R95.mono())
                    .padding(.horizontal, 6)
                    .frame(width: SmartSummaryColumns.size, alignment: .trailing)
                Retro95ProgressBar(fraction: ratio(row, largest))
                    .padding(.horizontal, 6)
                    .frame(width: SmartSummaryColumns.bar)
            }
            .foregroundStyle(R95.black)
            .frame(height: R95.compactRowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// 0으로 나누지 않는다. 1위가 0이면 아무것도 못 찾은 것이라 막대도 없다.
    private func ratio(_ row: MenuBarSummary.Row, _ largest: Int64) -> Double {
        largest > 0 ? Double(row.bytes) / Double(largest) : 0
    }
}
