import Foundation

public extension Calc {

    struct CalcResult {
        public let groupResult: GroupResult
    }

    indirect enum ItemResult {
        case line(LineResult)
        case group(GroupResult)
    }

    struct LineResult {
        public let line: Item<D>.Line
        public let valueResult: ValueResult
    }

    struct GroupResult {
        public let group: Item<D>.Group
        public let outcomeResult: LineResult
        public let itemResults: [ItemResult]
    }

    enum ValueResult {
        case immutable(Double)
        case calculated(Double)
        case pending
        case error(ValueError)

        public var value: Double? {
            switch self {
            case let .immutable(value):
                return value
            case let .calculated(value):
                return value
            case .pending:
                return Double.pendingCalculationValue
            case .error:
                return nil
            }
        }
    }

    indirect enum ValueError: Error {
        case referenceNotFound(source: ID, missingRef: Ref)
        case rangeFromNotFound(source: ID, rangeFromRef: Ref)
        case rangeToNotFound(source: ID, rangeToRef: Ref)
        case rangeGroupNotFound(source: ID, rangeGroupRef: Ref)
        case errorInRef(ref: Ref, ValueError)
    }
}

extension Calc.ItemResult {

    init(skeletonWithItem item: Item<D>) {
        switch item {
        case let .group(group):
            self = .group(Calc.GroupResult(skeletonWithGroup: group))
        case let .line(line):
            self = .line(Calc.LineResult(skeletonWithLine: line))
        }
    }

    subscript(index: Int) -> Calc.ItemResult? {
        switch self {
        case let .group(groupResult):
            return groupResult[index]
        case .line:
            return nil
        }
    }
}

extension Calc.GroupResult {

    init(skeletonWithGroup group: Item<D>.Group) {
        let itemResults = group.items.map(Calc.ItemResult.init(skeletonWithItem:))
        self = .init(
            group: group,
            outcomeResult: Calc.LineResult(skeletonWithGroupOutcome: group.outcome, groupItemResults: itemResults),
            itemResults: itemResults
        )
    }

    subscript(index: Int) -> Calc.ItemResult? {
        guard index < itemResults.count else { return nil }
        return itemResults[index]
    }
}

extension Calc.LineResult {

    init(skeletonWithLine line: Item<D>.Line) {
        let valueResult: Calc.ValueResult = {
            switch line.value {
            case let .plain(value):
                return .immutable(value)
            case .reference, .binaryOp, .ternaryOp, .rangeOp, .transformedReference:
                return .pending
            }
        }()
        self = Calc.LineResult(line: line, valueResult: valueResult)
    }

    init(skeletonWithGroupOutcome outcome: Item<D>.GroupOutcome, groupItemResults: [Calc.ItemResult]) {
        switch outcome {
        case let .line(line):
            self.init(skeletonWithLine: line)
        case let .sum(id, descriptor):
            guard let first = groupItemResults.first, let last = groupItemResults.last else {
                // TODO return better default value
                self.init(skeletonWithLine: .init(id: id, value: .plain(0), descriptor: descriptor))
                return
            }

            self.init(
                skeletonWithLine: Item<D>.Line(
                    id: id,
                    value: .rangeOp(
                        RangeOp(from: first.ref, to: last.ref, traversion: .shallow, reduce: { $0.reduce(0, +) })
                    ),
                    descriptor: descriptor
                )
            )
        case let .product(id, descriptor):
            guard let first = groupItemResults.first, let last = groupItemResults.last else {
                // TODO return better default value
                self.init(skeletonWithLine: .init(id: id, value: .plain(0), descriptor: descriptor))
                return
            }

            self.init(
                skeletonWithLine: Item<D>.Line(
                    id: id,
                    value: .rangeOp(
                        RangeOp(from: first.ref, to: last.ref, traversion: .shallow, reduce: { $0.reduce(0, *) })
                    ),
                    descriptor: descriptor
                )
            )
        case let .op(id, descriptor, groupOp):
            guard let first = groupItemResults.first, let last = groupItemResults.last else {
                // TODO return better default value
                self.init(skeletonWithLine: .init(id: id, value: .plain(0), descriptor: descriptor))
                return
            }

            self.init(
                skeletonWithLine: Item<D>.Line(
                    id: id,
                    value: .rangeOp(
                        RangeOp(from: first.ref, to: last.ref, traversion: .shallow, reduce: groupOp.reduce)
                    ),
                    descriptor: descriptor
                )
            )
        }
        let valueResult: Calc.ValueResult = {
            switch line.value {
            case let .plain(value):
                return .immutable(value)
            case .reference, .binaryOp, .rangeOp, .ternaryOp, .transformedReference:
                return .pending
            }
        }()
        self = Calc.LineResult(line: line, valueResult: valueResult)
    }
}

extension Calc.CalcResult {

    init(skeletonWithCalc calc: Calc) {
        groupResult = Calc.GroupResult(skeletonWithGroup: calc.group)
    }
}

public extension Calc.ItemResult {

    var ref: Ref {
        switch self {
        case let .group(groupResult):
            return .byID(groupResult.group.id)
        case let .line(lineResult):
            return .byID(lineResult.line.id)
        }
    }

    var allLineResults: AnySequence<Calc.LineResult> {

        switch self {
        case let .line(lineResult):
            return .init([lineResult])
        case let .group(groupResult):
            return AnySequence(groupResult.allLineResults.lazy)
        }
    }

    func lineResultsInRange(
        range: Calc.ResultRange,
        parentGroupResult: Calc.GroupResult
    ) -> AnySequence<Calc.LineResult> {

        switch self {
        case let .line(lineResult):
            if let lineResult = lineResult.lineResultIfInRange(range: range, parentGroupResult: parentGroupResult) {
                    return .init([lineResult])
                } else {
                    return .init([])
                }
        case let .group(groupResult):
            return groupResult.lineResultsInRange(range: range)
        }
    }
}

/// Lazy collection
public extension Calc.GroupResult {

    var allLineResults: AnySequence<Calc.LineResult> {
        AnySequence<Calc.LineResult>(
            (itemResults + [Calc.ItemResult.line(outcomeResult)])
            .lazy
            .flatMap { itemResult -> AnySequence<Calc.LineResult> in
                switch itemResult {
                case let .group(groupResult):
                    return groupResult.allLineResults
                case let .line(lineResult):
                    return .init([lineResult])
                }
            }
        )
    }

    func lineResultsInRange(
        range: Calc.ResultRange
    ) -> AnySequence<Calc.LineResult> {

        AnySequence<Calc.LineResult>(
            (itemResults + [Calc.ItemResult.line(outcomeResult)])
            .lazy
            .flatMap { itemResult -> AnySequence<Calc.LineResult> in
                switch range {
                case let .bounded(_, _, _, state) where state.finished:
                    return .init([])
                case .bounded, .all:
                    break
                }

                switch itemResult {
                case let .group(groupResult):
                    switch range {
                    case .all, .bounded(_, _, .deep, _):
                        return groupResult.lineResultsInRange(range: range)
                    case let .bounded(_, _, _, state):
                        if state.started {
                            if let lineResult = groupResult.outcomeResult.lineResultIfInRange(range: range, parentGroupResult: groupResult) {
                                return .init([lineResult])
                            } else {
                                return .init([])
                            }
                        } else {
                            return groupResult.lineResultsInRange(range: range)
                        }
                    }
                case let .line(lineResult):
                    if let lineResult = lineResult.lineResultIfInRange(range: range, parentGroupResult: self) {
                        return .init([lineResult])
                    } else {
                        return .init([])
                    }
                }
            }
        )
    }

    func firstLineResultInRange(range: Calc.ResultRange) -> Calc.LineResult? {
        switch range {
        case let .bounded(boundA, boundB, traversion, state):
            switch boundA {
            case let .byID(id):
                switch id {
                case let .default(opaqueId):
                    break
                default:
                    break
                }
            default:
                break
            }
        default:
            break
        }
        return lineResultsInRange(range: range).first(where: { _ in true })
    }

    func lineResult(at ref: Ref) -> Calc.LineResult? {
        firstLineResultInRange(range: .single(ref))
    }

    func value(at ref: Ref) -> Double? {
        lineResult(at: ref)?.valueResult.value
    }

    func value(atLine lineIdString: String) -> Double? {
        value(at: .init(lineIdString))
    }

}

public extension Calc {
    enum ResultRange {
        case all
        case bounded(boundA: Ref, boundB: Ref, traversion: RangeTraversion, state: Calc.RangeSearchState = .init())

        public var isSingle: Bool {
            switch self {
            case .all:
                return false
            case let .bounded(boundA, boundB, _, _):
                return boundA == boundB
            }
        }

        public static func single(_ ref: Ref) -> ResultRange {
            bounded(boundA: ref, boundB: ref, traversion: .shallow)
        }
    }

    class RangeSearchState {
        public var innerState: InnerState = .initial

        public var finished: Bool {
            innerState == .finished
        }

        public var started: Bool {
            if case .oneBoundFound = innerState {
                return true
            } else {
                return false
            }
        }

        public init() {}

        public enum InnerState: Equatable {
            case initial
            case oneBoundFound(Ref)
            case finished
        }
    }
}

public extension Calc.LineResult {
    func lineResultIfInRange(
        range: Calc.ResultRange,
        parentGroupResult: Calc.GroupResult
    ) -> Calc<D>.LineResult? {

        func isRefDenotingLineResult(ref: Ref) -> Bool {
            switch ref {
            case let .byID(id):
                if id == line.id {
                    return true
                } else {
                    let selfIsGroupOutcomeResult = parentGroupResult.outcomeResult.line.id == line.id
                    let idDenotesParentGroup = id == parentGroupResult.group.id
                    if selfIsGroupOutcomeResult, idDenotesParentGroup {
                        return true
                    } else {
                        return false
                    }
                }
            }
        }

        switch range {
        case .all:
            return self
        case let .bounded(boundA, boundB, _, state):
            switch state.innerState {
            case .initial:
                if range.isSingle {
                    if isRefDenotingLineResult(ref: boundA) {
                        state.innerState = .finished
                        return self
                    } else {
                        return nil
                    }
                } else {
                    if isRefDenotingLineResult(ref: boundA) {
                        state.innerState = .oneBoundFound(boundA)
                        return self
                    } else if isRefDenotingLineResult(ref: boundB) {
                        state.innerState = .oneBoundFound(boundB)
                        return self
                    } else {
                        return nil
                    }
                }
            case let .oneBoundFound(previouslyFoundRef):
                if boundA != previouslyFoundRef, isRefDenotingLineResult(ref: boundA) {
                    state.innerState = .finished
                    return self
                } else if boundB != previouslyFoundRef, isRefDenotingLineResult(ref: boundB) {
                    state.innerState = .finished
                    return self
                } else {
                    return self
                }
            case .finished:
                break
            }
            return self
        }
    }
}
