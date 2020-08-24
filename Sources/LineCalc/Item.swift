import Foundation
import NonEmpty

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

        static func line(_ value: T) -> Item {
            return .line(.init(value))
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
    }

    struct Line: Equatable {
        public typealias ID = Item.ID
        let id: Line.ID
        let value: Value
    }

    struct Group: Equatable {
        public typealias ID = Item.ID
        let id: Group.ID
        let items: NonEmpty<[Item]>
    }

    indirect enum Value: Equatable {
        case plain(T)
        case reference(ID)
        case binaryOp(BinaryOp)
        case rangeOp(RangeOp)
    }

    struct BinaryOp: Equatable {
        let a: ID
        let b: ID
        let op: (T, T) -> T

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.a == rhs.a && lhs.b == rhs.b
        }
    }

    struct RangeOp: Equatable {
        let scope: Scope
        let op: ([T]) -> T

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.scope == rhs.scope
        }

        public enum Scope: Equatable {
            case fromTo(from: ID, to: ID)
            case group(ID)
        }
    }

    enum ValueOperation {
        case subtract
    }
}

public extension Calc.RangeOp {

    init(from: Calc.ID, to: Calc.ID, op: @escaping ([T]) -> T) {
        self.init(scope: .fromTo(from: from, to: to), op: op)
    }

    init(groupResultId: Calc.ID, op: @escaping ([T]) -> T) {
        self.init(scope: .group(groupResultId), op: op)
    }
}

public extension Calc.Line {

    init(id: ID = .default(), _ immutableValue: T) {
        self.init(id: id, value: .plain(immutableValue))
    }

    init(id: ID = .default(), _ value: Calc.Value) {
        self.init(id: id, value: value)
    }
}

public extension Calc.Group {

    init(id: ID, items: [Calc.Item]) throws {
        guard let first = items.first else {
            throw Calc.CalcError.emptyGroup(id)
        }
        self.id = id
        self.items = .init(first, Array(items.dropFirst()))
    }
}
