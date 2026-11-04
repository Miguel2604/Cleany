import AppKit
import CleanyCore
import SwiftUI

/// The palette, category names and symbols, formatters, and the creek band. Depends only on
/// CleanyCore and SwiftUI so the widget draws the same world.
///
/// One hue, on data only: the green of a charging battery marks what is idle and can come back.
/// Everything else is ink and two greys. Red appears once, on Stop anyway.
enum Creek {
    /// The one data hue, as text: "idle", "2.1 cores idle", "Stopped". 4.5:1 on the window in both appearances.
    static let idle = Color(light: 0x1C7A47, dark: 0x5CD692)
    /// The same hue as a mark: the band's idle stretches and the legend dot.
    static let idleMark = Color(light: 0x2DB46E, dark: 0x4CC983)
    /// The band's in-use stretches.
    static let inUseMark = Color.primary.opacity(0.38)
    /// Stop anyway, and nothing else: as text, and as the button's fill under a white label (5.6:1).
    static let negative = Color(light: 0xB8392A, dark: 0xF07A65)
    static let negativeFill = Color(hex: 0xC4242A)
    /// The band's empty stretch, unticked boxes, quiet fills.
    static let track = Color.primary.opacity(0.08)
    /// One lightness step above the window: an opened category, the outcome, hover.
    static let raised = Color.primary.opacity(0.05)
    /// The ground under the glass, tinting the window and filling the widget. True neutral, no navy.
    static let ground = Color(light: 0xF6F6F7, dark: 0x0E0F11)

    static func name(_ id: CategoryID) -> String {
        switch id {
        case .simulators: "Simulators"
        case .containers: "Containers"
        case .devServers: "Dev servers"
        case .apps: "Apps"
        case .browserTabs: "Browser tabs"
        case .restart: "Restart"
        case .worktrees: "Worktrees"
        }
    }

    static func symbol(_ id: CategoryID) -> String {
        switch id {
        case .simulators: "iphone"
        case .containers: "shippingbox"
        case .devServers: "server.rack"
        case .apps: "square.grid.2x2"
        case .browserTabs: "globe"
        case .restart: "arrow.clockwise"
        case .worktrees: "arrow.triangle.branch"
        }
    }

    static func title(_ mood: Mood) -> String {
        switch mood {
        case .allGood: "All calm"
        case .busy: "Busy"
        case .drainingFast: "Draining fast"
        }
    }

    /// "35m left on battery · 48°C", or "Plugged in" when the temperature can't be read.
    static func batteryLine(_ snapshot: Snapshot) -> String {
        let power: String
        if let battery = snapshot.battery {
            power = battery.onBattery ? battery.minutesLeft.map { "\(minutes($0)) left on battery" } ?? "On battery" : "Plugged in"
        } else {
            power = "No battery"
        }
        return snapshot.cpuCelsius.map { "\(power) · \(Int($0.rounded()))°C" } ?? power
    }

    /// "10.5": cores always with one decimal.
    static func cores(_ value: Double) -> String { String(format: "%.1f", value) }

    /// "35m", "2h 5m".
    static func minutes(_ value: Int) -> String {
        let value = max(0, value)
        if value < 60 { return "\(value)m" }
        let rest = value % 60
        return rest == 0 ? "\(value / 60)h" : "\(value / 60)h \(rest)m"
    }

    /// The cores of a category's items that Quick select would stop (`reclaimable`): the part of its
    /// stretch that could come back. Kept items and blocked engines are not in it.
    static func idleCores(_ category: CategorySummary, reclaimable: Set<ItemIdentity>) -> Double {
        category.items.filter { reclaimable.contains($0.id) }.reduce(0) { $0 + $1.cores }
    }

    /// The band's categories in a fixed order (the order never changes, only the widths), with their
    /// exact share of the CPU in use and the idle part of it. The floor of one core keeps a calm Mac
    /// mostly empty track.
    static func shares(_ snapshot: Snapshot, reclaimable: Set<ItemIdentity>) -> [(id: CategoryID, share: Double, idleShare: Double)] {
        let shown = snapshot.categories.filter { $0.id != .restart && $0.cores > 0 }
        let total = max(snapshot.coresBusy, shown.reduce(0) { $0 + $1.cores }, 1)
        return CategoryID.allCases.compactMap { id in
            shown.first { $0.id == id }.map { (id, $0.cores / total, min(idleCores($0, reclaimable: reclaimable), $0.cores) / total) }
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }

    init(light: UInt32, dark: UInt32) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(Color(hex: hex))
        })
    }
}

/// The creek: one strip where each category's stretch is exactly its share of the CPU in use, in a
/// fixed order, split by 2 pt of water. The idle part of each stretch is green; the rest is in use.
struct CreekBand: View {
    let snapshot: Snapshot
    /// What Quick select would stop: the app's quick selection, or the widget snapshot's copy of it.
    let reclaimable: Set<ItemIdentity>
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            let shares = Creek.shares(snapshot, reclaimable: reclaimable)
            let gaps = CGFloat(max(shares.count - 1, 0)) * 2
            let width = max(geo.size.width - gaps, 0)
            HStack(spacing: 2) {
                ForEach(shares, id: \.id) { entry in
                    HStack(spacing: 0) {
                        Rectangle().fill(Creek.idleMark).frame(width: width * entry.idleShare)
                        Rectangle().fill(Creek.inUseMark)
                    }
                    .frame(width: max(2, width * entry.share))
                    .help("\(Creek.name(entry.id)): \(Int((entry.share * 100).rounded()))% of the CPU in use")
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Creek.track)
            .clipShape(.capsule)
        }
        .frame(height: height)
        .animation(.smooth(duration: 0.6), value: snapshot)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Creek.shares(snapshot, reclaimable: reclaimable).map { "\(Creek.name($0.id)) \(Int(($0.share * 100).rounded())) percent" }.joined(separator: ", "))
    }
}

/// The band's legend: each dot is the mark it explains, with the cores it stands for.
struct BandLegend: View {
    let snapshot: Snapshot
    let reclaimable: Set<ItemIdentity>

    var body: some View {
        // The same parts the band draws, so the legend's figures add up to its stretches.
        let shown = snapshot.categories.filter { $0.id != .restart && $0.cores > 0 }
        let idle = shown.reduce(0) { $0 + min(Creek.idleCores($1, reclaimable: reclaimable), $1.cores) }
        let inUse = shown.reduce(0) { $0 + $1.cores } - idle
        HStack(spacing: 14) {
            entry(Creek.idleMark, value: idle, label: "idle", ink: Creek.idle)
            entry(Creek.inUseMark, value: max(inUse, 0), label: "in use", ink: .secondary)
        }
        .font(.caption)
        .monospacedDigit()
    }

    private func entry(_ mark: Color, value: Double, label: String, ink: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(mark).frame(width: 6, height: 6)
            Text("\(Creek.cores(value)) \(label)").foregroundStyle(ink)
        }
        .accessibilityElement(children: .combine)
    }
}

/// "10.5 cores busy": the value the band measures, said once, in tabular figures.
struct CoresLabel: View {
    let cores: Double
    var size: CGFloat = 24

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(Creek.cores(cores))
                .font(.system(size: size, weight: .semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text("cores busy")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
