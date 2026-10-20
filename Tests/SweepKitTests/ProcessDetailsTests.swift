import Darwin
import Foundation
import Testing
@testable import SweepKit

@Suite("ProcessDetailsReader")
struct ProcessDetailsTests {

    @Test("자기 자신은 이름·시작 시각·메모리·내 계정이 채워진다")
    func readsSelf() throws {
        let details = try #require(ProcessDetailsReader.read(pid: getpid()))
        #expect(details.pid == getpid())
        #expect(details.isMine)
        #expect(details.startedAt != nil)
        #expect((details.memoryBytes ?? 0) > 0)
        #expect((details.threads ?? 0) > 0)
        #expect(!details.name.isEmpty)
    }

    @Test("자기 자신의 부모 사슬은 가까운 부모부터이고 launchd를 넣지 않는다")
    func ancestorsStopBeforeLaunchd() throws {
        let details = try #require(ProcessDetailsReader.read(pid: getpid()))
        #expect(!details.launchedBy.contains { $0.pid <= 1 })
        #expect(details.launchedBy.count <= ProcessDetailsReader.maxAncestors)
        #expect(details.launchedBy.first?.pid == getppid())
    }

    @Test("말이 안 되는 시작 시각(1976년, 미래, 0)은 모른다고 한다")
    func implausibleStartDates() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(ProcessDetailsReader.startDate(seconds: 196_000_000, now: now) == nil)
        #expect(ProcessDetailsReader.startDate(seconds: 0, now: now) == nil)
        #expect(ProcessDetailsReader.startDate(seconds: 1_900_000_000, now: now) == nil)
        #expect(ProcessDetailsReader.startDate(seconds: 1_700_000_000, now: now)
            == Date(timeIntervalSince1970: 1_700_000_000))
    }

    @Test("없는 pid는 nil이다")
    func missingPID() {
        #expect(ProcessDetailsReader.read(pid: 999_999) == nil)
    }

    @Test("부모가 서로를 가리켜도 사슬이 무한히 돌지 않는다")
    func cyclicAncestors() {
        var a = kinfo_proc(), b = kinfo_proc()
        a.kp_proc.p_pid = 100; a.kp_eproc.e_ppid = 200
        b.kp_proc.p_pid = 200; b.kp_eproc.e_ppid = 100
        let chain = ProcessDetailsReader.ancestors(of: 100, table: [100: a, 200: b])
        #expect(chain.map(\.pid) == [200])
    }

    @Test("부모가 이미 끝났다면 거기서 멈춘다")
    func missingParent() {
        var a = kinfo_proc()
        a.kp_proc.p_pid = 100; a.kp_eproc.e_ppid = 300
        #expect(ProcessDetailsReader.ancestors(of: 100, table: [100: a]).isEmpty)
    }

    @Test("실행 명령을 argc만큼 읽고 경로 뒤 널 패딩을 건너뛴다")
    func parsesArguments() {
        var bytes: [UInt8] = []
        withUnsafeBytes(of: Int32(3)) { bytes += $0 }
        func add(_ text: String, nulls: Int = 1) {
            bytes += Array(text.utf8)
            bytes += [UInt8](repeating: 0, count: nulls)
        }
        add("/usr/bin/node", nulls: 3)
        add("node")
        add("/Users/a/server.js")
        add("--port")
        add("PATH=/usr/bin")   // 환경변수는 읽지 않는다
        #expect(ProcessDetailsReader.parseArguments(bytes) == ["node", "/Users/a/server.js", "--port"])
    }

    @Test("argc가 0이거나 너무 짧으면 nil이다")
    func rejectsBadArguments() {
        #expect(ProcessDetailsReader.parseArguments([]) == nil)
        #expect(ProcessDetailsReader.parseArguments([0, 0, 0, 0, 0]) == nil)
    }

    @Test("가장 바깥 .app을 찾고 폴더 이름을 이름으로 쓴다")
    func enclosingOutermostApp() {
        let app = ProcessDetailsReader.enclosingApp(
            of: "/Applications/Nonexistent Tool.app/Contents/Frameworks/Helper.app/Contents/MacOS/Helper")
        #expect(app?.name == "Nonexistent Tool")
        #expect(app?.path == "/Applications/Nonexistent Tool.app")
    }

    @Test("앱 안이 아니면 nil이다")
    func notInApp() {
        #expect(ProcessDetailsReader.enclosingApp(of: "/usr/bin/yes") == nil)
    }

    @Test("실제로 설치된 앱은 버전을 읽는다")
    func readsInstalledAppVersion() throws {
        let app = try #require(ProcessDetailsReader.enclosingApp(
            of: "/System/Applications/Utilities/Activity Monitor.app/Contents/MacOS/Activity Monitor"))
        #expect(!app.name.isEmpty)
        #expect(app.version != nil)
    }
}
