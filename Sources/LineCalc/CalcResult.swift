import Foundation
import NonEmpty

public extension Calc {

    struct CalcResult {
        let groupResult: GroupResult
    }

    indirect enum ItemResult {
        case line(LineResult)
        case group(GroupResult)
    }

    struct LineResult {
        let line: Line
        let valueResult: ValueResult
    }

    struct GroupResult {
        let group: Group
        let itemResults: NonEmpty<[ItemResult]>
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
        case referenceNotFound(line: ID, missingRef: ID)
        case rangeFromNotFound(line: ID, rangeFromRef: ID)
        case rangeToNotFound(line: ID, rangeToRef: ID)
        case rangeGroupNotFound(line: ID, rangeGroupRef: ID)
        case errorInRef(ref: ID, ValueError)
    }
}

extension Calc.ItemResult {

    init(skeletonWithItem item: Calc.Item) {
        switch item {
        case let .group(group):
            self = .group(
                .init(
                    group: group,
                    itemResults: group.items.map(Self.init(skeletonWithItem:))
                )
            )
        case let .line(line):
            let valueResult: Calc.ValueResult = {
                switch line.value {
                case let .plain(value):
                    return .immutable(value)
                case .reference, .binaryOp, .rangeOp:
                    return .pending
                }
            }()
            self = .line(.init(line: line, valueResult: valueResult))
        }
    }
}

extension Calc.CalcResult {

    init(skeletonWithCalc calc: Calc) {
        let itemResults = calc.group.items.map(Calc.ItemResult.init(skeletonWithItem:))
        groupResult = .init(group: calc.group, itemResults: itemResults)
    }
}

extension Calc.GroupResult {

    var firstLineResult: Calc.LineResult {
        switch itemResults.first {
        case let .group(groupResult):
            return groupResult.firstLineResult
        case let .line(lineResult):
            return lineResult
        }
    }

    var lastLineResult: Calc.LineResult {
        switch itemResults.last {
        case let .group(groupResult):
            return groupResult.lastLineResult
        case let .line(lineResult):
            return lineResult
        }
    }

}

public extension NonEmptyArray {
    func lineResultsInRange<Value: CalcValue>(
        from rangeFrom: Calc<Value>.ID,
        to rangeTo: Calc<Value>.ID,
        started: inout Bool,
        ended: inout Bool
    ) -> [Calc<Value>.LineResult] where Element == Calc<Value>.ItemResult {
        var lineResults = [Calc<Value>.LineResult]()
        for itemResult in self {
            guard !ended else { return lineResults }
            switch itemResult {
            case let .group(groupResult):
                lineResults.append(
                    contentsOf: groupResult.itemResults.lineResultsInRange(
                        from: rangeFrom,
                        to: rangeTo,
                        started: &started,
                        ended: &ended
                    )
                )
            case let .line(lineResult):
                if started, !ended {
                    lineResults.append(lineResult)
                    if lineResult.line.id == rangeTo {
                        ended = true
                    }
                } else if !started, lineResult.line.id == rangeFrom {
                    started = true
                    lineResults.append(lineResult)
                    if lineResult.line.id == rangeTo {
                        ended = true
                    }
                }
            }
        }
        return lineResults
    }

    func firstLineResult<Value: CalcValue>(_ id: Calc<Value>.ID) -> Calc<Value>.LineResult?
    where Element == Calc<Value>.ItemResult {
        for itemResult in self {
            switch itemResult {
            case let .line(lineResult):
                if lineResult.line.id == id {
                    return lineResult
                }
            case let .group(groupResult):
                if let lineResult = groupResult.itemResults.firstLineResult(id) {
                    return lineResult
                }
            }
        }
        return nil
    }

    func firstGroupResult<Value: CalcValue>(_ id: Calc<Value>.ID) -> Calc<Value>.GroupResult?
    where Element == Calc<Value>.ItemResult {
        for itemResult in self {
            switch itemResult {
            case .line:
                continue
            case let .group(groupResult):
                if groupResult.group.id == id {
                    return groupResult
                } else if let groupResult = groupResult.itemResults.firstGroupResult(id) {
                    return groupResult
                }
            }
        }
        return nil
    }
}
