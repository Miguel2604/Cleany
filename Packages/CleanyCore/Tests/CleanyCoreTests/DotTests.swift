import Testing
@testable import CleanyCore

@Test func dotsFollowTheShares() {
    #expect(dots(share: 0.5, idleShare: 0.25, count: 8) == [.on, .on, .idle, .idle, .off, .off, .off, .off])
    #expect(dots(share: 1, idleShare: 1, count: 3) == [.idle, .idle, .idle])
    #expect(dots(share: 0, idleShare: 0, count: 3) == [.off, .off, .off])
}

@Test func anythingAboveZeroKeepsADot() {
    #expect(dots(share: 0.001, idleShare: 0, count: 4) == [.on, .off, .off, .off])
    #expect(dots(share: 0.5, idleShare: 0.001, count: 4) == [.on, .idle, .off, .off])
}

@Test func dotsStayInsideTheMeter() {
    #expect(dots(share: 2, idleShare: 3, count: 2) == [.idle, .idle])
    #expect(dots(share: 0.25, idleShare: 0.9, count: 4) == [.idle, .off, .off, .off])
    #expect(dots(share: -1, idleShare: -1, count: 2) == [.off, .off])
}
