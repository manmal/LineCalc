import Foundation

public extension Calc {

    @_functionBuilder
    struct GroupBuilder {
        static func buildBlock(_ components: Item<T, D>...) -> [Item<T, D>] {
            components
        }

        static func buildExpression(_ line: Line<T, D>) -> Item<T, D> {
            .line(line)
        }

        static func buildExpression(_ group: Group<T, D>) -> Item<T, D> {
            .group(group)
        }

        static func buildExpression(_ item: Item<T, D>) -> Item<T, D> {
            item
        }

        static func buildExpression(_ value: T) -> Item<T, D> {
            .line(.init(value, descriptor: nil))
        }

        static func buildExpression(_ tuple: (T, idString: String, descriptor: D?)) -> Item<T, D> {
            .value(tuple.0, id: tuple.1, descriptor: tuple.2)
        }

        static func buildExpression(_ sum: Sum<D>) -> Item<T, D> {
            .sum(from: sum.from, to: sum.to, id: sum.id, descriptor: sum.descriptor)
        }

        static func buildExpression(_ groupSum: GroupSum<T, D>) -> Item<T, D> {
            .group(Group<T, D>(id: groupSum.id, outcome: .sum(.default(), groupSum.descriptor), groupSum.descriptor, items: groupSum.items))
        }
    }

}
