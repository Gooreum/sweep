import Testing
import Foundation
@testable import SweepKit

@Suite("StatusLine")
@MainActor
struct StatusLineTests {

    private func sampleTree() -> DiskUsageNode {
        let a = DiskUsageNode(url: URL(filePath: "/private/tmp/root/a"), size: 300)
        let b = DiskUsageNode(url: URL(filePath: "/private/tmp/root/b"), size: 200)
        return DiskUsageNode(url: URL(filePath: "/private/tmp/root"), size: 500, children: [a, b])
    }

    // TC-1
    @Test("디스크 맵이 분모 없이 읽는 중이면 읽은 양을 보여주고 숫자 칸은 비운다")
    func diskMapReading() {
        let line = StatusLine.diskMap(loadPhase: .reading(bytes: 5_000_000), current: sampleTree())
        let read = ByteCountFormatter.string(fromByteCount: 5_000_000, countStyle: .file)
        #expect(line == StatusLine(status: "\(read) 읽는 중…", count: "—", size: "—"))
    }

    // TC-2
    @Test("디스크 맵이 크기를 재는 중이면 퍼센트를 보여준다")
    func diskMapMeasuring() {
        let line = StatusLine.diskMap(loadPhase: .measuring(percent: 42), current: nil)
        #expect(line == StatusLine(status: "크기 확인 중… 42%", count: "—", size: "—"))
    }

    // TC-3
    @Test("디스크 맵에 아직 아무것도 없으면 준비됨")
    func diskMapEmpty() {
        let line = StatusLine.diskMap(loadPhase: nil, current: nil)
        #expect(line == StatusLine(status: "시작 전", count: "—", size: "—"))
    }

    // TC-4
    @Test("디스크 맵을 보고 있으면 스캔 모델이 아니라 디스크 맵 상태를 보여준다")
    func appShowsDiskMap() {
        let tree = sampleTree()
        let app = AppModel(makeDiskMap: {
            let model = DiskMapModel()
            model.seed(tree)
            return model
        }, needsFolderAccess: false)
        app.selected = .diskMap
        _ = app.diskMap()

        #expect(app.statusLine == StatusLine(status: "확인 완료", count: "항목 2개",
                                              size: "크기 \(tree.formattedSize)"))
    }

    // TC-5
    @Test("정크 화면이 폴더 허락을 기다리면 그렇게 말한다")
    func junkNeedsFolderAccess() {
        let app = AppModel(folderAccess: FolderAccess.Registry(defaults: UserDefaults(suiteName: UUID().uuidString)!),
                           needsFolderAccess: true)
        app.selected = .junk

        #expect(app.statusLine == StatusLine(status: "폴더 선택 필요", count: "—", size: "—"))
    }

    // TC-6
    @Test("스캔 전 기능 화면은 준비됨 · 항목 0개")
    func scanIdle() {
        let app = AppModel(needsFolderAccess: false)
        app.selected = .junk

        #expect(app.statusLine == StatusLine(status: "시작 전", count: "항목 0개", size: "—"))
    }

    @Test("CPU 탭은 스캔 전 문구 '시작 전'을 쓰지 않고, 모델 없이 읽어도 만들지 않는다")
    func cpuTabIsNotNotStarted() {
        let app = AppModel(needsFolderAccess: false)
        app.selected = .cpu

        #expect(app.statusLine.status == "측정 중…")
        #expect(app.statusLine.status != "시작 전")
    }

    @Test("CPU 탭은 재기 시작하면 읽은 프로그램 수를 보여준다")
    func cpuTabShowsProgramCount() async {
        let model = CPUModel(
            interval: .milliseconds(5), limit: 20, cores: 1,
            sample: { [ProcessCPUTick(pid: 7, name: "a", nanoseconds: 1), ProcessCPUTick(pid: 8, name: "b", nanoseconds: 1)] },
            loadSample: { nil })
        let task = Task { await model.run() }
        for _ in 0..<200 where model.isWarmingUp { try? await Task.sleep(for: .milliseconds(5)) }
        task.cancel()

        let line = StatusLine.cpu(model: model)
        #expect(line.status == "실시간으로 보는 중")
        #expect(line.count == "프로그램 \(model.usage.count)개")
    }

    // TC-7
    @Test("상태바를 읽는다고 디스크 맵 모델을 만들지 않는다")
    func statusLineDoesNotCreateDiskMap() {
        var created = 0
        let app = AppModel(makeDiskMap: { created += 1; return DiskMapModel() },
                           needsFolderAccess: false)
        app.selected = .diskMap

        #expect(app.statusLine == StatusLine(status: "시작 전", count: "—", size: "—"))
        #expect(created == 0)
    }
}
