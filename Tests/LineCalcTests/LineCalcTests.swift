import XCTest
@testable import LineCalc

final class LineCalcTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(LineCalc().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
