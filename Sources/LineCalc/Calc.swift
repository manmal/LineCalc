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
    static var defaultValue: Self { get  }
}

extension Double: CalcValue {
    public static var defaultValue: Double { 0 }
}

extension Int: CalcValue {
    public static var defaultValue: Int { 0 }
}

extension Decimal: CalcValue {
    public static var defaultValue: Decimal { 0 }
}

public extension Calc {

    init(_ groupSum: GroupSum<T, D>) {
        self.group = Group(
            id: groupSum.id,
            items: groupSum.items(),
            outcome: .sum(.default(), groupSum.descriptor),
            descriptor: groupSum.descriptor
        )
    }

    enum CalcError: Error {
        case emptyGroup(ID)
    }
}
