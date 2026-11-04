import Foundation

/// What past cleanups stopped and the CPU they gave back, newest first, persisted in `UserDefaults`.
/// Only cores are recorded: battery minutes saved would be a guess, so Cleany never claims them.
public struct CleanupHistory: Sendable {
    public struct Entry: Codable, Equatable, Sendable {
        public let date: Date
        public let stopped: Int
        public let freedCores: Double
        public let names: [String]

        public init(date: Date, stopped: Int, freedCores: Double, names: [String]) {
            self.date = date
            self.stopped = stopped
            self.freedCores = freedCores
            self.names = names
        }
    }

    public static let defaultsKey = "app.cleany.history"
    public static let limit = 50

    public private(set) var entries: [Entry]
    /// `UserDefaults` is documented as thread-safe but not annotated `Sendable`.
    nonisolated(unsafe) private let defaults: UserDefaults?

    /// nil keeps the history in memory only.
    public init(defaults: UserDefaults?) {
        self.defaults = defaults
        entries = defaults?.data(forKey: Self.defaultsKey)
            .flatMap { try? JSONDecoder().decode([Entry].self, from: $0) } ?? []
    }

    /// Adds a cleanup that stopped something; one that stopped nothing is not history.
    public mutating func record(_ entry: Entry) {
        guard entry.stopped > 0 else { return }
        entries = Array(([entry] + entries).prefix(Self.limit))
        defaults?.set(try? JSONEncoder().encode(entries), forKey: Self.defaultsKey)
    }

    public func totals(since start: Date) -> (stopped: Int, freedCores: Double) {
        entries.filter { $0.date >= start }.reduce((0, 0)) { ($0.0 + $1.stopped, $0.1 + $1.freedCores) }
    }
}
