import Foundation
import Testing
@testable import BeamCalc

@Suite struct CalculatorServiceTests {
    let calc = CalculatorService(liveRates: false, locale: Locale(identifier: "en_US"))

    @Test func percentOf() async { #expect(await calc.evaluate("5 % of 5000")?.value == "250") }
    @Test func addition() async { #expect(await calc.evaluate("123 + 456")?.value == "579") }
    @Test func units() async { #expect(await calc.evaluate("65 kg in pounds")?.value.hasPrefix("143.3") == true) }
    @Test func currency() async { #expect(await calc.evaluate("10 usd in eur") != nil) }
    @Test func plainWord() async { #expect(await calc.evaluate("chrome") == nil) }
    @Test func tip() async { #expect(await calc.evaluate("$10 for lunch + 15% tip")?.value == "$11.50") }
    @Test func followsLocaleDecimalSeparator() async {
        let german = CalculatorService(liveRates: false, locale: Locale(identifier: "de_DE"))
        #expect(await german.evaluate("1/4")?.value == "0,25")
    }
    @Test func keepsExpression() async { #expect(await calc.evaluate(" 123 + 456 ")?.expression == "123 + 456") }

    @Test(arguments: ["Affinity Photo 2", "Office 365", "Things 3", "Xcode 16", "1Password"])
    func appNamesWithNumbersAreNotCalculations(name: String) async {
        #expect(await calc.evaluate(name) == nil)
    }
    @Test func germanPercentEchoHidden() async {
        let german = CalculatorService(liveRates: false, locale: Locale(identifier: "de_DE"))
        #expect(await german.evaluate("100%") == nil)
    }

    @Test(arguments: [("average of 2 and 4 and 6", "4"), ("gcd of 12 and 4", "4"), ("lcm of 3 and 6", "6"),
                      ("max of 3 and 5", "5"), ("median of 1, 2, 3", "2")])
    func answerEqualToAnInputIsShown(input: String, expected: String) async {
        #expect(await calc.evaluate(input)?.value == expected)
    }
}
