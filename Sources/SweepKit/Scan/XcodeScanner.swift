import Foundation

/// Xcode·시뮬레이터가 남기는 산출물을 찾는다.
public struct XcodeScanner: CleanupScanner {
    public let category: ScanCategory = .xcode

    /// 홈 디렉토리. 테스트에서 가짜 트리를 주입하기 위해 열어 둔다 —
    /// 실제 홈에 의존하면 Xcode 설치 여부에 따라 결과가 달라진다.
    private let home: URL

    public init(home: URL = Sandbox.userHome) {
        self.home = home
    }

    /// 안전도는 "다시 만들 수 있는가"로 갈린다.
    /// DerivedData는 빌드하면 되살아나지만, Archives는 심사 제출본이라 대체물이 없다.
    private struct Target {
        let path: String
        let safety: SafetyLevel
        let detail: String
        /// true면 디렉토리 자체가 아니라 하위 항목 하나하나가 후보다(프로젝트별 표시).
        let expandsChildren: Bool
    }

    private static let targets: [Target] = [
        .init(path: "Library/Developer/Xcode/DerivedData",
              safety: .safe, detail: "빌드하면 다시 생성됩니다", expandsChildren: true),
        // 이 기계에서는 실측 0B다. 용량을 먹는 dyld 공유 캐시는
        // `/Library/Developer/CoreSimulator/Caches`(root 소유, 11G)로 옮겨가 홈 쪽은 비어 있다.
        // 그래도 남겨 둔다 — Xcode 14 이하는 아직 여기에 쌓고, 비어 있으면 size 0으로 걸러진다.
        .init(path: "Library/Developer/CoreSimulator/Caches",
              safety: .safe, detail: "시뮬레이터 캐시입니다", expandsChildren: false),
        .init(path: "Library/Developer/CoreSimulator/Temp",
              safety: .safe, detail: "시뮬레이터 임시 파일입니다", expandsChildren: false),
        .init(path: "Library/Developer/Xcode/iOS DeviceSupport",
              safety: .caution, detail: "기기를 다시 연결하면 내려받습니다", expandsChildren: true),
        .init(path: "Library/Developer/XCTestDevices",
              safety: .caution, detail: "테스트용 시뮬레이터 기기입니다", expandsChildren: false),
        .init(path: "Library/Developer/DVTDownloads",
              safety: .caution, detail: "Xcode가 내려받은 구성요소입니다", expandsChildren: false),
        .init(path: "Library/Developer/Xcode/Archives",
              safety: .danger, detail: "앱 심사 제출본 — 지우면 복구할 수 없습니다", expandsChildren: true),
    ]

    /// 실측 1.0초. 1초 안에 끝나므로 중간 보고 없이 완료 시점만 알린다.
    public var progressWeight: Double { 1.0 }

    /// 펼치기는 디렉토리만 대상으로 한다.
    ///
    /// `Devices` 아래에는 기기 폴더와 함께 `device_set.plist`가 있다. 기기 목록 인덱스라
    /// 지우면 CoreSimulator가 기기를 잃는다. 12KB뿐이라 목록 맨 아래에 묻히지만
    /// "전체 선택 → 삭제"에는 함께 딸려간다. `expandsChildren`이 뜻하는 것은
    /// 프로젝트별·기기별로 펼치는 것이므로 파일은 애초에 후보가 아니다.
    private func expandedChildren(of root: URL) -> [URL] {
        children(of: root).filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
        }
    }

    public func scan() async -> [CleanupItem] {
        targetItems() + simulatorDeviceItems()
    }

    private func targetItems() -> [CleanupItem] {
        Self.targets.flatMap { target -> [CleanupItem] in
            let root = home.appending(path: target.path)
            let urls = target.expandsChildren ? expandedChildren(of: root) : [root]
            return urls.compactMap { url in
                let size = DirectorySize.bytes(at: url)
                // 크기 0은 대상이 없거나 비어 있다는 뜻이다. 목록에 올릴 이유가 없다.
                guard size > 0 else { return nil }
                return CleanupItem(url: url, size: size, category: .xcode,
                                   safety: target.safety, detail: target.detail)
            }
        }
    }

    /// 시뮬레이터 기기를 하나씩 후보로 올린다. 기기 하나가 2~3GB고 여러 대라
    /// 한 덩어리로 보여주면 무엇을 버리는지 고를 수 없다.
    ///
    /// `Target`에 넣지 않고 따로 두는 이유는 기기에만 필요한 규칙이 둘 있어서다.
    ///
    /// 하나는 **부팅 중인 기기를 빼는 것**이다. `Remover`는 휴지통으로 옮기는데(이름 바꾸기)
    /// 그래서 오류가 나지 않는다. 그런데 CoreSimulator는 옛 경로의 파일 기술자를 계속
    /// 붙들고 있어 시뮬레이터만 깨지고, 용량은 휴지통을 비우기 전까지 회수되지 않는다.
    /// 실패로 보고되지 않으니 안전 등급 배지로는 막을 수 없다 — 목록에서 빼야 한다.
    ///
    /// 다른 하나는 **이름을 보여주는 것**이다. 폴더 이름이 UUID라 그것만으로는
    /// 어느 기기인지 알 수 없다.
    ///
    /// `simctl`은 부르지 않는다. 샌드박스에서 프로세스를 띄울 수 없고, 필요한 값은
    /// 전부 기기 폴더 안 `device.plist`에 있다.
    private func simulatorDeviceItems() -> [CleanupItem] {
        let devices = home.appending(path: "Library/Developer/CoreSimulator/Devices")
        return expandedChildren(of: devices).compactMap { url in
            // `device.plist`가 없으면 기기가 아니다. `device_set.plist`(기기 목록 인덱스)도
            // 파일이라 `expandedChildren`에서 이미 빠지지만, 여기서 한 번 더 걸러진다.
            guard let device = Self.device(at: url), device.state == Self.shutdownState
            else { return nil }

            let size = DirectorySize.bytes(at: url)
            guard size > 0 else { return nil }

            return CleanupItem(url: url, size: size, category: .xcode,
                               safety: .caution,
                               detail: "\(device.name) · \(device.runtime) — "
                                     + "설치한 앱과 설정이 사라집니다")
        }
    }

    /// Shutdown. 2(Booting)·3(Booted)·4(Shutting Down)은 쓰는 중이라 건드리지 않는다.
    private static let shutdownState = 1

    private static func device(at url: URL) -> (name: String, runtime: String, state: Int)? {
        guard let data = try? Data(contentsOf: url.appending(path: "device.plist")),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil)
                  as? [String: Any],
              let name = plist["name"] as? String,
              let state = plist["state"] as? Int
        else { return nil }
        return (name, Self.shortRuntime(plist["runtime"] as? String), state)
    }

    /// `com.apple.CoreSimulator.SimRuntime.iOS-26-2` → `iOS 26.2`
    private static func shortRuntime(_ identifier: String?) -> String {
        guard let tail = identifier?.split(separator: ".").last else { return "알 수 없는 런타임" }
        let parts = tail.split(separator: "-")
        guard let platform = parts.first, parts.count > 1 else { return String(tail) }
        return "\(platform) \(parts.dropFirst().joined(separator: "."))"
    }
}
