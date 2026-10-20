import Foundation
import Testing
@testable import SweepKit

@Suite("KnownProcess")
struct KnownProcessTests {

    @Test("fileproviderd는 알려진 프로그램이고 건드리지 말라고 한다")
    func fileproviderd() throws {
        let known = try #require(KnownProcess.match(name: "fileproviderd"))
        #expect(known.advice == .leaveIt)
        #expect(!known.summary.isEmpty)
        #expect(!known.whenBusy.isEmpty)
    }

    @Test("대소문자는 무시한다")
    func ignoresCase() {
        #expect(KnownProcess.match(name: "WindowServer") != nil)
        #expect(KnownProcess.match(name: "KERNEL_TASK") != nil)
    }

    @Test("목록에 없는 이름은 설명을 지어내지 않고 nil이다")
    func unknownIsNil() {
        #expect(KnownProcess.match(name: "my-own-tool") == nil)
        #expect(KnownProcess.match(name: "") == nil)
    }

    @Test("접두어가 같다고 묶지 않는다")
    func noPrefixMatching() {
        #expect(KnownProcess.match(name: "nodemon") == nil)
        #expect(KnownProcess.match(name: "node") != nil)
    }

    @Test("kernel_task 설명은 열을 식히려고 CPU를 막는다는 사실을 담는다")
    func kernelTask() throws {
        let known = try #require(KnownProcess.match(name: "kernel_task"))
        #expect(known.summary.contains("열") || known.whenBusy.contains("열") || known.whenBusy.contains("뜨거"))
    }

    @Test("모든 항목은 설명과 이유가 비어 있지 않고 이름이 겹치지 않는다")
    func catalogIsWellFormed() {
        for name in ["kernel_task", "windowserver", "launchd", "fileproviderd", "bird", "node", "xcodebuild"] {
            let known = KnownProcess.match(name: name)
            #expect(known != nil, "\(name) 누락")
            #expect(known?.summary.isEmpty == false)
            #expect(known?.whenBusy.isEmpty == false)
        }
    }
}
