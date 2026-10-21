import Darwin
import Foundation

/// 프로그램을 띄운 쪽. 가까운 부모부터 `ProcessDetails.launchedBy`에 줄지어 담긴다.
public struct ProcessAncestor: Sendable, Equatable {
    public let pid: pid_t
    public let name: String

    public init(pid: pid_t, name: String) {
        self.pid = pid
        self.name = name
    }
}

/// 실행 파일이 들어 있는 `.app`. 이름·버전은 그 앱의 `Info.plist`에서 읽는다.
public struct AppIdentity: Sendable, Equatable {
    public let name: String
    public let version: String?
    public let path: String

    public init(name: String, version: String?, path: String) {
        self.name = name
        self.version = version
        self.path = path
    }
}

/// CPU 표에서 고른 **한 프로그램**의 자세한 정보.
///
/// 2초마다 500개 전부에 만들지 않는다 — 고른 하나에만 읽는다.
/// 값마다 nil이 될 수 있다: 샌드박스는 내 계정 소유가 아닌 프로세스의 일부 값을
/// 막는다. **못 읽은 것과 0인 것은 다르므로** 못 읽으면 nil이고 화면은 그 줄을 숨긴다.
public struct ProcessDetails: Sendable, Equatable {
    public let pid: pid_t
    public let name: String
    /// 내 계정이 띄운 프로그램인가. false면 macOS 시스템이나 다른 계정이다.
    public let isMine: Bool
    public let startedAt: Date?
    /// 가까운 부모부터. `launchd`(pid 1) 앞에서 멈춘다.
    public let launchedBy: [ProcessAncestor]
    /// 지금 메모리에 올라와 있는 크기.
    public let memoryBytes: UInt64?
    /// 일하는 줄기(스레드) 수.
    public let threads: Int?
    /// 실행할 때 준 명령 전체. 내 계정 프로세스만 읽힌다.
    public let arguments: [String]?
    public let executablePath: String?
    public let app: AppIdentity?

    /// 사전에 있는 프로그램이면 쉬운 설명. 없으면 nil — 설명을 지어내지 않는다.
    public var known: KnownProcess? { KnownProcess.match(name: name) }

    public init(
        pid: pid_t, name: String, isMine: Bool, startedAt: Date? = nil,
        launchedBy: [ProcessAncestor] = [], memoryBytes: UInt64? = nil, threads: Int? = nil,
        arguments: [String]? = nil, executablePath: String? = nil, app: AppIdentity? = nil
    ) {
        self.pid = pid
        self.name = name
        self.isMine = isMine
        self.startedAt = startedAt
        self.launchedBy = launchedBy
        self.memoryBytes = memoryBytes
        self.threads = threads
        self.arguments = arguments
        self.executablePath = executablePath
        self.app = app
    }
}

extension ProcessDetails {

    /// "11일 11시간째", "3시간 20분째", "5분째", "방금 켜졌어요". 모르면 nil.
    public func runningText(now: Date = Date()) -> String? {
        guard let startedAt else { return nil }
        let minutes = max(0, Int(now.timeIntervalSince(startedAt) / 60))
        let days = minutes / 1440, hours = minutes % 1440 / 60, rest = minutes % 60
        if days > 0 { return String(localized: "\(days)일 \(hours)시간째") }
        if hours > 0 { return String(localized: "\(hours)시간 \(rest)분째") }
        if rest > 0 { return String(localized: "\(rest)분째") }
        return String(localized: "방금 켜졌어요")
    }

    /// "182.5 MB". 모르면 nil.
    public var memoryText: String? {
        memoryBytes.map { ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .memory) }
    }

    /// 가까운 부모부터 먼 부모 순서를 사람이 읽는 순서(먼 쪽 › 가까운 쪽)로 뒤집는다.
    /// "터미널 › zsh › xcodebuild". 부모가 launchd뿐이면 nil.
    public var launchedByText: String? {
        launchedBy.isEmpty ? nil : launchedBy.reversed().map(\.name).joined(separator: " › ")
    }

    /// 실행할 때 준 명령 한 줄. 사용자 폴더는 `~`로 줄인다.
    public var commandLineText: String? {
        guard let arguments, !arguments.isEmpty else { return nil }
        let home = NSHomeDirectory()
        return arguments.map { $0.hasPrefix(home) ? "~" + $0.dropFirst(home.count) : $0 }
            .joined(separator: " ")
    }
}

public enum ProcessDetailsReader {

    /// 부모를 몇 단계까지 거슬러 오를지. 터미널 › zsh › xcodebuild 정도면 충분하고,
    /// 더 길어지면 줄이 화면 밖으로 나간다.
    static let maxAncestors = 6

    /// `pid` 하나의 자세한 정보. 이미 끝난 프로세스면 nil.
    public static func read(pid: pid_t) -> ProcessDetails? {
        let table = Dictionary(
            ProcessCPUSampler.kernelProcessTable().map { ($0.kp_proc.p_pid, $0) },
            uniquingKeysWith: { first, _ in first })
        return read(pid: pid, table: table)
    }

    static func read(pid: pid_t, table: [pid_t: kinfo_proc]) -> ProcessDetails? {
        guard let info = table[pid] else { return nil }

        let path = ProcessCPUSampler.executablePath(of: pid)
        var task = proc_taskinfo()
        let taskSize = Int32(MemoryLayout<proc_taskinfo>.size)
        let hasTask = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &task, taskSize) == taskSize

        return ProcessDetails(
            pid: pid,
            name: name(of: pid, path: path, info: info),
            isMine: info.kp_eproc.e_ucred.cr_uid == getuid(),
            startedAt: startDate(of: info),
            launchedBy: ancestors(of: pid, table: table),
            memoryBytes: hasTask ? task.pti_resident_size : nil,
            threads: hasTask ? Int(task.pti_threadnum) : nil,
            arguments: arguments(of: pid),
            executablePath: path,
            app: path.flatMap(enclosingApp(of:)))
    }

    // MARK: - 부모 사슬

    /// `ppid`를 따라 거슬러 오른다. 순환이나 끊어진 사슬에서 멈춘다 —
    /// pid는 재사용되므로 부모가 이미 끝났다면 엉뚱한 프로세스를 가리킬 수 있다.
    static func ancestors(of pid: pid_t, table: [pid_t: kinfo_proc]) -> [ProcessAncestor] {
        var result: [ProcessAncestor] = []
        var seen: Set<pid_t> = [pid]
        var current = pid
        while result.count < maxAncestors,
              let info = table[current],
              case let parent = info.kp_eproc.e_ppid,
              parent > 1, !seen.contains(parent),
              let parentInfo = table[parent] {
            seen.insert(parent)
            let path = ProcessCPUSampler.executablePath(of: parent)
            result.append(ProcessAncestor(
                pid: parent, name: name(of: parent, path: path, info: parentInfo)))
            current = parent
        }
        return result
    }

    /// 실행 파일 이름 → `proc_name` → 커널이 적어 둔 16자 이름 순으로 물러선다.
    /// 경로는 내 계정 소유만 읽히므로 시스템 프로세스는 뒤의 둘로 떨어진다.
    private static func name(of pid: pid_t, path: String?, info: kinfo_proc) -> String {
        if let path, let name = ProcessCPUSampler.displayName(forPath: path) { return name }
        var buffer = [CChar](repeating: 0, count: 256)
        if proc_name(pid, &buffer, UInt32(buffer.count)) > 0 {
            let name = ProcessCPUSampler.string(from: buffer)
            if !name.isEmpty { return name }
        }
        var comm = info.kp_proc.p_comm
        let fallback = withUnsafeBytes(of: &comm) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
        return fallback.isEmpty ? "pid \(pid)" : fallback
    }

    private static func startDate(of info: kinfo_proc) -> Date? {
        startDate(seconds: Int(info.kp_proc.p_un.__p_starttime.tv_sec), now: Date())
    }

    /// 시작 시각이 말이 되는 값일 때만 믿는다. 샌드박스에서 시스템 프로세스(WindowServer)는
    /// 이 칸이 1976년으로 온다(실측) — 그대로 보여주면 "17000일째 돌고 있어요"가 된다.
    /// 컴퓨터가 존재하기 전이거나 미래면 모른다고 한다.
    static func startDate(seconds: Int, now: Date) -> Date? {
        let earliest = 978_307_200   // 2001-01-01
        guard seconds >= earliest else { return nil }
        let date = Date(timeIntervalSince1970: TimeInterval(seconds))
        return date <= now ? date : nil
    }

    // MARK: - 실행 명령

    /// `KERN_PROCARGS2`. 앞 4바이트가 인자 개수(argc), 그 뒤로 실행 파일 경로,
    /// 널 패딩, 그리고 인자들이 널로 끝나며 이어진다.
    static func arguments(of pid: pid_t) -> [String]? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else {
            return nil
        }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0 else { return nil }
        return parseArguments(Array(buffer.prefix(size)))
    }

    /// 순수 함수라 샌드박스 없이 테스트한다.
    static func parseArguments(_ bytes: [UInt8]) -> [String]? {
        let head = MemoryLayout<Int32>.size
        guard bytes.count > head else { return nil }
        let argc = bytes.prefix(head).withUnsafeBytes { $0.loadUnaligned(as: Int32.self) }
        guard argc > 0 else { return nil }

        var index = head
        // 실행 파일 경로를 건너뛴다.
        while index < bytes.count, bytes[index] != 0 { index += 1 }
        // 그 뒤의 널 패딩을 건너뛴다.
        while index < bytes.count, bytes[index] == 0 { index += 1 }

        var result: [String] = []
        while result.count < Int(argc), index < bytes.count {
            var end = index
            while end < bytes.count, bytes[end] != 0 { end += 1 }
            result.append(String(decoding: bytes[index..<end], as: UTF8.self))
            index = end + 1
        }
        return result.isEmpty ? nil : result
    }

    // MARK: - 속한 앱

    /// 실행 파일 경로에서 **가장 바깥** `.app`을 찾는다. `Google Chrome Helper.app`은
    /// `Google Chrome.app` 안에 들어 있고, 사용자가 아는 이름은 바깥쪽이다.
    static func enclosingApp(of path: String) -> AppIdentity? {
        let parts = path.split(separator: "/", omittingEmptySubsequences: true)
        guard let index = parts.firstIndex(where: { $0.hasSuffix(".app") }) else { return nil }
        let appPath = "/" + parts[...index].joined(separator: "/")

        let bundle = Bundle(url: URL(filePath: appPath))
        let fileName = String(parts[index].dropLast(".app".count))
        // 표시 이름이 없으면 폴더 이름을 쓴다. 이름 없는 앱은 없다.
        let name = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? fileName
        let version = bundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return AppIdentity(name: name, version: version, path: appPath)
    }
}
