import Foundation

public struct Calc<T: CalcValue, D: Descriptor> {
    let group: Group<T, D>

    /// Max number of iterations _after_ the first run
    let maxIterations: Int = 10
}

public protocol CalcValue: AdditiveArithmetic & SignedNumeric & Strideable & DefaultValueProviding {}

public protocol Descriptor: CustomStringConvertible, Equatable {}

public typealias DoubleCalc = Calc<Double, String>

extension String: Descriptor {}

public protocol DefaultValueProviding {
    static var defaultValue: Self { get }
    static var pendingCalculationValue: Self { get }
}

extension Double: CalcValue {
    public static var defaultValue: Double { 0 }
    public static var pendingCalculationValue: Double { 0 }
}

extension Int: CalcValue {
    public static var defaultValue: Int { 0 }
    public static var pendingCalculationValue: Int { 0 }
}

extension Decimal: CalcValue {
    public static var defaultValue: Decimal { 0 }
    public static var pendingCalculationValue: Decimal { 0 }
}

public extension Calc {

    init(_ group: Group<T, D>) {
        self.group = group
    }

    init(_ groupSum: GroupSum<T, D>) {
        self.group = Group(
            id: groupSum.id,
            items: groupSum.items(),
            outcome: .sum(.default(), descriptor: groupSum.descriptor),
            descriptor: groupSum.descriptor
        )
    }

    enum CalcError: Error {
        case emptyGroup(ID)
    }
}
