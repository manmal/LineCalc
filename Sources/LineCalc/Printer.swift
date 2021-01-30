import Foundation

public struct Printer<D: Descriptor> {
    public typealias T = Double

    let lineLength: Int
    let maxDepth: Int

    public init(lineLength: Int = 70, maxDepth: Int = .max) {
        self.lineLength = lineLength
        self.maxDepth = maxDepth
    }

    public func print(_ calcResult: Calc<T, D>.CalcResult) -> [String] {
        print(calcResult.groupResult, level: 0)
    }

    public func print(_ groupResult: Calc<T, D>.GroupResult, level: Int) -> [String] {
        if level < maxDepth {
            let contents = groupResult.itemResults.enumerated().flatMap { print($1, level: level + 1, indexInGroup: $0) }
            let header = GroupSeparator
                .header(descriptor: groupResult.group.descriptor)
                .print(level: level, lineLength: lineLength)
            let bottomSeparator = GroupSeparator.bottomSeparator.print(level: level, lineLength: lineLength)
            let outcome = GroupSeparator
                .outcome(valueResult: groupResult.outcomeResult.valueResult, descriptor: groupResult.group.descriptor)
                .print(level: level, lineLength: lineLength)
            let emptyLine = GroupSeparator.emptyLineAboveOrBelowGroup.print(level: level, lineLength: lineLength)
            
            return [emptyLine, header].compactMap { $0 } + contents + [bottomSeparator, outcome, emptyLine].compactMap { $0 }
        } else {
            return [print(groupResult.outcomeResult, level: level, indexInGroup: 0)]
        }
    }

    public func print(_ itemResult: Calc<T, D>.ItemResult, level: Int, indexInGroup: Int) -> [String] {
        switch itemResult {
        case let .line(lineResult):
            return [print(lineResult, level: level, indexInGroup: indexInGroup)]
        case let .group(groupResult):
            return print(groupResult, level: level)
        }
    }

    public func print<D>(_ lineResult: Calc<T, D>.LineResult, level: Int, indexInGroup: Int) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.groupingSeparator = "."
        nf.decimalSeparator = ","
        nf.maximumFractionDigits = 2
        nf.minimumFractionDigits = 2

        let descriptor = lineResult.line.descriptor?.description ?? "\(indexInGroup + 1). line"
        let value = (lineResult.valueResult.value).map { nf.string(from: NSNumber(value: $0)) ?? "-" } ?? "undefined"
        let prefix: String = {
            let innerMostPrefix = "|  "
            if level == 0 {
                return ""
            } else {
                return (0...level - 1).reduce("", { prefix, _ in prefix + innerMostPrefix })
            }
        }()
        let suffix: String = {
            let innerMostSuffix = "  |"
            if level == 0 {
                return ""
            } else {
                return (0...level - 1).reduce("", { suffix, _ in suffix + innerMostSuffix })
            }
        }()
        return (prefix + descriptor).padding(toLength: lineLength - value.count - suffix.count, withPad: " ", startingAt: 0)
            + value + suffix
    }

    private func line(_ title: String, _ sign: String, _ value: String, paddingLength: Int = 60) -> String {
        var titleWithPadding = (title + ":").padding(toLength: paddingLength, withPad: " ", startingAt: 0)
        if sign.isEmpty == false {
            titleWithPadding = String(titleWithPadding.dropLast())
        }
        return titleWithPadding + sign + value + "\n"
    }
}

private extension Printer {

    private static var currencyFormatter: NumberFormatter {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.groupingSeparator = "."
        nf.decimalSeparator = ","
        nf.maximumFractionDigits = 2
        nf.minimumFractionDigits = 2
        return nf
    }

    private static func currencyString<D: Descriptor>(_ valueResult: Calc<T, D>.ValueResult) -> String {
        (valueResult.value).map { currencyFormatter.string(from: NSNumber(value: $0)) ?? "-" } ?? "undefined"
    }

    enum GroupSeparator {
        case header(descriptor: D?)
        case bottomSeparator
        case outcome(valueResult: Calc<T, D>.ValueResult, descriptor: D?)
        case emptyLineAboveOrBelowGroup

        func print(level: Int, lineLength: Int) -> String {
            let descriptor: String = {
                switch self {
                case let .header(descriptor):
                    return descriptor?.description ?? "Group"
                case .bottomSeparator, .emptyLineAboveOrBelowGroup, .outcome:
                    return ""
                }
            }()
            let prefix: String = {
                let innerMostPrefix = "|  "
                if level == 0 {
                    return ""
                } else {
                    return (0...level - 1).reduce("", { prefix, _ in prefix + innerMostPrefix })
                }
            }()
            let suffix: String = {
                let innerMostSuffix = "  |"
                if level == 0 {
                    return ""
                } else {
                    return (0...level - 1).reduce("", { suffix, _ in suffix + innerMostSuffix })
                }
            }()
            let leftMost: String = {
                switch self {
                case .header: return prefix + descriptor + " "
                case .bottomSeparator: return prefix + "·"
                case .emptyLineAboveOrBelowGroup, .outcome: return prefix + ""
                }
            }()
            let rightMost: String = {
                switch self {
                case .header: return "·" + suffix
                case .bottomSeparator: return "·" + suffix
                case .emptyLineAboveOrBelowGroup: return suffix
                case let .outcome(valueResult, descriptor):
                    let visibleDescriptor = descriptor?.description ?? "Group"
                    return "\(visibleDescriptor): " +  Printer.currencyString(valueResult) + suffix
                }
            }()
            let pad: String = {
                switch self {
                case .header, .bottomSeparator: return "-"
                case .emptyLineAboveOrBelowGroup, .outcome: return " "
                }
            }()
            return leftMost
                .padding(
                    toLength: lineLength - rightMost.count,
                    withPad: pad,
                    startingAt: 0
                )
                + rightMost
        }
    }
}
