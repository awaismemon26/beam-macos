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
        if squashed(value).caseInsensitiveCompare(squashed(trimmedInput)) == .orderedSame { return false }
        guard let resultNumber = plainNumber(value, locale: locale) else { return true }
        // A bare number echoed back (possibly reformatted, e.g. "5000" → "5,000") adds nothing.
        if plainNumber(trimmedInput, locale: locale) == resultNumber { return false }
        // Without any operator, the only number lifted out of words ("Things 3" → 3, "Office 365" → 365)
        // is noise. With several numbers ("max of 3 and 5" → 5) the answer is real.
        if trimmedInput.rangeOfCharacter(from: echoOperatorCharacters) == nil,
           numberTokens(trimmedInput, locale: locale) == [resultNumber] {
            return false
        }
        return true
    }

    private static let echoOperatorCharacters = operatorCharacters.union(CharacterSet(charactersIn: "-"))

    private static func squashed(_ s: String) -> String {
        s.filter { !$0.isWhitespace }
    }

    /// Every run of digits (with `locale`'s separators) in `s`, parsed as a number.
    private static func numberTokens(_ s: String, locale: Locale) -> [Decimal] {
        let separators = Set((locale.groupingSeparator ?? ",") + (locale.decimalSeparator ?? "."))
        return s.split { !($0.isNumber || separators.contains($0)) }
            .compactMap { plainNumber(String($0), locale: locale) }
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
