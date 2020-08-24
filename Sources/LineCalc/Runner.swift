import Foundation

public extension Calc {

    enum Runner {
        public static func run(_ calc: Calc) -> CalcResult {
            var result = runIteration(calc: calc, result: nil)
            (0..<calc.maxIterations).forEach { iteration in
                result = runIteration(calc: calc, result: result)
            }
            return result
        }

        public static func runIteration(calc: Calc, result: CalcResult?) -> CalcResult {
            let base = result ?? CalcResult(skeletonWithCalc:calc)
            return CalcResult(
                groupResult: .init(
                    group: calc.group,
                    itemResults: base.groupResult.itemResults.map { calcItemResult($0, calcResult: base) }
                )
            )
        }

        public static func calcItemResult(_ itemResult: ItemResult, calcResult: CalcResult) -> ItemResult {
            switch itemResult {
            case let .line(lineResult):
                return .line(
                    .init(
                        line: lineResult.line,
                        valueResult: calcValueResult(
                            lineResult.valueResult,
                            line: lineResult.line,
                            calcResult: calcResult
                        )
                    )
                )
            case let .group(groupResult):
                return .group(
                    .init(
                        group: groupResult.group,
                        itemResults: groupResult.itemResults.map { calcItemResult($0, calcResult: calcResult) }
                    )
                )
            }
        }

        public static func calcValueResult(_ valueResult: ValueResult, line: Line, calcResult: CalcResult) -> ValueResult {
            switch valueResult {
            case .calculated, .pending, .error(.errorInRef):
                switch line.value {
                case let .plain(plainValue):
                    return .immutable(plainValue)
                case let .reference(id):
                    guard let lineResult = calcResult.groupResult.itemResults.firstLineResult(id) else {
                        return .error(.referenceNotFound(line: line.id, missingRef: id))
                    }
                    return lineResult.valueResult
                case let .binaryOp(op):
                    guard let a = calcResult.groupResult.itemResults.firstLineResult(op.a) else {
                        return .error(.referenceNotFound(line: line.id, missingRef: op.a))
                    }
                    guard let b = calcResult.groupResult.itemResults.firstLineResult(op.b) else {
                        return .error(.referenceNotFound(line: line.id, missingRef: op.b))
                    }
                    guard let aValue = a.valueResult.value, let bValue = b.valueResult.value else {
                        return .pending
                    }
                    return .calculated(op.op(aValue, bValue))
                case let .rangeOp(rangeOp):
                        switch rangeOp.scope {
                        case let .fromTo(from, to):
                            return calcLineRangeOp(
                                fromLineResult: from,
                                toLineResult: to,
                                op: rangeOp.op,
                                forLine: line,
                                calcResult: calcResult
                            )
                        case let .group(groupId):
                            guard let groupResult = calcResult.groupResult.itemResults.firstGroupResult(groupId) else {
                                return .error(.rangeGroupNotFound(line: line.id, rangeGroupRef: groupId))
                            }
                            return calcLineRangeOp(
                                fromLineResult: groupResult.firstLineResult.line.id,
                                toLineResult: groupResult.lastLineResult.line.id,
                                op: rangeOp.op,
                                forLine: line,
                                calcResult: calcResult
                            )
                        }
                }
            case .immutable, .error:
                return valueResult
            }
        }

        static func calcLineRangeOp(
            fromLineResult: ID,
            toLineResult: ID,
            op: ([T]) -> T,
            forLine line: Line,
            calcResult: CalcResult
        ) -> ValueResult {
            var started = false
            var ended = false
            let lineResults = calcResult.groupResult.itemResults.lineResultsInRange(
                from: fromLineResult,
                to: toLineResult,
                started: &started,
                ended: &ended
            )
            guard started else {
                return .error(.rangeFromNotFound(line: line.id, rangeFromRef: fromLineResult))
            }
            guard ended else {
                return .error(.rangeToNotFound(line: line.id, rangeToRef: toLineResult))
            }

            var resolvedValues = [T]()
            for lineResult in lineResults {
                switch lineResult.valueResult {
                case let .immutable(value), let .calculated(value):
                    resolvedValues.append(value)
                case .pending:
                    return .pending
                case let .error(error):
                    return .error(.errorInRef(ref: lineResult.line.id, error))
                }
            }
            return .calculated(op(resolvedValues))
        }
    }

}
