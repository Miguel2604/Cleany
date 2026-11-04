import AppKit
import CleanyCore
import SwiftUI

/// The night-creek palette, category names and symbols, formatters, and the creek band. Depends only
/// on CleanyCore and SwiftUI so the widget draws the same world.
enum Creek {
    /// The water: deep blue-green at night, pale creek at dawn. Tints the window's glass.
    static let water = Color(light: 0xD5E8E2, dark: 0x0B2226)
    static let deepWater = Color(light: 0xBCD8D0, dark: 0x061719)
    /// The one action tint (Clean up, Stop). Dark enough for white labels in both appearances.
    static let action = Color(hex: 0x2E7A4E)
    /// "idle", "Safe", "Stopped": reed green, readable as text on the water.
    static let reed = Color(light: 0x25693F, dark: 0x8BD69F)
    /// Draining fast and "check".
    static let lantern = Color(light: 0x8F5200, dark: 0xF3B249)
    /// Stop anyway, and nothing else.
    static let coral = Color(light: 0xB8392A, dark: 0xF07A65)
    /// The water under the glass: lighter at the surface, deeper below.
    static let depth = LinearGradient(colors: [water.opacity(0.55), deepWater.opacity(0.85)], startPoint: .top, endPoint: .bottom)
    /// The band's empty water and empty ticks.
    static let track = Color.primary.opacity(0.10)

    static func color(_ id: CategoryID) -> Color {
        switch id {
        case .simulators: Color(light: 0x95641A, dark: 0xE9B872)
        case .containers: Color(light: 0x2D66A3, dark: 0x82B4E8)
        case .devServers: Color(light: 0x6A4EC0, dark: 0xB8A4F2)
        case .apps: Color(light: 0xA3446A, dark: 0xEBA3BA)
        case .browserTabs: Color(light: 0x1F7385, dark: 0x8ED5E5)
        case .restart: Color(light: 0x56625F, dark: 0x93A19E)
        case .worktrees: Color(light: 0x4A5DBE, dark: 0xA2B5FF)
        }
    }

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
        case .containers: "shippingbox.fill"
        case .devServers: "server.rack"
        case .apps: "square.grid.2x2.fill"
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

    static func raccoon(_ mood: Mood, watching: Bool = false) -> RaccoonMood {
        switch mood {
        case .allGood: .calm
        case .busy: watching ? .watching : .busy
        case .drainingFast: .worried
        }
    }

    /// "35m left on battery", or "Plugged in".
    static func batteryLine(_ snapshot: Snapshot) -> String {
        guard let battery = snapshot.battery else { return "No battery" }
        guard battery.onBattery else { return "Plugged in" }
        return battery.minutesLeft.map { "\(minutes($0)) left on battery" } ?? "On battery"
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

    /// The band's categories in a fixed order (the order never changes, only the widths), with their
    /// exact share of the CPU in use. The floor of one core keeps a calm Mac mostly open water.
    static func shares(_ snapshot: Snapshot) -> [(id: CategoryID, share: Double)] {
        let shown = snapshot.categories.filter { $0.id != .restart && $0.cores > 0 }
        let total = max(snapshot.coresBusy, shown.reduce(0) { $0 + $1.cores }, 1)
        return CategoryID.allCases.compactMap { id in
            shown.first { $0.id == id }.map { (id, $0.cores / total) }
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

/// The creek: one strip of water where each category's stretch is exactly its share of the CPU in
/// use, in a fixed order. `washes` changing sends a ripple across it.
struct CreekBand: View {
    let snapshot: Snapshot
    var height: CGFloat = 14
    var washes = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ripple: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            let shares = Creek.shares(snapshot)
            let gaps = CGFloat(max(shares.count - 1, 0)) * 2
            HStack(spacing: 2) {
                ForEach(shares, id: \.id) { entry in
                    Rectangle()
                        .fill(Creek.color(entry.id))
                        .frame(width: max(2, (geo.size.width - gaps) * entry.share))
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Creek.track)
            .overlay {
                // The ripple: a bright crest crossing the water after a cleanup.
                LinearGradient(colors: [.clear, .white.opacity(0.55), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: geo.size.width * 0.35)
                    .offset(x: ripple * geo.size.width)
                    .opacity(ripple > -1 && ripple < 1 ? 1 : 0)
            }
            .clipShape(.rect(cornerRadius: height / 2.5, style: .continuous))
        }
        .frame(height: height)
        .animation(.smooth(duration: 0.6), value: snapshot)
        .onChange(of: washes) {
            guard !reduceMotion else { return }
            ripple = -0.35
            withAnimation(.easeOut(duration: 1.1)) { ripple = 1 }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Creek.shares(snapshot).map { "\(Creek.name($0.id)) \(Int(($0.share * 100).rounded())) percent" }.joined(separator: ", "))
    }
}

/// "10.5 cores busy": the value the band measures, said once, with rounded numerals.
struct CoresLabel: View {
    let cores: Double
    var size: CGFloat = 20

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(Creek.cores(cores))
                .font(.system(size: size, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text("cores busy")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A category's SF Symbol on a small tinted stone; its color matches its stretch of the band.
struct Stone: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 26

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
            .fill(color.opacity(0.22))
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.48, weight: .semibold))
                    .foregroundStyle(color)
            }
    }
}
