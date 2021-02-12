import Foundation

public extension Item {

    enum Runner {
        public static func run(_ item: Item, iterations: Int) -> ItemResult {
            guard iterations > 0 else {
                preconditionFailure()
            }
            var result = runIteration(item: item, previousResult: nil)
            (1..<iterations).forEach { iteration in
                result = runIteration(item: item, previousResult: result)
            }
            return result
        }

        public static func runIteration(item: Item, previousResult: ItemResult?) -> ItemResult {
            let rootResult = previousResult ?? ItemResult(skeletonWithItem: item)
            return calcItemResult(rootResult, rootResult: rootResult)
        }

        public static func calcItemResult(_ itemResult: ItemResult, rootResult: ItemResult) -> ItemResult {
            switch itemResult {
            case let .line(lineResult):
                return .line(calcLineResult(lineResult, rootResult: rootResult))
            case let .group(groupResult):
                return .group(calcGroupResult(groupResult, rootResult: rootResult))
            }
        }

        public static func calcGroupResult(_ groupResult: GroupResult, rootResult: ItemResult) -> GroupResult {
            GroupResult(
                group: groupResult.group,
                outcomeResult: calcLineResult(groupResult.outcomeResult, rootResult: rootResult),
                itemResults: groupResult.itemResults.map { calcItemResult($0, rootResult: rootResult) }
            )
        }

        public static func calcLineResult(_ lineResult: LineResult, rootResult: ItemResult) -> LineResult {
            LineResult(
                line: lineResult.line,
                valueResult: calcValueResult(
                    lineResult.valueResult,
                    line: lineResult.line,
                    rootResult: rootResult
                )
            )
        }

        public static func calcValueResult(_ valueResult: ValueResult, line: Item.Line, rootResult: ItemResult)
        -> ValueResult {
            switch valueResult {
            case .calculated, .pending, .error(.errorInRef):
                switch line.value {
                case let .plain(plainValue):
                    return .immutable(plainValue)
                case let .reference(id):
                    guard
                        let lineResult = rootResult.firstLineResultInRange(range: .single(id))
                    else {
                        return .error(.referenceNotFound(source: line.key, missingRef: id))
                    }
                    return lineResult.valueResult
                case let .transformedReference(op):
                    guard
                        let lineResult = rootResult.firstLineResultInRange(range: .single(op.ref))
                    else {
                        return .error(.referenceNotFound(source: line.key, missingRef: op.ref))
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
                    guard let a = rootResult.firstLineResultInRange(range: .single(op.a)) else {
                        return .error(.referenceNotFound(source: line.key, missingRef: op.a))
                    }
                    guard let b = rootResult.firstLineResultInRange(range: .single(op.b)) else {
                        return .error(.referenceNotFound(source: line.key, missingRef: op.b))
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
                    guard let a = rootResult.firstLineResultInRange(range: .single(op.a)) else {
                        return .error(.referenceNotFound(source: line.key, missingRef: op.a))
                    }
                    guard let b = rootResult.firstLineResultInRange(range: .single(op.b)) else {
                        return .error(.referenceNotFound(source: line.key, missingRef: op.b))
                    }
                    guard let c = rootResult.firstLineResultInRange(range: .single(op.c)) else {
                        return .error(.referenceNotFound(source: line.key, missingRef: op.c))
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
                            rootResult: rootResult
                        )
                    case let .group(groupId):
                        return reduceLineRange(
                            fromRef: .byID(groupId),
                            toRef: .byID(groupId),
                            reduce: rangeOp.reduce,
                            traversion: rangeOp.traversion,
                            forLine: line,
                            rootResult: rootResult
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
            reduce: ([Double]) -> Double,
            traversion: RangeTraversion,
            forLine line: Item.Line,
            rootResult: ItemResult
        ) -> ValueResult {
            let searchState = Item.RangeSearchState()
            let lineResults = Array(
                rootResult.lineResultsInRange(
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
                var resolvedValues = [Double]()
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
