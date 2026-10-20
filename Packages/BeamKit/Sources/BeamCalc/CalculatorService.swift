import BeamCore
import Foundation
import SoulverCore

/// Natural-language calculator backed by SoulverCore (the engine Raycast ships).
/// Personal use only under SoulverCore's licence terms.
public actor CalculatorService {
    private let calculator: Calculator
    private let rateProvider: ECBCurrencyRateProvider?
    public private(set) var lastRatesUpdate: Date?

    private let locale: Locale

    /// - Parameters:
    ///   - liveRates: fetch European Central Bank rates via `refreshRates()`; otherwise SoulverCore's
    ///     built-in rates for ~190 currencies are used.
    ///   - locale: number/date formatting; defaults to the user's region settings.
    public init(liveRates: Bool = true, locale: Locale = .current) {
        self.locale = locale
        var customization = EngineCustomization.standardWith(locale: locale)
        if liveRates {
            let provider = ECBCurrencyRateProvider()
            customization.currencyRateProvider = provider
            rateProvider = provider
        } else {
            rateProvider = nil
        }
        calculator = Calculator(customization: customization)
    }

    /// The answer for `input`, or nil when it isn't a calculation worth showing.
    public func evaluate(_ input: String) -> BeamCore.CalculationResult? {
        let expression = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard CalculatorGate.looksLikeCalculation(expression) else { return nil }
        let result = calculator.calculate(expression)
        guard !result.isEmptyResult, !result.isFailedResult, !result.isPendingResult,
              CalculatorGate.shouldShow(input: expression, result: result.stringValue, locale: locale)
        else { return nil }
        return BeamCore.CalculationResult(expression: expression, value: result.stringValue)
    }

    /// Fetches the latest ECB rates. Returns false when live rates are off or the fetch failed.
    @discardableResult
    public func refreshRates() async -> Bool {
        guard let rateProvider else { return false }
        let ok = await rateProvider.updateRates()
        if ok { lastRatesUpdate = Date() }
        return ok
    }
}
