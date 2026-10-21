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

    @Test(arguments: [("Affinity Photo 2", "2"), ("Office 365", "365"), ("Things 3", "3"), ("Xcode 16", "16"), ("1password", "1")])
    func appNameNumberEchoHidden(input: String, result: String) {
        #expect(!CalculatorGate.shouldShow(input: input, result: result, locale: Locale(identifier: "en_US")))
    }
    @Test func percentEchoWithSpacingHidden() {
        #expect(!CalculatorGate.shouldShow(input: "100%", result: "100 %", locale: Locale(identifier: "de_DE")))
    }
    @Test func arithmeticResultMatchingAnOperandStillShown() {
        #expect(CalculatorGate.shouldShow(input: "2 * 1", result: "2", locale: Locale(identifier: "en_US")))
    }

    @Test func answerEqualToOneOfSeveralNumbersShown() {
        #expect(CalculatorGate.shouldShow(input: "max of 3 and 5", result: "5", locale: Locale(identifier: "en_US")))
    }
}
