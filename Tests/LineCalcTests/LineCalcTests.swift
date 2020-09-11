import XCTest
@testable import LineCalc

final class LineCalcTests: XCTestCase {

    func testGroupSum() {
        let calc = DoubleCalc(
            group: .init(
                [
                    .value(3, id: "three"),
                    .value(5, id: "five"),
                    .value(7, id: "seven"),
                    .group(
                        DoubleCalc.Group(
                            [

                            ],
                            outcome: .product()
                        )
                    ),
                    .sum(from: .line("three"), to: .line("five"), id: .init("sumShouldBeEight")),
                    .sum(from: .line("five"), to: .line("five"), id: .init("sumShouldBeFive")),
                    .sum(from: .line("three"), to: .line("seven"), id: .init("sumShouldBeFifteenA")),
                    .sum(from: .line("seven"), to: .line("three"), id: .init("sumShouldBeFifteenB")),
                ],
                outcome: .sum()
            )
        )
        let result = DoubleCalc.Runner.run(calc)
        let sum = result.groupResult.outcomeResult.valueResult.value
        XCTAssertEqual(result.groupResult.value(atLine: "sumShouldBeEight"), 8)
        XCTAssertEqual(result.groupResult.value(atLine: "sumShouldBeFive"), 5)
        XCTAssertEqual(result.groupResult.value(atLine: "sumShouldBeFifteenA"), 15)
        XCTAssertEqual(result.groupResult.value(atLine: "sumShouldBeFifteenB"), 15)
        XCTAssertEqual(sum, 58)
    }

    static var allTests = [
        ("testGroupSum", testGroupSum),
    ]
}
