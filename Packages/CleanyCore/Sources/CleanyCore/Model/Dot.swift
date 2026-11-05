/// One dot of a meter: on is in use, idle is running but can come back, off is neither.
public enum Dot: Sendable, Equatable {
    case on, idle, off
}

/// A row of `count` dots for a share of the CPU and the idle part of it (both 0…1): in use first,
/// then idle, then off. Anything above zero keeps at least one dot, so a small cost stays visible.
public func dots(share: Double, idleShare: Double, count: Int) -> [Dot] {
    func lit(_ value: Double, limit: Int) -> Int {
        value > 0 ? min(max(1, Int((value * Double(count)).rounded())), limit) : 0
    }
    let total = lit(share, limit: count)
    let idle = lit(idleShare, limit: total)
    return Array(repeating: .on, count: total - idle) + Array(repeating: .idle, count: idle)
        + Array(repeating: .off, count: count - total)
}
