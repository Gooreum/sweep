import Testing
import Foundation
@testable import SweepKit

@Suite("RemovalVerdict")
struct RemovalVerdictTests {

    /// 실재하지 않는 가짜 홈. 위치 규칙만 보므로 디스크에 있을 필요가 없다.
    private let home = URL(filePath: "/Users/sweep-verdict-test", directoryHint: .isDirectory)

    private func classify(_ relative: String) -> RemovalVerdict {
        RemovalVerdict.classify(home.appending(path: relative), home: home)
    }

    private func isSafe(_ v: RemovalVerdict) -> Bool { if case .safe = v { true } else { false } }
    private func isCaution(_ v: RemovalVerdict) -> Bool { if case .caution = v { true } else { false } }

    // TC-1
    @Test("다시 만들어지는 곳은 지워도 됨이다")
    func regenerableLocationsAreSafe() {
        let probes = [
            "Library/Caches/com.apple.dt.Xcode",
            "Library/Developer/Xcode/DerivedData/App-abc",
            "Library/Logs/app.log",
            ".npm/_cacache/index-v5",
            "Library/Application Support/Code/Cache",
            "Library/Developer/CoreSimulator/Caches/dyld",
        ]
        for path in probes {
            let verdict = classify(path)
            #expect(isSafe(verdict), "\(path)가 지워도 됨이 아니다: \(verdict)")
            #expect(!verdict.reason.isEmpty, "\(path)에 사유가 없다")
            #expect(verdict.level == .safe)
        }
    }

    // TC-2
    @Test("내 파일·앱 데이터는 확인 필요이고 위치마다 사유가 다르다")
    func userContentIsCautionWithLocationReason() {
        let cases: [(String, String)] = [
            ("Documents/a.mov", "내 파일"),
            ("Downloads/x.dmg", "내려받은"),
            ("Library/Application Support/Notion", "앱 데이터"),
            ("Library/Containers/com.example.app", "따로 보관하는 데이터"),
            ("Library/Developer/Xcode/Archives/a.xcarchive", "심사 제출본"),
            ("Applications/Foo.app", "앱이에요"),
            ("Library/Fonts/x.ttf", "설정 정보"),
            ("Library/Developer/CoreSimulator/Devices/ABC", "앱 시험용 가상 기기"),
        ]
        for (path, keyword) in cases {
            let verdict = classify(path)
            #expect(isCaution(verdict), "\(path)가 확인 필요가 아니다: \(verdict)")
            #expect(verdict.reason.contains(keyword), "\(path) 사유가 다르다: \(verdict.reason)")
            #expect(verdict.level == .caution)
            #expect(verdict.allowsRemoval)
        }
    }

    // TC-3
    @Test("홈 밖의 내 소유 항목은 확인 필요로 두고 홈 밖임을 말한다")
    func outsideHomeIsCaution() {
        let verdict = RemovalVerdict.classify(URL(filePath: "/opt/homebrew/Cellar/node"), home: home)
        #expect(isCaution(verdict))
        #expect(verdict.reason.contains("사용자 폴더 밖"))
    }

    // TC-4
    @Test("관문이 막으면 보호됨이고 사유는 관문 문장이다")
    func gateVetoBecomesBlocked() {
        let realHome = FileManager.default.homeDirectoryForCurrentUser
        let verdict = RemovalVerdict.forDiskMap(realHome.appending(path: "Library/Keychains/x"))

        guard case .blocked(let veto) = verdict else {
            Issue.record("보호됨이 아니다: \(verdict)")
            return
        }
        #expect(verdict.level == .danger)
        #expect(!verdict.allowsRemoval)
        #expect(verdict.veto == veto)
        #expect(verdict.reason == veto.message)
    }

    // TC-4
    @Test("관문을 통과한 실제 경로는 위치로 갈린다")
    func passingGateFallsThroughToClassification() {
        let realHome = FileManager.default.homeDirectoryForCurrentUser
        #expect(RemovalVerdict.forDiskMap(realHome.appending(path: "Library/Caches/sweep-x")).level == .safe)
        #expect(RemovalVerdict.forDiskMap(realHome.appending(path: "Documents/sweep-x.mov")).level == .caution)
    }

    // TC-5
    @Test("세 갈래의 배지 글자는 비어 있지 않고 서로 다르다")
    func titlesAreDistinct() {
        let titles = [
            RemovalVerdict.safe(reason: "a").title,
            RemovalVerdict.caution(reason: "b").title,
            RemovalVerdict.blocked(.rootOrHome(URL(filePath: "/"))).title,
        ]
        #expect(titles.allSatisfy { !$0.isEmpty })
        #expect(Set(titles).count == 3)
    }

    @Test("좁은 규칙이 넓은 규칙을 이긴다")
    func narrowRuleWinsOverBroad() {
        // DerivedData는 Library 안이지만 "설정 데이터"가 아니라 "빌드하면 다시 생성"이다
        #expect(classify("Library/Developer/Xcode/DerivedData/App").reason.contains("다시 생겨요"))
        // Application Support 안이라도 끝 이름이 캐시면 지워도 됨
        #expect(isSafe(classify("Library/Application Support/Figma/DesktopProfile/v39/GPUCache")))
        #expect(isCaution(classify("Library/Application Support/Figma/DesktopProfile/v39")))
    }
}
