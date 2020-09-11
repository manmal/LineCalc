import Foundation

public extension Calc {

    @_functionBuilder
    struct GroupBuilder {
        static func buildBlock(_ components: Item<T>...) -> [Item<T>] {
            components
        }

        static func buildExpression(_ line: Line<T>) -> Item<T> {
            .line(line)
        }

        static func buildExpression(_ group: Group<T>) -> Item<T> {
            .group(group)
        }

        static func buildExpression(_ item: Item<T>) -> Item<T> {
            item
        }

        static func buildExpression(_ value: T) -> Item<T> {
            .line(.init(value))
        }

        static func buildExpression(_ tuple: (T, String)) -> Item<T> {
            .value(tuple.0, id: tuple.1)
        }

        static func buildExpression(_ sum: Sum) -> Item<T> {
            .sum(from: sum.from, to: sum.to, id: sum.id)
        }

        static func buildExpression(_ groupSum: GroupSum<T>) -> Item<T> {
            .group(Group<T>.init(id: groupSum.id, outcome: .sum(), items: groupSum.items))
        }
    }

}
