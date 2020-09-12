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

    func testDeepRangeOpAcrossGroupSum() {
        let calc = Calc<Double, String>(
            Group<Double, String>(
                outcome: .rangeOp(
                    fromId: "three",
                    toId: "seven",
                    traversion: .deep,
                    reduce: { $0.reduce(0, +) }
                )
            ) {
                (3, "three", nil)
                GroupSum {
                    5
                }
                (7, "seven", nil)
            }
        )
        let result = DoubleCalc.Runner.run(calc).groupResult

        // Deep traversal means that every group's items are added,
        // in addition to the Group's outcome. Hence, the result is:
        // 3 + (5 + 5 [outcome]) + 7
        XCTAssertEqual(result.outcomeResult.valueResult.value, 20)
    }

    func testDeepRangeOpForNestedGroupSums() {
        let calc = Calc<Double, String>(
            Group<Double, String>(
                outcome: .rangeOp(
                    fromId: "three",
                    toId: "groupSum",
                    traversion: .deep,
                    reduce: { $0.reduce(0, +) }
                )
            ) {
                (3, "three", nil)
                GroupSum("groupSum") {
                    5
                    GroupSum {
                        7
                    }
                }
            }
        )
        let result = DoubleCalc.Runner.run(calc).groupResult

        // Deep traversal means that every group's items are added,
        // in addition to the Group's outcome. Hence, the result is:
        // 3 + (5 + (7 + 7 [outcome]) + (5 + 7) [outcome])
        XCTAssertEqual(result.outcomeResult.valueResult.value, 34)
    }

    func testShallowRangeOpForNestedGroupSums() {
        let calc = Calc<Double, String>(
            Group<Double, String>(
                outcome: .rangeOp(
                    fromId: "three",
                    toId: "groupSum",
                    traversion: .shallow,
                    reduce: { $0.reduce(0, +) }
                )
            ) {
                (3, "three", nil)
                GroupSum("groupSum") {
                    5
                    GroupSum {
                        7
                    }
                }
            }
        )
        let result = DoubleCalc.Runner.run(calc).groupResult
        XCTAssertEqual(result.outcomeResult.valueResult.value, 15)
    }

    static var allTests = [
        ("testGroupSum", testGroupSum),
    ]
}
