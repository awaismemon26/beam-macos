import Testing
@testable import BeamCore

@Suite struct MRUListTests {
    let windows = [WindowInfo.fixture(id: 1), .fixture(id: 2), .fixture(id: 3)]

    @Test func touchMovesToFront() {
        var m = MRUList()
        m.touch(3); m.touch(1)
        #expect(m.ordered(windows).map(\.id) == [1, 3, 2])
    }
    @Test func unknownWindowsKeepInputOrder() {
        var m = MRUList()
        m.touch(2)
        #expect(m.ordered(windows).map(\.id) == [2, 1, 3])
    }
    @Test func removeForgets() {
        var m = MRUList()
        m.touch(3); m.touch(2); m.remove(2)
        #expect(m.ordered(windows).map(\.id) == [3, 1, 2])
    }
    @Test func capacityEvictsOldest() {
        var m = MRUList(capacity: 2)
        m.touch(1); m.touch(2); m.touch(3)
        #expect(m.ordered(windows).map(\.id) == [3, 2, 1])
        #expect(!m.contains(1))
    }
}
