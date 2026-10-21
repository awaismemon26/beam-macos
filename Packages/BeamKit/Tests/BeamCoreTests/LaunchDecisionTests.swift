import Testing
@testable import BeamCore

@Suite struct LaunchDecisionTests {
    func v(_ short: String, _ build: String = "1") -> AppVersion { AppVersion(short: short, build: build) }

    @Test func noOthersProceeds() {
        #expect(LaunchDecision.decide(own: v("1.1.0"), ownPID: 50, others: []) == .proceed)
    }
    @Test func olderRunningIsReplaced() {
        let d = LaunchDecision.decide(own: v("1.1.0"), ownPID: 90, others: [(pid: 50, version: v("1.0.0"))])
        #expect(d == .replace(50))
    }
    @Test func newerRunningGetsHandOff() {
        let d = LaunchDecision.decide(own: v("1.0.0"), ownPID: 50, others: [(pid: 90, version: v("1.1.0"))])
        #expect(d == .handOff(to: 90))
    }
    @Test func equalVersionsLowerPIDWins() {
        let d = LaunchDecision.decide(own: v("1.1.0"), ownPID: 50, others: [(pid: 90, version: v("1.1.0"))])
        #expect(d == .proceed)
    }
    @Test func equalVersionsHigherPIDHandsOff() {
        let d = LaunchDecision.decide(own: v("1.1.0"), ownPID: 90, others: [(pid: 50, version: v("1.1.0"))])
        #expect(d == .handOff(to: 50))
    }
    @Test func buildBreaksTie() {
        let d = LaunchDecision.decide(own: v("1.1.0", "5"), ownPID: 90, others: [(pid: 50, version: v("1.1.0", "4"))])
        #expect(d == .replace(50))
    }
    @Test func comparedAgainstTheBestOfSeveralOthers() {
        let others = [(pid: Int32(20), version: v("1.0.0")), (pid: Int32(30), version: v("1.2.0")), (pid: Int32(40), version: v("1.1.0"))]
        #expect(LaunchDecision.decide(own: v("1.1.0"), ownPID: 50, others: others) == .handOff(to: 30))
    }
    @Test func versionsCompareNumerically() {
        #expect(v("1.10.0") > v("1.9.9"))
        #expect(v("1.1") == v("1.1.0"))
        #expect(v("1.1.0", "10") > v("1.1.0", "9"))
        #expect(v("x.y") == v("0"))
    }

    @Test func applicationsPathIsAlwaysRepointed() {
        #expect(LoginItemPolicy.shouldRepointLoginItem(bundlePath: "/Applications/Beam.app", currentTargetExists: true))
    }
    @Test func strayCopyKeepsAnExistingTarget() {
        #expect(!LoginItemPolicy.shouldRepointLoginItem(bundlePath: "/Users/x/Downloads/Beam.app", currentTargetExists: true))
    }
    @Test func strayCopyRepointsWhenTargetIsGone() {
        #expect(LoginItemPolicy.shouldRepointLoginItem(bundlePath: "/Users/x/Downloads/Beam.app", currentTargetExists: false))
    }
}
