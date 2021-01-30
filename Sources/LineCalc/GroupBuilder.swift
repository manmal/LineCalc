import Foundation

public extension Calc {

    @_functionBuilder
    struct GroupBuilder {
        public static func buildBlock(_ components: Item<T, D>...) -> [Item<T, D>] {
            components
        }

        public static func buildExpression(_ line: Line<T, D>) -> Item<T, D> {
            .line(line)
        }

        public static func buildExpression(_ group: Group<T, D>) -> Item<T, D> {
            .group(group)
        }

        public static func buildExpression(_ item: Item<T, D>) -> Item<T, D> {
            item
        }

        public static func buildExpression(_ value: T) -> Item<T, D> {
            .line(.init(value, descriptor: nil))
        }

        public static func buildExpression(_ tuple: (T, idString: String, descriptor: D?)) -> Item<T, D> {
            .value(tuple.0, id: tuple.1, descriptor: tuple.2)
        }

        public static func buildExpression(_ sum: Sum<D>) -> Item<T, D> {
            .sum(from: sum.from, to: sum.to, id: sum.id, descriptor: sum.descriptor)
        }

        public static func buildExpression(_ groupSum: GroupSum<T, D>) -> Item<T, D> {
            .group(
                Group<T, D>(
                    id: groupSum.id,
                    outcome: .sum(
                        .default(),
                        descriptor: groupSum.descriptor
                    ),
                    descriptor: groupSum.descriptor,
                    items: groupSum.items
                )
            )
        }
    }

}
