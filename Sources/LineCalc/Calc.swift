import Foundation
import NonEmpty

public struct Calc<T: CalcValue> {
    let group: Group

    /// Max number of iterations _after_ the first run
    let maxIterations: Int = 10
}

public protocol CalcValue: AdditiveArithmetic & SignedNumeric & Strideable & DefaultValueProviding {}

public typealias DoubleCalc = Calc<Double>

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

    enum CalcError: Error {
        case emptyGroup(ID)
    }
}
