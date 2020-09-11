import Foundation

public extension Calc {

    @_functionBuilder
    struct GroupBuilder {
        static func buildBlock(_ components: Calc.Item...) -> [Calc.Item] {
            components
        }

        static func buildExpression(_ line: Calc.Line) -> Calc.Item {
            .line(line)
        }

        static func buildExpression(_ group: Calc.Group) -> Calc.Item {
            .group(group)
        }

        static func buildExpression(_ item: Calc.Item) -> Calc.Item {
            item
        }

        static func buildExpression(_ value: T) -> Calc.Item {
            .line(.init(value))
        }

        static func buildExpression(_ tuple: (T, String)) -> Calc.Item {
            .value(tuple.0, id: tuple.1)
        }
    }

}
