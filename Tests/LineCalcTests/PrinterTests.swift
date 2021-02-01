import XCTest
@testable import LineCalc

final class PrinterTests: XCTestCase {

    func testGroupSumPrinting() {
        let calc = Calc<String>(
            GroupSum(descriptor: "GroupSum 1") {
                (3, "three", "Three")
                (5, "five", "Five")
                (7, "seven", "Seven")
                GroupSum(descriptor: "Crazy Eight") {
                    2
                    2
                    2
                    GroupSum(descriptor: "Double Trouble") {
                        2
                    }
                }
                GroupSum(descriptor: "sumOfSums") {
                    Sum(fromLine: "three", toLine: "five",  id: "sumShouldBeEight")
                    Sum(fromLine: "five",  toLine: "five",  id: "sumShouldBeFive")
                    Sum(fromLine: "three", toLine: "seven", id: "sumShouldBeFifteenA")
                    Sum(fromLine: "seven", toLine: "three", id: "sumShouldBeFifteenB")
                }
            }
        )
        print(Printer().print(Item.Runner.run(calc)).joined(separator: "\n"))
    }
}
