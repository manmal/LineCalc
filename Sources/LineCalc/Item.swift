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

public enum ID: Hashable, CustomDebugStringConvertible {
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

    public var debugDescription: String {
        switch self {
        case .default:
            return "Opaque ID"
        case let .uuid(uuid):
            return uuid.uuidString
        case let .string(value):
            return value
        }
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

/// Container for `Item`s. Also acts as a `Line` via the `outcome` variable.
/// E.g. a non-recursive range operation will select the `Group`'s `outcome`
/// as if it were a `Line`. A recursive operation will select the `Group`'s
/// `items` instead, and disregard the `outcome`.
public struct Group<T: CalcValue, D: Descriptor>: Equatable {
    let id: ID
    let items: [Item<T, D>]
    let outcome: GroupOutcome<T, D>
    let descriptor: D?
}

/// A GroupOutcome can be referenced either by its own `ID`, or
/// by the containing Group's `ID`.
public enum GroupOutcome<T: CalcValue, D: Descriptor>: Equatable {
    case sum(ID = .default(), descriptor: D? = nil)
    case product(ID = .default(), D? = nil)
    case op(ID = .default(), D? = nil, op: GroupOp)
    case line(Line<T, D>)

    public struct GroupOp: Equatable {
        private let uuid = UUID()
        public let reduce: ([T]) -> T

        public init(_ reduce: @escaping ([T]) -> T) {
            self.reduce = reduce
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.uuid == rhs.uuid
        }
    }
}

public indirect enum Value<T: CalcValue>: Equatable {
    case plain(T)
    case reference(Ref)
    case transformedReference(UnaryOp<T>)
    case binaryOp(BinaryOp<T>)
    case ternaryOp(TernaryOp<T>)
    case rangeOp(RangeOp<T>)
}

public struct UnaryOp<T: CalcValue>: Equatable {
    let ref: Ref
    let op: (T) -> T

    public init(ref: Ref, op: @escaping (T) -> T) {
        self.ref = ref
        self.op = op
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.ref == rhs.ref
    }
}

public struct BinaryOp<T: CalcValue>: Equatable {
    let a: Ref
    let b: Ref
    let op: (T, T) -> T

    public init(a: Ref, b: Ref, op: @escaping (T, T) -> T) {
        self.a = a
        self.b = b
        self.op = op
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.a == rhs.a && lhs.b == rhs.b
    }
}

public struct TernaryOp<T: CalcValue>: Equatable {
    let a: Ref
    let b: Ref
    let c: Ref
    let op: (T, T, T) -> T

    public init(a: Ref, b: Ref, c: Ref, op: @escaping (T, T, T) -> T) {
        self.a = a
        self.b = b
        self.c = c
        self.op = op
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.a == rhs.a && lhs.b == rhs.b && lhs.c == rhs.c
    }
}

public struct RangeOp<T: CalcValue>: Equatable {
    let scope: Scope
    let traversion: RangeTraversion
    let reduce: ([T]) -> T

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.scope == rhs.scope
    }

    public enum Scope: Equatable {
        case fromTo(from: Ref, to: Ref)
        case group(ID)
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

public extension GroupOutcome {
    static func rangeOp(
        fromId: String,
        toId: String,
        traversion: RangeTraversion,
        id: ID = .default(),
        descriptor: D? = nil,
        reduce: @escaping ([T]) -> T
    ) -> GroupOutcome {
        .line(
            Line(
                id: id,
                .rangeOp(
                    RangeOp<T>(
                        from: .byID(.string(fromId)),
                        to: .byID(.string(toId)),
                        traversion: traversion,
                        reduce: reduce
                    )
                ),
                descriptor: descriptor
            )
        )
    }
}

public extension RangeOp {

    init(from: Ref, to: Ref, traversion: RangeTraversion, reduce: @escaping ([T]) -> T) {
        self.init(scope: .fromTo(from: from, to: to), traversion: traversion, reduce: reduce)
    }
}

public extension Line {

    init(id: ID = .default(), _ immutableValue: T, descriptor: D?) {
        self.init(id: id, .plain(immutableValue), descriptor: descriptor)
    }

    init(id: ID = .default(), _ value: Value<T>, descriptor: D? = nil) {
        self.init(id: id, value: value, descriptor: descriptor)
    }
}

public extension Group {

    init(id: ID = .default(), outcome: GroupOutcome<T, D>, descriptor: D? = nil, @Calc<T, D>.GroupBuilder items: () -> [Item<T, D>]) {
        self.init(id: id, items: items(), outcome: outcome, descriptor: descriptor)
    }
}

public extension Value {

    static func reference(_ idString: String) -> Self {
        .reference(Ref.byID(.string(idString)))
    }
}

public extension Item {

    static func value(_ value: T, id: ID = .default(), descriptor: D?) -> Item {
        .line(.init(id: id, value, descriptor: descriptor))
    }

    static func value(_ value: T, id idString: String, descriptor: D?) -> Item {
        self.value(value, id: .string(idString), descriptor: descriptor)
    }

    static func rangeOp(from: Ref, to: Ref, traversion: RangeTraversion, id: ID = .default(), descriptor: D?, reduce: @escaping ([T]) -> T)
    -> Item {
        .line(
            .init(
                id: id,
                Value.rangeOp(RangeOp(from: from, to: to, traversion: traversion, reduce: reduce)),
                descriptor: descriptor
            )
        )
    }

    static func sum(from: Ref, to: Ref, id: ID = .default(), descriptor: D?) -> Item {
        rangeOp(from: from, to: to, traversion: .shallow, id: id, descriptor: descriptor, reduce: { $0.reduce(0, +) })
    }

    static func product(id: ID = .default(), from: Ref, to: Ref, descriptor: D?) -> Item {
        rangeOp(from: from, to: to, traversion: .shallow, descriptor: descriptor, reduce: { $0.reduce(0, *) })
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
    public let id: ID
    public let items: () -> [Item<T, D>]
    public let descriptor: D?

    public init(id: ID = .default(), descriptor: D? = nil, @Calc<T, D>.GroupBuilder items: @escaping () -> [Item<T, D>]) {
        self.id = id
        self.items = items
        self.descriptor = descriptor
    }

    public init(_ idString: String, descriptor: D? = nil, @Calc<T, D>.GroupBuilder items: @escaping () -> [Item<T, D>]) {
        self.init(id: .string(idString), descriptor: descriptor, items: items)
    }
}
