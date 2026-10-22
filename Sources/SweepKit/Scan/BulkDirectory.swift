import Darwin
import Foundation

/// 폴더 안 항목 하나. 크기 재기에 필요한 것만 담는다.
struct BulkEntry: Sendable, Equatable {
    enum Kind: Sendable { case file, directory, symlink, other }

    let name: String
    let kind: Kind
    /// 디스크에서 실제로 차지하는 바이트(모든 fork 합). `totalFileAllocatedSize`와 같은 값이다.
    /// 파일이 아니면 0.
    let allocated: Int64
    let modified: Date?
}

/// 폴더 하나의 항목을 `getattrlistbulk`로 **한 번에** 읽는다.
///
/// `FileManager.contentsOfDirectory` + `resourceValues`는 항목마다 URL과 속성 객체를 만들고
/// 속성을 따로 묻는다. 이 호출은 커널이 이름·종류·크기·수정 시각을 버퍼에 묶어 돌려준다 —
/// Finder와 디스크 분석 앱들이 쓰는 방식이다.
enum BulkDirectory {

    /// 못 열었으면 nil. **빈 폴더(`[]`)와 구분해야 한다** — 둘 다 0바이트지만
    /// 하나는 사실이고 하나는 모르는 것이다.
    ///
    /// 숨김 파일도 포함한다. 링크는 따라가지 않는다(`.symlink`로만 알린다).
    static func entries(atPath path: String) -> [BulkEntry]? {
        let fd = open(path, O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard fd >= 0 else { return nil }
        defer { close(fd) }

        var request = attrlist()
        request.bitmapcount = u_short(ATTR_BIT_MAP_COUNT)
        request.commonattr = attrgroup_t(ATTR_CMN_RETURNED_ATTRS)
            | attrgroup_t(ATTR_CMN_ERROR) | attrgroup_t(ATTR_CMN_NAME)
            | attrgroup_t(ATTR_CMN_OBJTYPE) | attrgroup_t(ATTR_CMN_MODTIME)
        request.fileattr = attrgroup_t(ATTR_FILE_ALLOCSIZE)

        let capacity = 128 * 1024
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: capacity, alignment: 16)
        defer { buffer.deallocate() }

        var result: [BulkEntry] = []
        var readAny = false
        while true {
            let count = getattrlistbulk(fd, &request, buffer, capacity, 0)
            if count == 0 { break }
            if count < 0 {
                if errno == EINTR { continue }
                // 처음부터 못 읽었으면 모른다. 도중에 끊겼으면 읽은 만큼은 사실이다.
                return readAny ? result : nil
            }
            readAny = true

            var entry = UnsafeRawPointer(buffer)
            for _ in 0..<Int(count) {
                let length = Int(entry.loadUnaligned(as: UInt32.self))
                defer { entry += length }
                if let parsed = parse(entry) { result.append(parsed) }
            }
        }
        return result
    }

    /// 항목 하나를 푼다. 필드는 **요청한 비트 순서대로**, 돌려받은 것만 들어 있다
    /// (`man getattrlistbulk`의 예제 순서: returned → error → name → objtype → modtime → 파일 속성).
    private static func parse(_ entry: UnsafeRawPointer) -> BulkEntry? {
        var field = entry + MemoryLayout<UInt32>.size
        let returned = field.loadUnaligned(as: attribute_set_t.self)
        field += MemoryLayout<attribute_set_t>.size

        if returned.commonattr & attrgroup_t(ATTR_CMN_ERROR) != 0 {
            let error = field.loadUnaligned(as: UInt32.self)
            field += MemoryLayout<UInt32>.size
            // 이 항목의 속성을 못 읽었다. 크기를 지어내지 않고 건너뛴다.
            if error != 0 { return nil }
        }

        guard returned.commonattr & attrgroup_t(ATTR_CMN_NAME) != 0 else { return nil }
        let reference = field.loadUnaligned(as: attrreference_t.self)
        let name = String(cString: (field + Int(reference.attr_dataoffset))
            .assumingMemoryBound(to: CChar.self))
        field += MemoryLayout<attrreference_t>.size

        var kind = BulkEntry.Kind.other
        if returned.commonattr & attrgroup_t(ATTR_CMN_OBJTYPE) != 0 {
            let type = field.loadUnaligned(as: fsobj_type_t.self)
            field += MemoryLayout<fsobj_type_t>.size
            switch type {
            case fsobj_type_t(VREG.rawValue): kind = .file
            case fsobj_type_t(VDIR.rawValue): kind = .directory
            case fsobj_type_t(VLNK.rawValue): kind = .symlink
            default: kind = .other
            }
        }

        var modified: Date?
        if returned.commonattr & attrgroup_t(ATTR_CMN_MODTIME) != 0 {
            let time = field.loadUnaligned(as: timespec.self)
            field += MemoryLayout<timespec>.size
            modified = Date(timeIntervalSince1970: TimeInterval(time.tv_sec)
                            + TimeInterval(time.tv_nsec) / 1_000_000_000)
        }

        var allocated: Int64 = 0
        if kind == .file, returned.fileattr & attrgroup_t(ATTR_FILE_ALLOCSIZE) != 0 {
            allocated = Int64(field.loadUnaligned(as: off_t.self))
        }

        return BulkEntry(name: name, kind: kind, allocated: allocated, modified: modified)
    }

    /// `"/"` 아래 항목이 `"//x"`가 되지 않게 잇는다.
    static func join(_ parent: String, _ name: String) -> String {
        parent.hasSuffix("/") ? parent + name : parent + "/" + name
    }
}
