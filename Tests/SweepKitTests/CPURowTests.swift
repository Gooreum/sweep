import Testing
import Foundation
@testable import SweepKit

/// 샌드박스가 못 읽는 시스템 프로세스 합계를 목록에 끼워 넣는 규칙.
@Suite("CPURow")
struct CPURowTests {

    private func usage(_ pid: pid_t, _ percent: Double) -> ProcessUsage {
        ProcessUsage(pid: pid, name: "p\(pid)", percent: percent)
    }

    @Test("합계 행이 점유율 순서 자리에 들어간다")
    func unlistedIsInsertedByPercent() {
        let rows = CPURow.rows(usage: [usage(1, 300), usage(2, 100)], unlisted: 160)

        #expect(rows.map(\.percent) == [300, 160, 100])
        #expect(rows[1] == .unlisted(percent: 160))
    }

    @Test("커널 값이 없으면 프로세스 행만 그대로다")
    func missingUnlistedLeavesProcesses() {
        let rows = CPURow.rows(usage: [usage(1, 50)], unlisted: nil)

        #expect(rows == [.process(usage(1, 50))])
    }

    @Test("0.5% 미만이면 합계 행을 만들지 않는다")
    func tinyUnlistedIsDropped() {
        // "0.4%" 줄은 반올림 잡음이라 자리만 차지한다
        let rows = CPURow.rows(usage: [usage(1, 50)], unlisted: 0.4)

        #expect(rows.count == 1)
    }

    @Test("가장 크면 맨 앞, 가장 작으면 맨 뒤에 온다")
    func unlistedAtEdges() {
        let list = [usage(1, 80), usage(2, 20)]

        #expect(CPURow.rows(usage: list, unlisted: 120).first == .unlisted(percent: 120))
        #expect(CPURow.rows(usage: list, unlisted: 5).last == .unlisted(percent: 5))
        // 목록이 비어도 합계 행 하나는 보인다 — 내 프로세스가 놀아도 기계는 바쁠 수 있다
        #expect(CPURow.rows(usage: [], unlisted: 30) == [.unlisted(percent: 30)])
    }

    @Test("동률이면 이름이 있는 프로세스가 먼저다")
    func tieKeepsProcessFirst() {
        let rows = CPURow.rows(usage: [usage(1, 40)], unlisted: 40)

        #expect(rows.first == .process(usage(1, 40)))
    }
}
