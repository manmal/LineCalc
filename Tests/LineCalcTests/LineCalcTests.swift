import XCTest
@testable import LineCalc

final class LineCalcTests: XCTestCase {

    func testGroupSum() throws {
        let calc = try DoubleCalc(
            group: .init(id: .default(), items: [
                .group(
                    .init(
                        id: .string("group1"),
                        items: [
                            .line(3),
                            .line(5),
                            .line(7)
                        ]
                    )
                ),
                .line(
                    .init(
                        id: .string("sum"),
                        .rangeOp(
                            .init(groupResultId: .string("group1")) { $0.reduce(0, +) }
                        )
                    )
                )
            ])
        )
        let result = DoubleCalc.Runner.run(calc)
        let sum = result.groupResult.itemResults.firstLineResult(.string("sum"))?.valueResult.value
        XCTAssertEqual(sum, 15)
    }

    static var allTests = [
        ("testGroupSum", testGroupSum),
    ]
}
