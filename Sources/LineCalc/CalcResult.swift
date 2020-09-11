import Foundation

public extension Calc {

    struct CalcResult {
        let groupResult: GroupResult
    }

    indirect enum ItemResult {
        case line(LineResult)
        case group(GroupResult)
    }

    struct LineResult {
        let line: Line<T>
        let valueResult: ValueResult
    }

    struct GroupResult {
        let group: Group<T>
        let outcomeResult: LineResult
        let itemResults: [ItemResult]
    }

    enum ValueResult {
        case immutable(T)
        case calculated(T)
        case pending
        case error(ValueError)

        var value: T? {
            switch self {
            case let .immutable(value):
                return value
            case let .calculated(value):
                return value
            case .pending, .error:
                return nil
            }
        }
    }

    indirect enum ValueError: Error {
        case referenceNotFound(line: ID, missingRef: Ref)
        case rangeFromNotFound(line: ID, rangeFromRef: Ref)
        case rangeToNotFound(line: ID, rangeToRef: Ref)
        case rangeGroupNotFound(line: ID, rangeGroupRef: Ref)
        case errorInRef(ref: Ref, ValueError)
    }
}

extension Calc.ItemResult {

    init(skeletonWithItem item: Item<T>) {
        switch item {
        case let .group(group):
            self = .group(Calc.GroupResult(skeletonWithGroup: group))
        case let .line(line):
            self = .line(Calc.LineResult(skeletonWithLine: line))
        }
    }
}

extension Calc.GroupResult {

    init(skeletonWithGroup group: Group<T>) {
        let itemResults = group.items.map(Calc.ItemResult.init(skeletonWithItem:))
        self = .init(
            group: group,
            outcomeResult: Calc.LineResult(skeletonWithGroupOutcome: group.outcome, groupItemResults: itemResults),
            itemResults: itemResults
        )
    }
}

extension Calc.LineResult {

    init(skeletonWithLine line: Line<T>) {
        let valueResult: Calc.ValueResult = {
            switch line.value {
            case let .plain(value):
                return .immutable(value)
            case .reference, .binaryOp, .rangeOp:
                return .pending
            }
        }()
        self = Calc.LineResult(line: line, valueResult: valueResult)
    }

    init(skeletonWithGroupOutcome outcome: GroupOutcome<T>, groupItemResults: [Calc.ItemResult]) {
        switch outcome {
        case let .line(line):
            self.init(skeletonWithLine: line)
        case let .sum(id):
            guard let first = groupItemResults.first, let last = groupItemResults.last else {
                self.init(skeletonWithLine: .init(id: id, value: .plain(0)))
                return
            }

            self.init(
                skeletonWithLine: Line<T>(
                    id: id,
                    value: .rangeOp(
                        RangeOp(from: first.ref, to: last.ref, recursive: false, reduce: { $0.reduce(0, +) })
                    )
                )
            )
        case let .product(id):
            guard let first = groupItemResults.first, let last = groupItemResults.last else {
                self.init(skeletonWithLine: .init(id: id, value: .plain(0)))
                return
            }

            self.init(
                skeletonWithLine: Line<T>(
                    id: id,
                    value: .rangeOp(
                        RangeOp(from: first.ref, to: last.ref, recursive: false, reduce: { $0.reduce(0, *) })
                    )
                )
            )
        }
        let valueResult: Calc.ValueResult = {
            switch line.value {
            case let .plain(value):
                return .immutable(value)
            case .reference, .binaryOp, .rangeOp:
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
            return .outcomeOfGroup(groupResult.group.id)
        case let .line(lineResult):
            return .line(lineResult.line.id)
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
                case .all, .bounded:
                    break
                }

                switch itemResult {
                case let .group(groupResult):
                    switch range {
                    case .all, .bounded(_, _, recursive: true, _):
                        return groupResult.lineResultsInRange(range: range)
                    case let .bounded(_, _, _, state):
                        if state.started {
                            if let lineResult = groupResult.outcomeResult.lineResultIfInRange(range: range, parentGroupResult: self) {
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
        lineResultsInRange(range: range).first(where: { _ in true })
    }

    func lineResult(at ref: Ref) -> Calc.LineResult? {
        firstLineResultInRange(range: .single(ref))
    }

    func value(at ref: Ref) -> T? {
        lineResult(at: ref)?.valueResult.value
    }

    func value(atLine lineId: ID) -> T? {
        value(at: .line(lineId))
    }

    func value(atLine lineIdString: String) -> T? {
        value(at: .line(.string(lineIdString)))
    }

}

public extension Calc {
    enum ResultRange {
        case all
        case bounded(boundA: Ref, boundB: Ref, recursive: Bool, state: Calc.RangeSearchState = .init())

        public var isSingle: Bool {
            switch self {
            case .all:
                return false
            case let .bounded(boundA, boundB, _, _):
                return boundA == boundB
            }
        }

        public static func single(_ ref: Ref) -> ResultRange {
            bounded(boundA: ref, boundB: ref, recursive: false)
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
    ) -> Calc<T>.LineResult? {

        func isRefDenotingLineResult(ref: Ref) -> Bool {
            switch ref {
            case let .line(lineId) where lineId == line.id:
                return true
            case let .outcomeOfGroup(groupId) where groupId == parentGroupResult.group.id &&
                 parentGroupResult.outcomeResult.line.id == line.id:
                // Self is the outcomeResult of its parent group, and this parent group is
                // referenced by boundA, therefore we regard self as being in range.
                return true
            case .line, .outcomeOfGroup:
                return false
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
