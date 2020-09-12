import Foundation

public indirect enum Item<T: CalcValue, D: Descriptor>: Equatable {
    case line(Line<T, D>)
    case group(Group<T, D>)

    var id: ID {
        switch self {
        case let .group(group):
            return group.id
        case let .line(line):
            return line.id
        }
    }

    var descriptor: D? {
        switch self {
        case let .group(group):
            return group.descriptor
        case let .line(line):
            return line.descriptor
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
    case byID(ID)

    init(_ idString: String) {
        self = .byID(.init(idString))
    }
}

public struct Line<T: CalcValue, D: Descriptor>: Equatable {
    let id: ID
    let value: Value<T>
    let descriptor: D?
}

public struct Group<T: CalcValue, D: Descriptor>: Equatable {
    let id: ID
    let items: [Item<T, D>]
    let outcome: GroupOutcome<T, D>
    let descriptor: D?
}

public enum GroupOutcome<T: CalcValue, D: Descriptor>: Equatable {
    case sum(ID = .default(), D?)
    case product(ID = .default(), D?)
    case line(Line<T, D>)
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

    init(id: ID = .default(), _ immutableValue: T, descriptor: D?) {
        self.init(id: id, .plain(immutableValue), descriptor: descriptor)
    }

    init(id: ID = .default(), _ value: Value<T>, descriptor: D?) {
        self.init(id: id, value: value, descriptor: descriptor)
    }
}

public extension Group {

    init(id: ID = .default(), outcome: GroupOutcome<T, D>, _ descriptor: D?, @Calc<T, D>.GroupBuilder items: () -> [Item<T, D>]) {
        self.init(id: id, items: items(), outcome: outcome, descriptor: descriptor)
    }
}

public extension Item {

    static func value(_ value: T, id: ID = .default(), descriptor: D?) -> Item {
        .line(.init(id: id, value, descriptor: descriptor))
    }

    static func value(_ value: T, id idString: String, descriptor: D?) -> Item {
        self.value(value, id: .string(idString), descriptor: descriptor)
    }

    static func rangeOp(from: Ref, to: Ref, recursive: Bool, id: ID = .default(), descriptor: D?, reduce: @escaping ([T]) -> T)
    -> Item {
        .line(
            .init(
                id: id,
                Value.rangeOp(RangeOp(from: from, to: to, recursive: recursive, reduce: reduce)),
                descriptor: descriptor
            )
        )
    }

    static func sum(from: Ref, to: Ref, id: ID = .default(), descriptor: D?) -> Item {
        rangeOp(from: from, to: to, recursive: false, id: id, descriptor: descriptor, reduce: { $0.reduce(0, +) })
    }

    static func product(id: ID = .default(), from: Ref, to: Ref, descriptor: D?) -> Item {
        rangeOp(from: from, to: to, recursive: false, descriptor: descriptor, reduce: { $0.reduce(0, *) })
    }
}

public struct Sum<D: Descriptor> {
    let from: Ref
    let to: Ref
    let id: ID
    let descriptor: D?

    public init(from: Ref, to: Ref, id: ID = .default(), descriptor: D?) {
        self.from = from
        self.to = to
        self.id = id
        self.descriptor = descriptor
    }

    public init(fromLine: String, toLine: String, id: ID = .default(), descriptor: D? = nil) {
        self.from = .init(fromLine)
        self.to = .init(toLine)
        self.id = id
        self.descriptor = descriptor
    }

    public init(fromLine: String, toLine: String, id: String, descriptor: D? = nil) {
        self.init(fromLine: fromLine, toLine: toLine, id: ID.string(id), descriptor: descriptor)
    }
}

public struct GroupSum<T: CalcValue, D: Descriptor> {
    let id: ID
    let items: () -> [Item<T, D>]
    let descriptor: D?

    init(id: ID = .default(), descriptor: D? = nil, @Calc<T, D>.GroupBuilder items: @escaping () -> [Item<T, D>]) {
        self.id = id
        self.items = items
        self.descriptor = descriptor
    }

    init(_ idString: String, descriptor: D? = nil, @Calc<T, D>.GroupBuilder items: @escaping () -> [Item<T, D>]) {
        self.init(id: .string(idString), descriptor: descriptor, items: items)
    }
}
