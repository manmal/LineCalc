import Foundation

public indirect enum Item<T: CalcValue>: Equatable {
    case line(Line<T>)
    case group(Group<T>)

    var id: ID {
        switch self {
        case let .group(group):
            return group.id
        case let .line(line):
            return line.id
        }
    }
}

public enum ID: Hashable {
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

public enum Ref: Hashable {
    case line(ID)
    case outcomeOfGroup(ID)

    public static func line(_ lineIdString: String) -> Ref {
        line(.string(lineIdString))
    }
}

public struct Line<T: CalcValue>: Equatable {
    let id: ID
    let value: Value<T>
}

public struct Group<T: CalcValue>: Equatable {
    let id: ID
    let items: [Item<T>]
    let outcome: GroupOutcome<T>
}

public enum GroupOutcome<T: CalcValue>: Equatable {
    case sum(ID = .default())
    case product(ID = .default())
    case line(Line<T>)
}

public indirect enum Value<T: CalcValue>: Equatable {
    case plain(T)
    case reference(Ref)
    case binaryOp(BinaryOp<T>)
    case rangeOp(RangeOp<T>)
}

public struct BinaryOp<T: CalcValue>: Equatable {
    let a: Ref
    let b: Ref
    let op: (T, T) -> T

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.a == rhs.a && lhs.b == rhs.b
    }
}

public struct RangeOp<T: CalcValue>: Equatable {
    let scope: Scope
    let recursive: Bool
    let reduce: ([T]) -> T

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.scope == rhs.scope
    }

    public enum Scope: Equatable {
        case fromTo(from: Ref, to: Ref)
        case group(ID)
    }
}

public enum ValueOperation {
    case subtract
}

public extension RangeOp {

    init(from: Ref, to: Ref, recursive: Bool, reduce: @escaping ([T]) -> T) {
        self.init(scope: .fromTo(from: from, to: to), recursive: recursive, reduce: reduce)
    }
}

public extension Line {

    init(id: ID = .default(), _ immutableValue: T) {
        self.init(id: id, .plain(immutableValue))
    }

    init(id: ID = .default(), _ value: Value<T>) {
        self.init(id: id, value: value)
    }
}

public extension Group {

    init(id: ID = .default(), outcome: GroupOutcome<T>, @Calc<T>.GroupBuilder items: () -> [Item<T>]) {
        self.init(id: id, items: items(), outcome: outcome)
    }
}

public extension Item {

    static func value(_ value: T, id: ID = .default()) -> Item {
        .line(.init(id: id, value))
    }

    static func value(_ value: T, id idString: String) -> Item {
        self.value(value, id: .string(idString))
    }

    static func rangeOp(from: Ref, to: Ref, recursive: Bool, id: ID = .default(), reduce: @escaping ([T]) -> T)
    -> Item {
        .line(
            .init(
                id: id,
                Value.rangeOp(RangeOp(from: from, to: to, recursive: recursive, reduce: reduce))
            )
        )
    }

    static func sum(from: Ref, to: Ref, id: ID = .default()) -> Item {
        rangeOp(from: from, to: to, recursive: false, id: id, reduce: { $0.reduce(0, +) })
    }

    static func product(id: ID = .default(), from: Ref, to: Ref) -> Item {
        rangeOp(from: from, to: to, recursive: false, reduce: { $0.reduce(0, *) })
    }
}

public struct Sum {
    let from: Ref
    let to: Ref
    let id: ID

    public init(from: Ref, to: Ref, id: ID = .default()) {
        self.from = from
        self.to = to
        self.id = id
    }

    public init(fromLine: String, toLine: String, id: ID = .default()) {
        self.from = .line(fromLine)
        self.to = .line(toLine)
        self.id = id
    }
}

public struct GroupSum<T: CalcValue> {
    let id: ID
    let items: () -> [Item<T>]

    init(id: ID = .default(), @Calc<T>.GroupBuilder items: @escaping () -> [Item<T>]) {
        self.id = id
        self.items = items
    }
}
