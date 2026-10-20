import Foundation
import Testing
@testable import BeamCore

@Suite struct CalculatorGateTests {
    @Test func percentPhrase() { #expect(CalculatorGate.looksLikeCalculation("5 % of 5000")) }
    @Test func plainWordIsNot() { #expect(!CalculatorGate.looksLikeCalculation("chrome")) }
    @Test func emptyIsNot() { #expect(!CalculatorGate.looksLikeCalculation("   ")) }
    @Test func timeZonePhrase() { #expect(CalculatorGate.looksLikeCalculation("time in tokyo")) }
    @Test func bareNumberHidden() { #expect(!CalculatorGate.shouldShow(input: "42", result: "42")) }
    @Test func bareNumberWithFormattingHidden() {
        #expect(!CalculatorGate.shouldShow(input: "5000", result: "5,000", locale: Locale(identifier: "en_US")))
    }
    @Test func bareNumberWithGermanGroupingHidden() {
        #expect(!CalculatorGate.shouldShow(input: "5000", result: "5.000", locale: Locale(identifier: "de_DE")))
    }
    @Test func appNameWithDigitIsNotHidden() { #expect(!CalculatorGate.shouldShow(input: "1password", result: "")) }
    @Test func resultEqualToInputHidden() { #expect(!CalculatorGate.shouldShow(input: "pi", result: "pi")) }
    @Test func realResultShown() { #expect(CalculatorGate.shouldShow(input: "5 % of 5000", result: "250")) }
    @Test func nilResultHidden() { #expect(!CalculatorGate.shouldShow(input: "5 % of 5000", result: nil)) }
}
