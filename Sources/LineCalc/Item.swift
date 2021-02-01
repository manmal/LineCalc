import Foundation

public indirect enum Item<LocalKey: ItemKey, GlobalKey: ItemKey>: Equatable {
    typealias LocalKey = LocalKey
    typealias GlobalKey = GlobalKey

    case line(Line)
    case group(Group)

    var key: Key {
        switch self {
        case let .group(group):
            return group.key
        case let .line(line):
            return line.key
        }
    }
}

public protocol ItemKey: Equatable {}

public extension Item {
    struct Line: Equatable {
        public let key: Key
        public let value: Value
    }

    /// Container for `Item`s. Also acts as a `Line` via the `outcome` variable.
    /// E.g. a non-recursive range operation will select the `Group`'s `outcome`
    /// as if it were a `Line`. A recursive operation will select the `Group`'s
    /// `items` instead, and disregard the `outcome`.
    struct Group: Equatable {
        public let key: Key
        public let items: [Item]
        public let outcome: GroupOutcome
    }

    indirect enum Value: Equatable {
        case plain(Double)
        case reference(Ref)
        case transformedReference(UnaryOp)
        case binaryOp(BinaryOp)
        case ternaryOp(TernaryOp)
        case rangeOp(RangeOp)
    }

    enum Ref: Equatable {
        case local(Key)
        case global(Item<GlobalKey, GlobalKey>.Key)
    }

    enum Key: Equatable {
        case `default`(uuid: UUID = UUID())
        case localKey(LocalKey)
    }

    /// A GroupOutcome can be referenced either by its own `ID`, or
    /// by the containing Group's `ID`.
    enum GroupOutcome: Equatable {
        case sum(Key = .default())
        case product(Key = .default())
        case op(Key = .default(), op: GroupOp)
        case line(Line)

        public struct GroupOp: Equatable {
            private let uuid = UUID()
            public let reduce: ([Double]) -> Double

            public init(_ reduce: @escaping ([Double]) -> Double) {
                self.reduce = reduce
            }

            public static func == (lhs: Self, rhs: Self) -> Bool {
                lhs.uuid == rhs.uuid
            }
        }
    }

    struct GroupSum {
        public let key: Key
        public let items: () -> [Item]

        public init(key: Key = .default(), @Item.GroupBuilder items: @escaping () -> [Item]) {
            self.key = key
            self.items = items
        }
    }

}

public extension Item {

    struct UnaryOp: Equatable {
        let ref: Ref
        let op: (Double) -> Double

        public init(ref: Ref, op: @escaping (Double) -> Double) {
            self.ref = ref
            self.op = op
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.ref == rhs.ref
        }
    }

    struct BinaryOp: Equatable {
        let a: Ref
        let b: Ref
        let op: (Double, Double) -> Double

        public init(a: Ref, b: Ref, op: @escaping (Double, Double) -> Double) {
            self.a = a
            self.b = b
            self.op = op
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.a == rhs.a && lhs.b == rhs.b
        }
    }

    struct TernaryOp: Equatable {
        let a: Ref
        let b: Ref
        let c: Ref
        let op: (Double, Double, Double) -> Double

        public init(a: Ref, b: Ref, c: Ref, op: @escaping (Double, Double, Double) -> Double) {
            self.a = a
            self.b = b
            self.c = c
            self.op = op
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.a == rhs.a && lhs.b == rhs.b && lhs.c == rhs.c
        }
    }

    struct RangeOp: Equatable {
        let scope: Scope
        let traversion: RangeTraversion
        let reduce: ([Double]) -> Double

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.scope == rhs.scope
        }

        public enum Scope: Equatable {
            case fromTo(from: Ref, to: Ref)
            case group(Key)
        }
    }

    struct Sum {
        let from: Ref
        let to: Ref
        let key: Key

        public init(from: Ref, to: Ref, key: Key = .default()) {
            self.from = from
            self.to = to
            self.key = key
        }
    }
}

public enum RangeTraversion {
    /// Selects all encountered `Line`s and also encountered `Group`s' `outcome`s.
    case deep
    /// Selects the `outcome` for any encountered `Group`
    case shallow
}

public enum ValueOperation {
    case subtract
}

public extension Item.GroupOutcome {
    static func rangeOp(
        from: Item.Ref,
        to: Item.Ref,
        traversion: RangeTraversion,
        key: Item.Key = .default(),
        reduce: @escaping ([Double]) -> Double
    ) -> Item.GroupOutcome {
        .line(
            Item.Line(
                key: key,
                Item.Value.rangeOp(
                    Item.RangeOp(
                        from: from,
                        to: to,
                        traversion: traversion,
                        reduce: reduce
                    )
                )
            )
        )
    }
}

public extension Item.RangeOp {

    init(from: Item.Ref, to: Item.Ref, traversion: RangeTraversion, reduce: @escaping ([Double]) -> Double) {
        self.init(scope: .fromTo(from: from, to: to), traversion: traversion, reduce: reduce)
    }
}

public extension Item.Line {

    init(key: Item.Key = .default(), _ immutableValue: Double) {
        self.init(key: key, .plain(immutableValue))
    }

    init(key: Item.Key = .default(), _ value: Item.Value) {
        self.init(key: key, value: value)
    }
}

public extension Item.Group {

    init(
        key: Item.Key = .default(),
        outcome: Item.GroupOutcome,
        @Item.GroupBuilder items: () -> [Item]
    ) {
        self.init(key: key, items: items(), outcome: outcome)
    }
}

public extension Item.Key {

}

public extension Item.Value {

    static func localRef(_ key: Item.Key) -> Self {
        .reference(Item.Ref.local(key))
    }

    static func globalRef(_ key: Item<GlobalKey, GlobalKey>.Key) -> Self {
        .reference(Item.Ref.global(key))
    }
}

public extension Item {

    static func value(_ value: Double, key: Key = .default()) -> Item {
        .line(.init(key: key, value))
    }

    static func rangeOp(
        from: Ref,
        to: Ref,
        traversion: RangeTraversion,
        key: Key = .default(),
        reduce: @escaping ([Double]) -> Double
    ) -> Item {
        .line(
            .init(
                key: key,
                Value.rangeOp(RangeOp(from: from, to: to, traversion: traversion, reduce: reduce))
            )
        )
    }

    static func sum(from: Ref, to: Ref, key: Key = .default()) -> Item {
        rangeOp(from: from, to: to, traversion: .shallow, key: key, reduce: { $0.reduce(0, +) })
    }

    static func product(key: Key = .default(), from: Ref, to: Ref) -> Item {
        rangeOp(from: from, to: to, traversion: .shallow, reduce: { $0.reduce(0, *) })
    }
}

public extension Item {
    enum CalcError: Error {
        case emptyGroup(Key)
    }
}
