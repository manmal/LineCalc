import Foundation

public extension Calc {

    indirect enum Item: Equatable {
        public typealias ID = Calc.ID
        case line(Line)
        case group(Group)

        var id: ID {
            switch self {
            case let .group(group):
                return group.id
            case let .line(line):
                return line.id
            }
        }
    }

    enum ID: Hashable {
        case `default`(OpaqueID = .init())
        case uuid(UUID = UUID())
        case string(String)

        public struct OpaqueID: Hashable {
            private let uuid = UUID()
            public init() {}
        }

        public init(_ string: String) {
            self = .string(string)
        }
    }

    enum Ref: Hashable {
        case line(ID)
        case outcomeOfGroup(ID)

        public static func line(_ lineIdString: String) -> Ref {
            line(.string(lineIdString))
        }
    }

    struct Line: Equatable {
        public typealias ID = Item.ID
        let id: Line.ID
        let value: Value
    }

    struct Group: Equatable {
        public typealias ID = Item.ID
        let id: Group.ID
        let items: [Item]
        let outcome: GroupOutcome
    }

    enum GroupOutcome: Equatable {
        public typealias ID = Item.ID
        case sum(ID = .default())
        case product(ID = .default())
        case line(Line)
    }

    indirect enum Value: Equatable {
        case plain(T)
        case reference(Ref)
        case binaryOp(BinaryOp)
        case rangeOp(RangeOp)
    }

    struct BinaryOp: Equatable {
        let a: Ref
        let b: Ref
        let op: (T, T) -> T

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.a == rhs.a && lhs.b == rhs.b
        }
    }

    struct RangeOp: Equatable {
        let scope: Scope
        let reduce: ([T]) -> T

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.scope == rhs.scope
        }

        public enum Scope: Equatable {
            case fromTo(from: Ref, to: Ref)
            case group(ID)
        }
    }

    enum ValueOperation {
        case subtract
    }
}

public extension Calc.RangeOp {

    init(from: Calc.Ref, to: Calc.Ref, reduce: @escaping ([T]) -> T) {
        self.init(scope: .fromTo(from: from, to: to), reduce: reduce)
    }
}

public extension Calc.Line {

    init(id: ID = .default(), _ immutableValue: T) {
        self.init(id: id, .plain(immutableValue))
    }

    init(id: ID = .default(), _ value: Calc.Value) {
        self.init(id: id, value: value)
    }
}

public extension Calc.Group {

    init(id: ID = .default(), outcome: Calc.GroupOutcome, @Calc.GroupBuilder items: () -> [Calc.Item]) {
        self.init(id: id, items: items(), outcome: outcome)
    }
}

public extension Calc.Item {

    static func value(_ value: T, id: ID = .default()) -> Calc.Item {
        .line(.init(id: id, value))
    }

    static func value(_ value: T, id idString: String) -> Calc.Item {
        self.value(value, id: .string(idString))
    }

    static func rangeOp(from: Calc.Ref, to: Calc.Ref, id: ID = .default(), reduce: @escaping ([T]) -> T) -> Calc.Item {
        .line(
            .init(
                id: id,
                Calc.Value.rangeOp(Calc.RangeOp.init(from: from, to: to, reduce: reduce))
            )
        )
    }

    static func sum(from: Calc.Ref, to: Calc.Ref, id: ID = .default()) -> Calc.Item {
        rangeOp(from: from, to: to, id: id, reduce: { $0.reduce(0, +) })
    }

    static func product(id: ID = .default(), from: Calc.Ref, to: Calc.Ref) -> Calc.Item {
        rangeOp(from: from, to: to, reduce: { $0.reduce(0, *) })
    }
}
