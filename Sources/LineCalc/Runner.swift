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
            return CalcResult(groupResult: calcGroupResult(base.groupResult, calcResult: base))
        }

        public static func calcItemResult(_ itemResult: ItemResult, calcResult: CalcResult) -> ItemResult {
            switch itemResult {
            case let .line(lineResult):
                return .line(calcLineResult(lineResult, calcResult: calcResult))
            case let .group(groupResult):
                return .group(calcGroupResult(groupResult, calcResult: calcResult))
            }
        }

        public static func calcGroupResult(_ groupResult: GroupResult, calcResult: CalcResult) -> GroupResult {
            GroupResult(
                group: groupResult.group,
                outcomeResult: calcLineResult(groupResult.outcomeResult, calcResult: calcResult),
                itemResults: groupResult.itemResults.map { calcItemResult($0, calcResult: calcResult) }
            )
        }

        public static func calcLineResult(_ lineResult: LineResult, calcResult: CalcResult) -> LineResult {
            LineResult(
                line: lineResult.line,
                valueResult: calcValueResult(
                    lineResult.valueResult,
                    line: lineResult.line,
                    calcResult: calcResult
                )
            )
        }

        public static func calcValueResult(_ valueResult: ValueResult, line: Line<T, D>, calcResult: CalcResult) -> ValueResult {
            switch valueResult {
            case .calculated, .pending, .error(.errorInRef):
                switch line.value {
                case let .plain(plainValue):
                    return .immutable(plainValue)
                case let .reference(id):
                    guard
                        let lineResult = calcResult.groupResult.firstLineResultInRange(range: .single(id))
                    else {
                        return .error(.referenceNotFound(source: line.id, missingRef: id))
                    }
                    return lineResult.valueResult
                case let .transformedReference(op):
                    guard
                        let lineResult = calcResult.groupResult.firstLineResultInRange(range: .single(op.ref))
                    else {
                        return .error(.referenceNotFound(source: line.id, missingRef: op.ref))
                    }
                    switch lineResult.valueResult {
                    case let .calculated(value):
                        return .calculated(op.op(value))
                    case let .immutable(value):
                        return .calculated(op.op(value))
                    case .pending:
                        return .calculated(op.op(0))
                    case .error:
                        return lineResult.valueResult
                    }
                case let .binaryOp(op):
                    guard let a = calcResult.groupResult.firstLineResultInRange(range: .single(op.a)) else {
                        return .error(.referenceNotFound(source: line.id, missingRef: op.a))
                    }
                    guard let b = calcResult.groupResult.firstLineResultInRange(range: .single(op.b)) else {
                        return .error(.referenceNotFound(source: line.id, missingRef: op.b))
                    }
                    if case let .error(error) = a.valueResult {
                        return .error(error)
                    }
                    if case let .error(error) = b.valueResult {
                        return .error(error)
                    }
                    guard let aValue = a.valueResult.value, let bValue = b.valueResult.value else {
                        return .pending
                    }
                    return .calculated(op.op(aValue, bValue))
                case let .ternaryOp(op):
                    guard let a = calcResult.groupResult.firstLineResultInRange(range: .single(op.a)) else {
                        return .error(.referenceNotFound(source: line.id, missingRef: op.a))
                    }
                    guard let b = calcResult.groupResult.firstLineResultInRange(range: .single(op.b)) else {
                        return .error(.referenceNotFound(source: line.id, missingRef: op.b))
                    }
                    guard let c = calcResult.groupResult.firstLineResultInRange(range: .single(op.c)) else {
                        return .error(.referenceNotFound(source: line.id, missingRef: op.c))
                    }
                    if case let .error(error) = a.valueResult {
                        return .error(error)
                    }
                    if case let .error(error) = b.valueResult {
                        return .error(error)
                    }
                    if case let .error(error) = c.valueResult {
                        return .error(error)
                    }
                    guard let aValue = a.valueResult.value, let bValue = b.valueResult.value, let cValue = c.valueResult.value else {
                        return .pending
                    }
                    return .calculated(op.op(aValue, bValue, cValue))
                case let .rangeOp(rangeOp):
                    switch rangeOp.scope {
                    case let .fromTo(from, to):
                        return reduceLineRange(
                            fromRef: from,
                            toRef: to,
                            reduce: rangeOp.reduce,
                            traversion: rangeOp.traversion,
                            forLine: line,
                            calcResult: calcResult
                        )
                    case let .group(groupId):
                        return reduceLineRange(
                            fromRef: .byID(groupId),
                            toRef: .byID(groupId),
                            reduce: rangeOp.reduce,
                            traversion: rangeOp.traversion,
                            forLine: line,
                            calcResult: calcResult
                        )
                    }
                }
            case .immutable, .error:
                return valueResult
            }
        }

        static func reduceLineRange(
            fromRef: Ref,
            toRef: Ref,
            reduce: ([T]) -> T,
            traversion: RangeTraversion,
            forLine line: Line<T, D>,
            calcResult: CalcResult
        ) -> ValueResult {
            let searchState = Calc.RangeSearchState()
            let lineResults = Array(
                calcResult.groupResult.lineResultsInRange(
                    range: .bounded(boundA: fromRef, boundB: toRef, traversion: traversion, state: searchState)
                )
            )

            switch searchState.innerState {
            case .initial:
                return .error(.rangeFromNotFound(source: line.id, rangeFromRef: fromRef))
            case let .oneBoundFound(foundBound):
                let unfoundBound = foundBound == fromRef ? toRef : fromRef
                return .error(.rangeToNotFound(source: line.id, rangeToRef: unfoundBound))
            case .finished:
                var resolvedValues = [T]()
                for lineResult in lineResults {
                    switch lineResult.valueResult {
                    case let .immutable(value), let .calculated(value):
                        resolvedValues.append(value)
                    case .pending:
                        return .pending
                    case let .error(error):
                        return .error(.errorInRef(ref: .byID(lineResult.line.id), error))
                    }
                }
                return .calculated(reduce(resolvedValues))
            }
        }
    }
}
