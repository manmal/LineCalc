import Foundation

public extension Calc {

    @_functionBuilder
    struct GroupBuilder {
        public static func buildBlock(_ components: Item<D>...) -> [Item<D>] {
            components
        }

        public static func buildExpression(_ line: Line<D>) -> Item<D> {
            .line(line)
        }

        public static func buildExpression(_ group: Group<D>) -> Item<D> {
            .group(group)
        }

        public static func buildExpression(_ item: Item<D>) -> Item<D> {
            item
        }

        public static func buildExpression(_ value: Double) -> Item<D> {
            .line(.init(value, descriptor: nil))
        }

        public static func buildExpression(_ tuple: (Double, idString: String, descriptor: D?)) -> Item<D> {
            .value(tuple.0, id: tuple.1, descriptor: tuple.2)
        }

        public static func buildExpression(_ sum: Sum<D>) -> Item<D> {
            .sum(from: sum.from, to: sum.to, id: sum.id, descriptor: sum.descriptor)
        }

        public static func buildExpression(_ groupSum: GroupSum<D>) -> Item<D> {
            .group(
                Group<D>(
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
