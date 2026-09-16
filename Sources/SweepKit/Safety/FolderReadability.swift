import Foundation

/// 폴더를 읽을 수 있는지. **없는 것과 막힌 것을 구분한다.**
///
/// `children(of:)`는 둘 다 빈 배열로 돌려준다(`try?`). 그래서 권한이 막혀도
/// 화면에는 "정리할 항목 없음"만 뜨고, 사용자는 무엇이 잘못됐는지 알 수 없었다.
///
/// `~/Downloads`·`~/Desktop`·`~/Documents`는 entitlement가 있어도 macOS가 TCC 프롬프트를
/// 띄운다. 거부하면 앱은 **다시 물어볼 수 없다** — 시스템 설정에서만 되돌릴 수 있다.
/// 샌드박스 밖에서도 마찬가지라, 직접 배포본도 같은 상황을 만난다.
public enum FolderReadability: Sendable, Equatable {
    /// 읽을 수 있다.
    case readable
    /// 폴더는 있는데 읽지 못한다 — TCC 거부이거나 허락이 빠졌다.
    case denied
    /// 폴더 자체가 없다. 그 도구를 안 쓰는 것이므로 알릴 일이 아니다.
    case missing

    /// 사용자에게 알려야 하는 상태인가.
    public var needsAttention: Bool { self == .denied }

    /// 실제로 열어 본다. 판정을 위해 한 번 읽는 비용을 치른다.
    ///
    /// `isReadableFile(atPath:)`는 쓰지 않는다 — POSIX 권한만 보고 TCC를 반영하지 않아서
    /// 막힌 폴더에도 `true`를 돌려준다. 던지는지로 판정해야 실제 상태를 안다.
    public static func check(_ url: URL,
                             fileManager: FileManager = .default) -> FolderReadability {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue
        else { return .missing }

        do {
            _ = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            return .readable
        } catch {
            return .denied
        }
    }
}

extension CleanupScope {

    /// 이 곳을 지금 읽을 수 있는가.
    ///
    /// 목록은 허용 루트에서 유도되지만(`CleanupScope.all`), 그 목록에 있다고
    /// 읽을 수 있는 것은 아니다. 권한은 실행 중에 막히거나 풀린다.
    public var readability: FolderReadability { FolderReadability.check(url) }

    /// "보는 곳" 전체의 읽기 상태. 화면이 줄마다 `check`를 부르면
    /// 렌더마다 디스크를 두드리므로, 한 번에 만들어 들고 있는다.
    public static func readabilityMap(of scopes: [CleanupScope])
        -> [String: FolderReadability] {
        var result: [String: FolderReadability] = [:]
        for scope in scopes { result[scope.id] = scope.readability }
        return result
    }
}
