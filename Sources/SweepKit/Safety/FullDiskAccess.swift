import Foundation

/// 전체 디스크 접근이 켜져 있는가.
///
/// **묻지 않고 재는 유일한 방법은 보호된 파일을 실제로 열어 보는 것이다.**
/// `isReadableFile`은 POSIX 권한만 보고 TCC를 반영하지 않는다 —
/// `FolderReadability`에서 겪은 것과 같은 함정이다.
///
/// 재는 대상은 TCC 데이터베이스 자신이다. 전체 디스크 접근이 있어야만 열리고,
/// **없다고 프롬프트가 뜨지도 않는다** — 조용히 실패한다. 재는 행위가 사용자를
/// 방해하면 안 되므로 이 성질이 중요하다.
///
/// 이 스위치 하나가 "다른 앱의 데이터에 접근하려고 합니다"를 통째로 없앤다.
/// 그 물음은 앱 폴더마다 따로 뜨기 때문에 한 번 허용으로는 끝나지 않는다.
public enum FullDiskAccess {

    /// 전체 디스크 접근이 있어야만 열리는 파일.
    static var probe: URL {
        Sandbox.userHome.appending(path: "Library/Application Support/com.apple.TCC/TCC.db")
    }

    public static var isGranted: Bool { canRead(probe) }

    /// 확인용 파일에 닿을 수 있는가. 샌드박스에서는 그 폴더 권한이 없으면 전체 디스크 접근과
    /// 무관하게 못 읽는다 — 그때 "꺼짐"이라고 하면 켜 놓은 사용자에게도 켜라고 한다.
    static func isMeasurable(sandboxed: Bool, granted: [URL]) -> Bool {
        !sandboxed || granted.contains { probe.isSameOrDescendant(of: $0) }
    }

    /// 꺼진 것이 **확실할 때만** true. 잴 수 없으면 폴더 허용을 먼저 안내한다
    /// (`Feature.permissionNeeds`).
    ///
    /// 샌드박스에서도 의미가 있다. `~/.Trash`는 폴더를 허용해도 이것 없이는 열리지 않는다(실측).
    public static func isMissing(sandboxed: Bool = Sandbox.isActive,
                                 granted: [URL] = FolderAccess.shared.urls) -> Bool {
        isMeasurable(sandboxed: sandboxed, granted: granted) && !isGranted
    }

    /// 한 바이트만 읽어 본다. 100KB짜리를 통째로 들 이유가 없다.
    ///
    /// **읽은 결과가 아니라 던졌는지를 본다.** 빈 파일은 `read`가 nil을 돌려주는데
    /// 그건 "못 읽는다"가 아니라 "읽을 것이 없다"다 — 실측에서 0바이트 파일이
    /// 못 읽는 것으로 판정돼 걸렸다. 권한이 없으면 애초에 `FileHandle`이 던진다.
    static func canRead(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        do {
            _ = try handle.read(upToCount: 1)
            return true
        } catch {
            return false
        }
    }
}
