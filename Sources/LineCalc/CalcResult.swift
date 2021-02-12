import Foundation

public extension Item {

    struct CalcResult {
        public let groupResult: GroupResult
    }

    indirect enum ItemResult {
        case line(LineResult)
        case group(GroupResult)
    }

    struct LineResult {
        public let line: Item.Line
        public let valueResult: ValueResult
    }

    struct GroupResult {
        public let group: Item.Group
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
        case referenceNotFound(source: Key, missingRef: Ref)
        case rangeFromNotFound(source: Key, rangeFromRef: Ref)
        case rangeToNotFound(source: Key, rangeToRef: Ref)
        case rangeGroupNotFound(source: Key, rangeGroupRef: Ref)
        case errorInRef(ref: Ref, ValueError)
    }
}

extension Item.ItemResult {

    init(skeletonWithItem item: Item) {
        switch item {
        case let .group(group):
            self = .group(Item.GroupResult(skeletonWithGroup: group))
        case let .line(line):
            self = .line(Item.LineResult(skeletonWithLine: line))
        }
    }

    subscript(index: Int) -> Item.ItemResult? {
        switch self {
        case let .group(groupResult):
            return groupResult[index]
        case .line:
            return nil
        }
    }
}

extension Item.GroupResult {

    init(skeletonWithGroup group: Item.Group) {
        let itemResults = group.items.map(Item.ItemResult.init(skeletonWithItem:))
        self = .init(
            group: group,
            outcomeResult: Item.LineResult(skeletonWithGroupOutcome: group.outcome, groupItemResults: itemResults),
            itemResults: itemResults
        )
    }

    subscript(index: Int) -> Item.ItemResult? {
        guard index < itemResults.count else { return nil }
        return itemResults[index]
    }
}

extension Item.LineResult {

    init(skeletonWithLine line: Item.Line) {
        let valueResult: Item.ValueResult = {
            switch line.value {
            case let .plain(value):
                return .immutable(value)
            case .reference, .binaryOp, .ternaryOp, .rangeOp, .transformedReference:
                return .pending
            }
        }()
        self = Item.LineResult(line: line, valueResult: valueResult)
    }

    init(skeletonWithGroupOutcome outcome: Item.GroupOutcome, groupItemResults: [Item.ItemResult]) {
        switch outcome {
        case let .line(line):
            self.init(skeletonWithLine: line)
        case let .sum(key):
            guard let first = groupItemResults.first, let last = groupItemResults.last else {
                // TODO return better default value
                self.init(skeletonWithLine: .init(key: key, value: .plain(0)))
                return
            }

            self.init(
                skeletonWithLine: Item.Line(
                    key: key,
                    value: .rangeOp(
                        Item.RangeOp(from: first.localRef, to: last.localRef, traversion: .shallow, reduce: { $0.reduce(0, +) })
                    )
                )
            )
        case let .product(key):
            guard let first = groupItemResults.first, let last = groupItemResults.last else {
                // TODO return better default value
                self.init(skeletonWithLine: .init(key: key, value: .plain(0)))
                return
            }

            self.init(
                skeletonWithLine: Item.Line(
                    key: key,
                    value: .rangeOp(
                        Item.RangeOp(from: first.localRef, to: last.localRef, traversion: .shallow, reduce: { $0.reduce(0, *) })
                    )
                )
            )
        case let .op(key, groupOp):
            guard let first = groupItemResults.first, let last = groupItemResults.last else {
                // TODO return better default value
                self.init(skeletonWithLine: .init(key: key, value: .plain(0)))
                return
            }

            self.init(
                skeletonWithLine: Item.Line(
                    key: key,
                    value: .rangeOp(
                        Item.RangeOp(from: first.localRef, to: last.localRef, traversion: .shallow, reduce: groupOp.reduce)
                    )
                )
            )
        }
        let valueResult: Item.ValueResult = {
            switch line.value {
            case let .plain(value):
                return .immutable(value)
            case .reference, .binaryOp, .rangeOp, .ternaryOp, .transformedReference:
                return .pending
            }
        }()
        self = Item.LineResult(line: line, valueResult: valueResult)
    }
}

public extension Item.ItemResult {

    var localRef: Item.Ref {
        switch self {
        case let .group(groupResult):
            return .local(groupResult.group.key)
        case let .line(lineResult):
            return .local(lineResult.line.key)
        }
    }

    var allLineResults: AnySequence<Item.LineResult> {

        switch self {
        case let .line(lineResult):
            return .init([lineResult])
        case let .group(groupResult):
            return AnySequence(groupResult.allLineResults.lazy)
        }
    }

    func lineResultsInRange(
        range: Item.ResultRange,
        parentGroupResult: Item.GroupResult?
    ) -> AnySequence<Item.LineResult> {

        switch self {
        case let .line(lineResult):
            guard let parentGroupResult = parentGroupResult else {
                switch range {
                case .all:
                    return .init([lineResult])
                case let .bounded(boundA, boundB, _, _):
                    if boundA == lineResult.line.key || boundB == lineResult.line.key {
                        return .init([lineResult])
                    } else {
                        return .init([])
                    }
                }
            }
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
public extension Item.GroupResult {

    var allLineResults: AnySequence<Item.LineResult> {
        AnySequence<Item.LineResult>(
            (itemResults + [Item.ItemResult.line(outcomeResult)])
            .lazy
            .flatMap { itemResult -> AnySequence<Item.LineResult> in
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
        range: Item.ResultRange
    ) -> AnySequence<Item.LineResult> {

        AnySequence<Item.LineResult>(
            (itemResults + [Item.ItemResult.line(outcomeResult)])
            .lazy
            .flatMap { itemResult -> AnySequence<Item.LineResult> in
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

    func firstLineResultInRange(range: Item.ResultRange) -> Item.LineResult? {
        return lineResultsInRange(range: range).first(where: { _ in true })
    }

    func lineResult(at ref: Item.Ref) -> Item.LineResult? {
        firstLineResultInRange(range: .single(ref))
    }

    func value(at ref: Item.Ref) -> Double? {
        lineResult(at: ref)?.valueResult.value
    }

    func value(atLine lineIdString: String) -> Double? {
        value(at: .init(lineIdString))
    }

}

public extension Item {
    enum ResultRange {
        case all
        case bounded(boundA: Ref, boundB: Ref, traversion: RangeTraversion, state: Item.RangeSearchState = .init())

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

public extension Item.LineResult {
    func lineResultIfInRange(
        range: Item.ResultRange,
        parentGroupResult: Item.GroupResult
    ) -> Item.LineResult? {

        func isRefDenotingLineResult(ref: Item.Ref) -> Bool {
            switch ref {
            case let .local(localKey):
                return line.key == localKey
            case let .global(globalKey):
                return line.key == globalKey
            }

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
