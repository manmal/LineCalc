import XCTest
@testable import LineCalc

final class LineCalcTests: XCTestCase {

    func testGroupSum() {
        let calc = Calc<Double>(
            GroupSum {
                (3, "three")
                (5, "five")
                (7, "seven")
                GroupSum {
                    2
                    2
                    2
                    2
                }
                Sum(fromLine: "three", toLine: "five",  id: .init("sumShouldBeEight"))
                Sum(fromLine: "five",  toLine: "five",  id: .init("sumShouldBeFive"))
                Sum(fromLine: "three", toLine: "seven", id: .init("sumShouldBeFifteenA"))
                Sum(fromLine: "seven", toLine: "three", id: .init("sumShouldBeFifteenB"))
            }
        )
        let result = DoubleCalc.Runner.run(calc).groupResult
        let sum = result.outcomeResult.valueResult.value
        XCTAssertEqual(result.value(atLine: "sumShouldBeEight"), 8)
        XCTAssertEqual(result.value(atLine: "sumShouldBeFive"), 5)
        XCTAssertEqual(result.value(atLine: "sumShouldBeFifteenA"), 15)
        XCTAssertEqual(result.value(atLine: "sumShouldBeFifteenB"), 15)
        XCTAssertEqual(sum, 66)
    }

    static var allTests = [
        ("testGroupSum", testGroupSum),
    ]
}
