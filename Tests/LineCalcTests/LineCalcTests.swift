import XCTest
@testable import LineCalc

final class LineCalcTests: XCTestCase {

    func testGroupSum() {
        let calc = DoubleCalc(
            group: DoubleCalc.Group(outcome: .sum()) {
                (3, "three")
                (5, "five")
                (7, "seven")
                DoubleCalc.Group(outcome: .product()) {}
                DoubleCalc.Item.sum(from: .line("three"), to: .line("five"), id: .init("sumShouldBeEight"))
                DoubleCalc.Item.sum(from: .line("five"), to: .line("five"), id: .init("sumShouldBeFive"))
                DoubleCalc.Item.sum(from: .line("three"), to: .line("seven"), id: .init("sumShouldBeFifteenA"))
                DoubleCalc.Item.sum(from: .line("seven"), to: .line("three"), id: .init("sumShouldBeFifteenB"))
            }
        )
        let result = DoubleCalc.Runner.run(calc).groupResult
        let sum = result.outcomeResult.valueResult.value
        XCTAssertEqual(result.value(atLine: "sumShouldBeEight"), 8)
        XCTAssertEqual(result.value(atLine: "sumShouldBeFive"), 5)
        XCTAssertEqual(result.value(atLine: "sumShouldBeFifteenA"), 15)
        XCTAssertEqual(result.value(atLine: "sumShouldBeFifteenB"), 15)
        XCTAssertEqual(sum, 58)
    }

    static var allTests = [
        ("testGroupSum", testGroupSum),
    ]
}
