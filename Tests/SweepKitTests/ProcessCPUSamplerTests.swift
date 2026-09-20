import Testing
import Foundation
@testable import SweepKit

/// 실제 프로세스에서 누적 CPU 시간을 읽어 오는 경로.
///
/// 가짜를 끼울 수 없는 유일한 층이다 — syscall이 실제로 무엇을 주는지가
/// 이 기능의 전부이므로, 이 머신의 진짜 프로세스로 확인한다.
@Suite("ProcessCPUSampler")
struct ProcessCPUSamplerTests {

    // TC-1
    @Test("프로세스를 하나도 못 읽으면 안 된다")
    func tickIsNotEmpty() {
        // 목록을 proc_listpids로 되돌리면 샌드박스에서 0개가 되는데,
        // 여기서는 통과해 버린다. 샌드박스 검증은 e2e가 맡는다.
        #expect(!ProcessCPUSampler.tick().isEmpty)
    }

    // TC-2
    @Test("적어도 자기 자신은 목록에 있다")
    func tickIncludesSelf() {
        // 지금 이 테스트를 돌리고 있는 프로세스다. 이게 빠지면 수집이 깨진 것이다.
        let pids = Set(ProcessCPUSampler.tick().map(\.pid))
        #expect(pids.contains(getpid()))
    }

    // TC-3
    @Test("이름이 빈 프로세스가 하나도 없다")
    func everyTickIsNamed() {
        // 이름은 3단 폴백이라 어떤 경우에도 빈 문자열이 나오면 안 된다 —
        // 화면에 빈 줄이 그려진다.
        let unnamed = ProcessCPUSampler.tick().filter(\.name.isEmpty)
        #expect(unnamed.isEmpty, "이름 없는 프로세스 \(unnamed.map(\.pid))")
    }

    // TC-4
    @Test("자기 자신은 CPU를 쓴 적이 있다")
    func selfHasAccumulatedTime() throws {
        let mine = try #require(ProcessCPUSampler.tick().first { $0.pid == getpid() })
        // 지금 돌고 있으므로 누적값이 0일 수 없다
        #expect(mine.nanoseconds > 0)
    }

    // TC-5
    @Test("누적값은 두 번 재도 줄지 않는다")
    func accumulatedTimeNeverShrinks() throws {
        let first = try #require(ProcessCPUSampler.tick().first { $0.pid == getpid() })
        // 일부러 조금 태운다. 아무것도 안 하면 두 값이 같을 수 있다.
        var sink = 0
        for index in 0..<2_000_000 { sink &+= index }
        #expect(sink != 0)
        let second = try #require(ProcessCPUSampler.tick().first { $0.pid == getpid() })

        // 누적 CPU 시간이 줄면 환산에서 pid 재사용으로 오인해 목록에서 빠진다
        #expect(second.nanoseconds >= first.nanoseconds)
    }

    // TC-6
    @Test("두 번 재서 환산하면 음수 사용률이 나오지 않는다")
    func realSamplesConvertWithoutNegatives() async {
        let before = ProcessCPUSampler.tick()
        try? await Task.sleep(for: .milliseconds(300))
        let usage = ProcessUsage.compute(
            from: before, to: ProcessCPUSampler.tick(), over: .milliseconds(300))

        // 실제 값으로도 환산 규칙이 지켜지는지 본다
        #expect(usage.allSatisfy { $0.percent > 0 })
        #expect(usage == usage.sorted {
            $0.percent == $1.percent ? $0.pid < $1.pid : $0.percent > $1.percent
        })
    }

    // TC-7
    @Test("pid가 0 이하인 항목이 섞이지 않는다")
    func noBogusIdentifiers() {
        // sysctl 버퍼의 남은 자리는 0으로 초기화돼 있어, 채워진 만큼만
        // 읽지 않으면 pid 0짜리 껍데기가 목록에 들어온다.
        #expect(ProcessCPUSampler.tick().allSatisfy { $0.pid > 0 })
    }

    // TC-9
    @Test("코어를 꽉 채운 프로세스가 100%로 잡힌다")
    func busyProcessReadsAsFullCore() async throws {
        // **이 TC가 이 파일에서 제일 중요하다.** `proc_pidinfo`가 주는 누적 시간은
        // 나노초가 아니라 Mach 절대시간이라, 환산을 빼먹으면 41배 작게 나온다 —
        // 실제로 코어를 꽉 채운 프로세스가 2.4%로 찍혔고 나머지 TC는 전부 통과했다.
        // 값이 "그럴듯한지"는 묻지 않으면 알 수 없다.
        let busy = Process()
        busy.executableURL = URL(filePath: "/bin/sh")
        busy.arguments = ["-c", "while :; do :; done"]
        try busy.run()
        defer { busy.terminate() }

        // 실제로 돌기 시작할 틈을 준다
        try await Task.sleep(for: .milliseconds(200))

        let interval = Duration.seconds(1)
        let before = ProcessCPUSampler.tick()
        try await Task.sleep(for: interval)
        let usage = ProcessUsage.compute(
            from: before, to: ProcessCPUSampler.tick(), over: interval)

        let mine = try #require(usage.first { $0.pid == busy.processIdentifier },
                                "바쁜 프로세스가 목록에 없다")
        // 다른 일이 끼어들 수 있으니 폭을 넉넉히 둔다.
        // 41배 어긋남은 이 폭을 한참 벗어나므로 그래도 잡힌다.
        #expect(mine.percent > 80, "\(mine.percent)% — 너무 낮다")
        #expect(mine.percent < 130, "\(mine.percent)% — 너무 높다")
    }

    // TC-8
    @Test("경로를 읽은 프로세스는 이름이 경로의 마지막 조각이다")
    func namedByExecutablePath() throws {
        let ticks = ProcessCPUSampler.tick()
        let withPath = try #require(ticks.first { $0.executablePath != nil })

        // p_comm(16자 잘림)이 아니라 경로에서 이름을 뽑는지 확인한다
        let expected = URL(filePath: try #require(withPath.executablePath)).lastPathComponent
        #expect(withPath.name == expected)
    }
}
