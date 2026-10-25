import Foundation

/// 시작점마다 마지막으로 다 읽은 공간 보기 트리.
///
/// 볼륨 전체는 몇 분이 걸린다. 다시 열 때마다 빈 진행 화면을 보게 하지 않으려고
/// 지난 결과를 남겨 두고 먼저 보여 준다. 트리는 깊이 4·1MB로 가지치기돼 있어
/// 수천 노드, 파일 하나에 수백 KB다.
///
/// 읽기·쓰기에 실패해도 던지지 않는다. 지난 결과는 있으면 좋은 것이지 없으면 안 되는 것이 아니다.
public struct DiskMapCache: Sendable {

    private struct Entry: Codable {
        let date: Date
        let tree: DiskUsageNode
    }

    private let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    /// 앱 지원 폴더 안. 캐시 폴더에 두지 않는다 — Sweep이 스스로 비우는 곳이 될 수 있다.
    public static var standard: DiskMapCache {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(filePath: NSTemporaryDirectory())
        return DiskMapCache(directory: base.appending(path: "Sweep/DiskMap", directoryHint: .isDirectory))
    }

    public func load(_ root: URL) -> (tree: DiskUsageNode, date: Date)? {
        guard let data = try? Data(contentsOf: file(for: root)),
              let entry = try? PropertyListDecoder().decode(Entry.self, from: data),
              // 파일 이름이 겹쳐도 다른 시작점의 트리를 보여 주지 않는다.
              entry.tree.url == root
        else { return nil }
        return (entry.tree, entry.date)
    }

    public func save(_ tree: DiskUsageNode, for root: URL, at date: Date = Date()) {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        guard let data = try? encoder.encode(Entry(date: date, tree: tree)) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: file(for: root), options: .atomic)
    }

    /// 경로를 그대로 파일 이름으로 쓴다(`/` 등은 퍼센트 인코딩). 이름이 너무 길면 뒤를 해시로 줄인다.
    private func file(for root: URL) -> URL {
        let path = root.standardizedFileURL.path
        var name = path.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "root"
        if name.count > 200 { name = String(name.prefix(180)) + "-\(Self.stableHash(path))" }
        return directory.appending(path: name + ".plist")
    }

    /// `hashValue`는 실행할 때마다 바뀐다. 다음 실행에서도 같은 파일을 찾아야 하므로 FNV-1a.
    private static func stableHash(_ text: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 { hash = (hash ^ UInt64(byte)) &* 0x100_0000_01b3 }
        return String(hash, radix: 16)
    }
}
