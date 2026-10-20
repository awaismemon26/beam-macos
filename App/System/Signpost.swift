import os

let log = Logger(subsystem: "dev.beam.Beam", category: "general")

/// Performance intervals, visible in Instruments' os_signpost / Points of Interest.
enum Signpost {
    static let signposter = OSSignposter(subsystem: "dev.beam.Beam", category: .pointsOfInterest)

    static func begin(_ name: StaticString) -> OSSignpostIntervalState {
        signposter.beginInterval(name, id: signposter.makeSignpostID())
    }

    static func end(_ name: StaticString, _ state: OSSignpostIntervalState) {
        signposter.endInterval(name, state)
    }
}
