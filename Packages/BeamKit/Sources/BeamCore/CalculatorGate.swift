import Foundation

/// A calculator answer to show in root search.
public struct CalculationResult: Equatable, Sendable {
    public let expression: String
    public let value: String

    public init(expression: String, value: String) {
        self.expression = expression
        self.value = value
    }
}

/// Decides whether a query deserves a calculator row. `looksLikeCalculation` is a cheap pre-filter;
/// `shouldShow` makes the final call once the engine has answered.
public enum CalculatorGate {
    private static let keywordPrefixes = [
        "time in ", "time ", "today", "tomorrow", "yesterday", "now", "days until", "weeks until",
        "months until", "sqrt", "pi",
    ]
    private static let operatorCharacters = CharacterSet(charactersIn: "+*/^%×÷π")

    public static func looksLikeCalculation(_ input: String) -> Bool {
        let s = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !s.isEmpty else { return false }
        if s.rangeOfCharacter(from: .decimalDigits) != nil { return true }
        if s.rangeOfCharacter(from: operatorCharacters) != nil { return true }
        if keywordPrefixes.contains(where: { s.hasPrefix($0) }) { return true }
        return s.contains(" in ") || s.contains(" to ")
    }

    public static func shouldShow(input: String, result: String?, locale: Locale = .current) -> Bool {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = result?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return false }
        if value.caseInsensitiveCompare(trimmedInput) == .orderedSame { return false }
        // A bare number echoed back (possibly reformatted, e.g. "5000" → "5,000") adds nothing.
        if let inputNumber = plainNumber(trimmedInput, locale: locale), let resultNumber = plainNumber(value, locale: locale),
           inputNumber == resultNumber {
            return false
        }
        return true
    }

    /// Parses a plain number written with `locale`'s grouping and decimal separators.
    private static func plainNumber(_ s: String, locale: Locale) -> Decimal? {
        let grouping = locale.groupingSeparator ?? ","
        let decimal = locale.decimalSeparator ?? "."
        let stripped = s
            .replacingOccurrences(of: grouping, with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: decimal, with: ".")
        guard !stripped.isEmpty, stripped.allSatisfy({ $0.isNumber || $0 == "." || $0 == "-" }) else { return nil }
        return Decimal(string: stripped)
    }
}
