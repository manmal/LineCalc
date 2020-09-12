import XCTest
@testable import LineCalc

final class LineCalcTests: XCTestCase {

    func testGroupSum() {
        let calc = Calc<Double, String>(
            GroupSum {
                (3, "three", nil)
                (5, "five", nil)
                (7, "seven", nil)
                GroupSum {
                    2
                    2
                    2
                    2
                }
                GroupSum("sumOfSums") {
                    Sum(fromLine: "three", toLine: "five",  id: "sumShouldBeEight")
                    Sum(fromLine: "five",  toLine: "five",  id: "sumShouldBeFive")
                    Sum(fromLine: "three", toLine: "seven", id: "sumShouldBeFifteenA")
                    Sum(fromLine: "seven", toLine: "three", id: "sumShouldBeFifteenB")
                }
            }
        )
        let result = DoubleCalc.Runner.run(calc).groupResult
        XCTAssertEqual(result.value(atLine: "sumShouldBeEight"), 8)
        XCTAssertEqual(result.value(atLine: "sumShouldBeFive"), 5)
        XCTAssertEqual(result.value(atLine: "sumShouldBeFifteenA"), 15)
        XCTAssertEqual(result.value(atLine: "sumShouldBeFifteenB"), 15)
        XCTAssertEqual(result.value(atLine: "sumOfSums"), 43)
        XCTAssertEqual(result.outcomeResult.valueResult.value, 66)
    }

    static var allTests = [
        ("testGroupSum", testGroupSum),
    ]
}
