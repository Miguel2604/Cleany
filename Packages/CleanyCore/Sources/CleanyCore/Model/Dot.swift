/// One dot of a meter: on is in use, idle is running but can come back, off is neither.
public enum Dot: Sendable, Equatable {
    case on, idle, off
}

/// A row of `count` dots for a share of the CPU and the idle part of it (both 0…1): in use first,
/// then idle, then off. Each state above zero keeps at least one dot, so a small cost stays visible.
public func dots(share: Double, idleShare: Double, count: Int) -> [Dot] {
    func lit(_ value: Double) -> Int {
        // The shares are sums of doubles: leftovers from rounding are not a dot.
        value > 1e-6 ? max(1, Int((value * Double(count)).rounded())) : 0
    }
    let idlePart = min(idleShare, share)
    var on = lit(share - idlePart)
    var idle = lit(idlePart)
    if on + idle > count {
        if on > idle { on = count - idle } else { idle = count - on }
    }
    return Array(repeating: .on, count: on) + Array(repeating: .idle, count: idle)
        + Array(repeating: .off, count: count - on - idle)
}
