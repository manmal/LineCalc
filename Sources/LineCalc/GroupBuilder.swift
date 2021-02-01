import Foundation

public extension Item {

    @_functionBuilder
    struct GroupBuilder {
        public static func buildBlock(_ components: Item...) -> [Item] {
            components
        }

        public static func buildExpression(_ line: Item.Line) -> Item {
            .line(line)
        }

        public static func buildExpression(_ group: Item.Group) -> Item {
            .group(group)
        }

        public static func buildExpression(_ item: Item) -> Item {
            item
        }

        public static func buildExpression(_ value: Double) -> Item {
            .line(.init(value))
        }

        public static func buildExpression(_ sum: Sum) -> Item {
            .sum(from: sum.from, to: sum.to, key: sum.key)
        }

        public static func buildExpression(_ groupSum: GroupSum) -> Item {
            .group(
                Item.Group(
                    key: groupSum.key,
                    outcome: .sum(
                        .default()
                    ),
                    items: groupSum.items
                )
            )
        }
    }

}
