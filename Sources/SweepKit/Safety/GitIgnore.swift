import Foundation

/// 폴더 이름이 프로젝트의 `.gitignore`에 적혀 있는가.
///
/// `dist`·`build`·`vendor`는 커밋된 결과물이거나 직접 만든 파일일 수 있어서, 이름과 설정 파일
/// 짝만으로는 지워도 되는지 알 수 없다. 저장소가 "이건 만들어지는 것"이라고 적어 둔 것만 믿는다.
/// 샌드박스에서 git을 실행할 수 없어 파일을 직접 읽는다.
///
/// **모르면 "적혀 있지 않다"로 본다.** 와일드카드(`dist*`)나 하위 경로(`dist/foo`)는 해석하지
/// 않는다 — 잘못 읽어 지우는 쪽이 못 찾는 쪽보다 훨씬 나쁘다.
enum GitIgnore {

    /// 위로 올라가며 볼 단계 수. 모노레포의 하위 패키지까지 닿으면 충분하다.
    static let maxLevels = 8
    /// 이보다 큰 `.gitignore`는 읽지 않는다.
    static let maxBytes = 256 * 1024

    /// `name` 폴더가 `project`부터 위로 올라가며 만나는 `.gitignore`에 적혀 있는가.
    ///
    /// 모노레포의 하위 패키지는 루트의 `.gitignore`가 정하므로 위쪽도 본다.
    /// `.git`이 있는 폴더(저장소 루트)까지만 올라가고 그 위는 보지 않는다.
    static func lists(_ name: String, from project: URL) -> Bool {
        var directory = project
        for level in 0..<maxLevels {
            if let lines = lines(of: directory.appending(path: ".gitignore")),
               matches(name: name, lines: lines, anchoredHere: level == 0) {
                return true
            }
            if exists(directory.appending(path: ".git")) { return false }
            let parent = directory.deletingLastPathComponent()
            if parent.path == directory.path { return false }
            directory = parent
        }
        return false
    }

    /// 한 파일의 줄들로 판정한다. 마지막으로 이름을 가리킨 줄이 이긴다(부정 `!`은 되돌린다).
    ///
    /// `anchoredHere`는 그 `.gitignore`가 `name`이 든 폴더 바로 위(프로젝트 폴더)에 있는가.
    /// `/name`처럼 앞에 `/`가 붙은 줄은 그때만 이 폴더를 가리킨다.
    static func matches(name: String, lines: [String], anchoredHere: Bool) -> Bool {
        var ignored = false
        for raw in lines {
            var line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }

            let negated = line.hasPrefix("!")
            if negated { line.removeFirst() }

            var anchored = false
            if line.hasPrefix("**/") {
                line.removeFirst(3)
            } else if line.hasPrefix("/") {
                line.removeFirst()
                anchored = true
            }
            if line.hasSuffix("/") { line.removeLast() }

            guard line == name else { continue }
            if anchored && !anchoredHere { continue }
            ignored = !negated
        }
        return ignored
    }

    private static func lines(of url: URL) -> [String]? {
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size <= maxBytes,
              let data = try? Data(contentsOf: url) else { return nil }
        return String(decoding: data, as: UTF8.self).components(separatedBy: .newlines)
    }

    private static func exists(_ url: URL) -> Bool {
        var info = stat()
        return lstat(url.path, &info) == 0
    }
}
