import Testing
@testable import SweepKit

@Suite("ItemColumnLayout")
struct ItemColumnLayoutTests {

    private let all = ItemColumnLayout.Column.allCases
    private let noDates: [ItemColumnLayout.Column] = [.detail, .size, .safety]

    // TC-1
    @Test("기본 폭은 예전 고정 폭과 같다")
    func defaults() {
        let layout = ItemColumnLayout()
        #expect(layout.width(.detail) == 200)
        #expect(layout.width(.dates) == 150)
        #expect(layout.width(.size) == 80)
        #expect(layout.width(.safety) == 80)
    }

    // TC-2
    @Test("가운데 경계는 양옆 두 열이 폭을 주고받는다")
    func tradesBetweenNeighbours() {
        var layout = ItemColumnLayout()
        layout.dragLeadingEdge(of: .dates, by: 30, visible: all, nameWidth: 300)
        #expect(layout.width(.detail) == 230)
        #expect(layout.width(.dates) == 120)
    }

    // TC-3
    @Test("오른쪽 열이 최소 폭에 닿으면 멈춘다")
    func stopsAtRightMinimum() {
        var layout = ItemColumnLayout()
        layout.dragLeadingEdge(of: .dates, by: 500, visible: all, nameWidth: 300)
        #expect(layout.width(.dates) == 70)
        #expect(layout.width(.detail) == 280)
    }

    // TC-4
    @Test("이름 옆 경계를 왼쪽으로 끌면 설명이 넓어진다")
    func widensFromName() {
        var layout = ItemColumnLayout()
        layout.dragLeadingEdge(of: .detail, by: -50, visible: all, nameWidth: 300)
        #expect(layout.width(.detail) == 250)
    }

    // TC-5
    @Test("이름 열은 최소 폭 아래로 내주지 않는다")
    func keepsNameMinimum() {
        var layout = ItemColumnLayout()
        layout.dragLeadingEdge(of: .detail, by: -50,
                               visible: all, nameWidth: ItemColumnLayout.nameMinimum + 20)
        #expect(layout.width(.detail) == 220)
    }

    // TC-6
    @Test("이름 옆 경계를 오른쪽으로 끌면 설명이 최소 폭에서 멈춘다")
    func stopsAtDetailMinimum() {
        var layout = ItemColumnLayout()
        layout.dragLeadingEdge(of: .detail, by: 500, visible: all, nameWidth: 300)
        #expect(layout.width(.detail) == 80)
    }

    // TC-7
    @Test("날짜가 숨겨지면 설명과 크기가 이웃이다")
    func skipsHiddenDates() {
        var layout = ItemColumnLayout()
        layout.dragLeadingEdge(of: .size, by: 10, visible: noDates, nameWidth: 300)
        #expect(layout.width(.detail) == 210)
        #expect(layout.width(.size) == 70)
        #expect(layout.width(.dates) == 150)
    }

    // TC-8
    @Test("보이지 않는 열은 끌어도 바뀌지 않는다")
    func ignoresHiddenColumn() {
        var layout = ItemColumnLayout()
        layout.dragLeadingEdge(of: .dates, by: 30, visible: noDates, nameWidth: 300)
        #expect(layout == ItemColumnLayout())
    }

    // TC-9
    @Test("저장 문자열로 되돌릴 수 있다")
    func roundTrips() {
        var layout = ItemColumnLayout()
        layout.dragLeadingEdge(of: .dates, by: 30, visible: all, nameWidth: 300)
        #expect(layout.rawValue == "230,120,80,80")
        #expect(ItemColumnLayout(rawValue: layout.rawValue) == layout)
    }

    // TC-10
    @Test("형식이 다른 저장값은 버린다", arguments: ["a,b", "1,2,3", "200,150,80,x", ""])
    func rejectsMalformed(_ raw: String) {
        #expect(ItemColumnLayout(rawValue: raw) == nil)
    }

    // TC-11
    @Test("최소 폭보다 작은 저장값은 최소로 올린다")
    func clampsStoredValues() {
        let layout = ItemColumnLayout(rawValue: "10,10,10,10")
        #expect(layout?.widths == ItemColumnLayout.minimums)
    }
}
