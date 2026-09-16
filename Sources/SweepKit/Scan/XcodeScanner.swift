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
        .init(path: "Library/Developer/CoreSimulator/Caches",
              safety: .safe, detail: "시뮬레이터 캐시입니다", expandsChildren: false),
        .init(path: "Library/Developer/CoreSimulator/Temp",
              safety: .safe, detail: "시뮬레이터 임시 파일입니다", expandsChildren: false),
        // 기기 하나가 2~3GB다. 통째로 묶으면 무엇을 지우는지 알 수 없어 기기별로 펼친다.
        // 지우면 그 시뮬레이터에 설치한 앱과 설정이 사라진다. 기기 자체는 Xcode가 다시 만든다.
        .init(path: "Library/Developer/CoreSimulator/Devices",
              safety: .caution, detail: "시뮬레이터에 설치한 앱과 설정이 사라집니다",
              expandsChildren: true),
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
}
