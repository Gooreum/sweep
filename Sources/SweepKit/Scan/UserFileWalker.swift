import Foundation

/// 사용자 폴더(`UserFolders.roots`)의 일반 파일을 훑는다. 큰 파일·중복 파일 스캐너가 함께 쓴다.
///
/// 두 스캐너가 같은 규칙으로 빼야 한다. 한쪽만 `node_modules`를 빼면
/// 같은 폴더가 큰 파일 목록에는 없고 중복 목록에는 수천 줄로 나온다.
enum UserFileWalker {

    struct File {
        let url: URL
        /// 디스크에서 실제로 차지하는 크기. 지우면 이만큼 돌아온다.
        let allocatedSize: Int64
        /// 내용의 길이. 중복 판정은 이것으로 묶는다 — 할당 크기는 압축·희소 파일에서 달라진다.
        let logicalSize: Int64
        let created: Date?
        let modified: Date?
    }

    private static let keys: Set<URLResourceKey> = [
        .isRegularFileKey, .isSymbolicLinkKey, .isDirectoryKey,
        .totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey,
        .contentModificationDateKey, .creationDateKey,
    ]

    /// iCloud에만 있고 이 Mac에는 자리표시자만 있는 파일의 플래그(`SF_DATALESS`).
    /// Darwin 모듈이 노출하지 않아 값을 직접 쓴다.
    static let datalessFlag: UInt32 = 0x4000_0000

    /// 이 Mac에 내용이 없는 파일인가.
    ///
    /// 크기는 크게 나오지만 디스크를 쓰지 않는다. 지워도 돌아오는 게 없고,
    /// 해시하려고 열면 **iCloud에서 내려받기가 시작된다.**
    static func isDataless(_ url: URL) -> Bool {
        (ProtectedPaths.fileFlags(of: url) ?? 0) & datalessFlag != 0
    }

    /// 루트 아래의 일반 파일 중 내용 길이가 `minimumSize` 이상인 것.
    ///
    /// 빼는 것: 숨김 파일, 번들 내부(`.app`·`.photoslibrary` — 안의 파일 하나만 지우면
    /// 번들이 깨진다), 의존성·빌드 폴더(`UserFolders.skippedDirectoryNames`),
    /// 심볼릭 링크(지워도 용량이 돌아오지 않는다), iCloud 자리표시자.
    ///
    /// `isDataless`는 테스트가 갈아끼운다 — 자리표시자 파일은 만들 수 없다.
    static func files(under root: URL, minimumSize: Int64,
                      isDataless: (URL) -> Bool = UserFileWalker.isDataless) -> [File] {
        guard let walker = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else { return [] }

        var found: [File] = []
        for case let url as URL in walker {
            guard let v = try? url.resourceValues(forKeys: keys) else { continue }

            if v.isDirectory == true {
                // 짝이 맞는 프로젝트 산출물(`target`·`build` 등)도 내려가지 않는다 —
                // 개발 프로젝트 탭이 통째로 보여주므로 한번에 찾기에서 두 번 세지 않게.
                if UserFolders.skippedDirectoryNames.contains(url.lastPathComponent)
                    || ProjectArtifactRule.match(url) != nil {
                    walker.skipDescendants()
                }
                continue
            }
            guard v.isSymbolicLink != true, v.isRegularFile == true,
                  let length = v.fileSize, Int64(length) >= minimumSize,
                  // 크기를 넘는 것만 플래그를 읽는다. 파일마다 lstat하면 홈 전체에서 비싸다.
                  !isDataless(url)
            else { continue }

            found.append(File(
                url: url,
                allocatedSize: Int64(v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? 0),
                logicalSize: Int64(length),
                created: v.creationDate,
                modified: v.contentModificationDate))
        }
        return found
    }
}
