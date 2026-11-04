import Foundation
import Testing
@testable import CleanyCore

@Suite struct CleanupHistoryTests {
    private func entry(_ minutesAgo: Double, stopped: Int, cores: Double, now: Date) -> CleanupHistory.Entry {
        .init(date: now.addingTimeInterval(-minutesAgo * 60), stopped: stopped, freedCores: cores, names: ["x"])
    }

    @Test func recordsNewestFirstAndSkipsEmptyCleanups() {
        let now = Date()
        var history = CleanupHistory(defaults: nil)
        history.record(entry(10, stopped: 2, cores: 1.5, now: now))
        history.record(entry(5, stopped: 0, cores: 0, now: now))
        history.record(entry(1, stopped: 1, cores: 0.5, now: now))
        #expect(history.entries.map(\.stopped) == [1, 2])
    }

    @Test func keepsOnlyTheLatestEntries() {
        let now = Date()
        var history = CleanupHistory(defaults: nil)
        for i in 0..<(CleanupHistory.limit + 5) { history.record(entry(Double(100 - i), stopped: i + 1, cores: 1, now: now)) }
        #expect(history.entries.count == CleanupHistory.limit)
        #expect(history.entries.first?.stopped == CleanupHistory.limit + 5)
    }

    @Test func persistsAcrossInstances() {
        let defaults = UserDefaults.ephemeral()
        var history = CleanupHistory(defaults: defaults)
        history.record(entry(1, stopped: 3, cores: 2.25, now: Date()))
        #expect(CleanupHistory(defaults: defaults).entries == history.entries)
    }

    @Test func totalsCountOnlyTheWindow() {
        let now = Date()
        var history = CleanupHistory(defaults: nil)
        history.record(entry(60 * 24 * 8, stopped: 9, cores: 9, now: now))
        history.record(entry(60, stopped: 2, cores: 1.5, now: now))
        history.record(entry(5, stopped: 1, cores: 0.5, now: now))
        let week = history.totals(since: now.addingTimeInterval(-7 * 86_400))
        #expect(week.stopped == 3)
        #expect(week.freedCores == 2)
    }
}
