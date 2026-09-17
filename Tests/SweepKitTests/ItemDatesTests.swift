import Testing
import Foundation
@testable import SweepKit

/// 스캐너가 실제로 `CleanupItem.dates`를 채우는가.
///
/// `FileDates`가 옳게 계산해도 스캐너가 넘기지 않으면 화면에는 아무것도 안 나온다.
/// 이 스위트는 **배선**을 본다 — 모델이 아니라 연결이 끊긴 것을 잡는 자리다.
@Suite("스캐너가 날짜를 채운다")
struct ItemDatesTests {

    private func makeFakeHome(_ tag: String) throws -> URL {
        let home = URL(filePath: NSTemporaryDirectory())
            .appending(path: "sweep-dates-\(tag)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        return home
    }

    private static let oneMB = 1024 * 1024

    private func seed(_ relative: String, in home: URL, bytes: Int = oneMB) throws -> URL {
        let dir = home.appending(path: relative)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(repeating: 0x41, count: bytes).write(to: dir.appending(path: "blob.bin"))
        return dir
    }

    // TC-1
    @Test("dates를 안 넘기면 unknown이다")
    func defaultsToUnknown() {
        let item = CleanupItem(url: URL(filePath: "/tmp/x"), size: 1,
                               category: .appCache, safety: .safe)

        // 기본값이 있어야 기존 생성 지점 47곳이 그대로 컴파일된다.
        #expect(item.dates == .unknown)
        #expect(item.dates.lastUsedLabel() == nil)
    }

    // TC-3
    @Test("앱 캐시 항목에 마지막 사용이 실린다")
    func appCacheCarriesDates() async throws {
        let home = try makeFakeHome("appcache")
        defer { try? FileManager.default.removeItem(at: home) }
        _ = try seed("Library/Application Support/Slack/Cache", in: home)

        // 전체 디스크 접근 여부와 무관하게 임시 홈을 읽도록 켜 둔다.
        let items = await AppCacheScanner(home: home, canReadAppData: true).scan()

        let item = try #require(items.first)
        #expect(item.dates.lastUsed != nil)
        #expect(item.dates.created != nil)
    }

    // TC-4
    @Test("개발 캐시 항목에 마지막 사용이 실린다")
    func devCacheCarriesDates() async throws {
        let home = try makeFakeHome("devcache")
        defer { try? FileManager.default.removeItem(at: home) }
        _ = try seed("Library/Logs/SomeApp", in: home)

        let items = await DevCacheScanner(home: home).scan()

        let item = try #require(items.first { $0.url.lastPathComponent == "SomeApp" })
        #expect(item.dates.lastUsed != nil)
    }

    // TC-5
    @Test("Xcode 항목에 마지막 사용이 실린다")
    func xcodeCarriesDates() async throws {
        let home = try makeFakeHome("xcode")
        defer { try? FileManager.default.removeItem(at: home) }
        _ = try seed("Library/Developer/Xcode/DerivedData/MyApp-abc", in: home)

        let items = await XcodeScanner(home: home).scan()

        let item = try #require(items.first)
        #expect(item.dates.lastUsed != nil)
    }

    // TC-6
    @Test("큰 파일의 마지막 사용은 그 파일의 수정 시각이다")
    func largeFileUsesItsOwnModification() async throws {
        let home = try makeFakeHome("large")
        defer { try? FileManager.default.removeItem(at: home) }
        let downloads = home.appending(path: "Downloads")
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
        let file = downloads.appending(path: "big.bin")
        try Data(repeating: 0x41, count: 2 * Self.oneMB).write(to: file)
        let stamped = Date().addingTimeInterval(-40 * 86_400)
        try FileManager.default.setAttributes([.modificationDate: stamped],
                                              ofItemAtPath: file.path)

        let items = await LargeFileScanner(minimumSize: Int64(Self.oneMB), home: home).scan()

        let item = try #require(items.first)
        let used = try #require(item.dates.lastUsed)
        #expect(abs(used.timeIntervalSince(stamped)) < 2)
    }

    // TC-8
    @Test("묵은 캐시의 설명과 날짜가 같은 값에서 나온다")
    func staleDetailAgreesWithDates() async throws {
        let home = try makeFakeHome("stale")
        defer { try? FileManager.default.removeItem(at: home) }
        let cache = try seed("Library/Caches/com.example.OldApp", in: home)
        let stamped = Date().addingTimeInterval(-200 * 86_400)
        try FileManager.default.setAttributes([.modificationDate: stamped],
                                              ofItemAtPath: cache.appending(path: "blob.bin").path)

        let items = await StaleCacheScanner(home: home).scan()

        let item = try #require(items.first)
        let used = try #require(item.dates.lastUsed)
        // 설명은 "200일 동안 쓰이지 않았습니다", 우측 열은 "6개월 전 사용".
        // 둘이 같은 값에서 나오므로 서로 모순될 수 없다.
        #expect(item.detail.hasPrefix("200일"))
        #expect(abs(used.timeIntervalSince(stamped)) < 2)
        #expect(item.dates.lastUsedLabel() == "6개월 전 사용")
    }

    // TC-2 (Phase 3) — 우측 열 둘째 줄
    @Test("만든 날과 마지막 사용이 한 줄에 같이 나온다")
    func datesLineJoinsBoth() {
        let item = CleanupItem(url: URL(filePath: "/tmp/Anki"), size: 1,
                               category: .appCache, safety: .safe,
                               detail: "npm 내려받기 캐시",
                               dates: FileDates(created: Date(timeIntervalSince1970: 1_747_000_000),
                                                lastUsed: Date()))

        let line = item.datesLine()

        // 설명이 있어도 만든 날이 사라지면 안 된다 — 실기에서 정크 항목은
        // 거의 전부 설명이 붙어 있어 만든 날이 한 줄도 안 나왔다.
        #expect(line?.contains("만듦") == true)
        #expect(line?.contains("오늘 사용") == true)
        #expect(line?.contains(" · ") == true)
    }

    // TC-3 (Phase 3)
    @Test("한쪽만 읽히면 읽히는 쪽만 나온다")
    func datesLinePartial() {
        let item = CleanupItem(url: URL(filePath: "/tmp/x"), size: 1,
                               category: .appCache, safety: .safe,
                               dates: FileDates(lastUsed: Date()))

        #expect(item.datesLine() == "오늘 사용")
    }

    // TC-4 (Phase 3)
    @Test("날짜를 하나도 못 읽으면 줄이 없다")
    func datesLineAbsent() {
        let item = CleanupItem(url: URL(filePath: "/tmp/x"), size: 1,
                               category: .appCache, safety: .safe)

        // 빈 문자열을 돌려주면 화면에 보이지 않는 빈 줄이 생긴다.
        #expect(item.datesLine() == nil)
    }
}
