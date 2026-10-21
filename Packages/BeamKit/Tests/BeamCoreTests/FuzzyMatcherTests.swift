import Testing
@testable import BeamCore

@Suite struct FuzzyMatcherTests {
    @Test func exact() { #expect(FuzzyMatcher.match("safari", in: "Safari")?.tier == .exact) }
    @Test func prefix() { #expect(FuzzyMatcher.match("term", in: "Terminal")?.tier == .prefix) }
    @Test func wordPrefix() { #expect(FuzzyMatcher.match("chrome", in: "Google Chrome")?.tier == .wordPrefix) }
    @Test func initials() {
        #expect(FuzzyMatcher.match("vsc", in: "Visual Studio Code")?.tier == .wordInitials)
        #expect(FuzzyMatcher.match("gc", in: "Google Chrome")?.tier == .wordInitials)
    }
    @Test func substring() { #expect(FuzzyMatcher.match("print", in: "Sprint 42 board")?.tier == .substring) }
    @Test func subsequence() { #expect(FuzzyMatcher.match("tms", in: "Microsoft Teams")?.tier == .subsequence) }
    @Test func noMatch() { #expect(FuzzyMatcher.match("xyz", in: "Safari") == nil) }
    @Test func emptyQuery() { #expect(FuzzyMatcher.match("", in: "Safari") == nil) }
    @Test func caseAndDiacriticInsensitive() { #expect(FuzzyMatcher.match("cafe", in: "Café Notes")?.tier == .prefix) }
    @Test func tighterSubsequenceScoresHigher() {
        #expect(FuzzyMatcher.match("ct", in: "Cat")! > FuzzyMatcher.match("ct", in: "Cabinet")!)
    }
    @Test func tierOrdering() {
        #expect(FuzzyMatcher.match("term", in: "Terminal")! > FuzzyMatcher.match("term", in: "Intermediate")!)
    }

    @Test func minimumTierSkipsSubsequence() {
        #expect(FuzzyMatcher.match("vsc", in: "Visual Studio Code")?.tier == .wordInitials)
        #expect(FuzzyMatcher.match("vdc", in: "Visual Studio Code")?.tier == .subsequence)
        #expect(FuzzyMatcher.match("vdc", in: "Visual Studio Code", minimumTier: .substring) == nil)
        #expect(FuzzyMatcher.match("studio", in: "Visual Studio Code", minimumTier: .substring)?.tier == .wordPrefix)
    }
}
