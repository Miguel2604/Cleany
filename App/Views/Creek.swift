import AppKit
import CleanyCore
import CoreText
import SwiftUI

/// The palette, type, category names and symbols, formatters, and the dot meters. Depends only on
/// CleanyCore and SwiftUI so the widget draws the same world.
///
/// Monochrome, dot-matrix, the same language as Headroom: ink at a few opacities, Doto for numbers
/// and the verdict, Fragment Mono for everything else. Red appears once, on Stop anyway.
enum Creek {
    /// Stop anyway, and nothing else: as text, and as the button's fill under a white label (5.6:1).
    static let negative = Color(light: 0xB8392A, dark: 0xF07A65)
    static let negativeFill = Color(hex: 0xC4242A)
    /// Text and every filled mark. Explicit, because `Color.primary` fills turn grey inside the window's glass.
    static let ink = Color(light: 0x000000, dark: 0xFFFFFF)
    /// Text on an ink fill: the primary button, a selected segment, an idle pill.
    static let inverse = Color(light: 0xFFFFFF, dark: 0x000000)
    /// One lightness step above the window: an opened category, the outcome, hover.
    static let raised = ink.opacity(0.05)
    /// Hairlines between groups of rows and around segments.
    static let hairline = ink.opacity(0.14)

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

    /// "10.5" in Doto, for a headline number. Its period is a Fragment Mono one: Doto's is a small cross
    /// that reads as "10+5".
    static func coresText(_ value: Double, size: CGFloat) -> Text {
        let parts = cores(value).split(separator: ".").map(String.init)
        guard parts.count == 2 else { return Text(cores(value)).font(.doto(size)) }
        return Text("\(Text(parts[0]).font(.doto(size)))\(Text(".").font(.fragment(size * 0.6)))\(Text(parts[1]).font(.doto(size)))")
    }

    /// "35m", "2h 5m".
    static func minutes(_ value: Int) -> String {
        let value = max(0, value)
        if value < 60 { return "\(value)m" }
        let rest = value % 60
        return rest == 0 ? "\(value / 60)h" : "\(value / 60)h \(rest)m"
    }

    /// The cores of a category's items that Quick select would stop (`reclaimable`): the part of its
    /// meter that could come back. Kept items and blocked engines are not in it.
    static func idleCores(_ category: CategorySummary, reclaimable: Set<ItemIdentity>) -> Double {
        category.items.filter { reclaimable.contains($0.id) }.reduce(0) { $0 + $1.cores }
    }

    /// The categories in a fixed order, with their exact share of the CPU in use and the idle part
    /// of it. The floor of one core keeps a calm Mac mostly dim.
    static func shares(_ snapshot: Snapshot, reclaimable: Set<ItemIdentity>) -> [(id: CategoryID, share: Double, idleShare: Double)] {
        let shown = snapshot.categories.filter { $0.id != .restart && $0.cores > 0 }
        let total = max(snapshot.coresBusy, shown.reduce(0) { $0 + $1.cores }, 1)
        return CategoryID.allCases.compactMap { id in
            shown.first { $0.id == id }.map { (id, $0.cores / total, min(idleCores($0, reclaimable: reclaimable), $0.cores) / total) }
        }
    }

    /// One category's meter, on the same scale as the machine's.
    static func dots(_ id: CategoryID, in snapshot: Snapshot, reclaimable: Set<ItemIdentity>, count: Int) -> [Dot] {
        let entry = shares(snapshot, reclaimable: reclaimable).first { $0.id == id }
        return CleanyCore.dots(share: entry?.share ?? 0, idleShare: entry?.idleShare ?? 0, count: count)
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

enum Fonts {
    private static let registered: Void = {
        for url in Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [] {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }()

    /// Safe to call from anywhere, any number of times.
    static func register() { _ = registered }
}

extension Font {
    /// Doto Black, for numbers and the verdict.
    static func doto(_ size: CGFloat) -> Font {
        Fonts.register()
        return .custom("Doto-Black", fixedSize: size)
    }

    /// Fragment Mono: item names and prose as they are, labels through `lbl`.
    static func fragment(_ size: CGFloat) -> Font {
        Fonts.register()
        return .custom("FragmentMono-Regular", fixedSize: size)
    }
}

extension View {
    func num(_ size: CGFloat) -> some View { font(.doto(size)).lineLimit(1).minimumScaleFactor(0.5) }

    /// Fragment Mono, uppercase, 0.06em tracking.
    func lbl(_ size: CGFloat = 11, lines: Int = 1) -> some View {
        font(.fragment(size)).tracking(size * 0.06).textCase(.uppercase).lineLimit(lines)
    }

    /// Ink at the secondary-text opacity for the current appearance.
    func secondary() -> some View { modifier(Secondary()) }
}

private struct Secondary: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View { content.opacity(scheme == .dark ? 0.68 : 0.62) }
}

/// One dot, so meters, legends and the "?" sheet's signals draw the same three states.
struct DotMark: View {
    let dot: Dot
    var size: CGFloat = 8
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Group {
            switch dot {
            case .on: Circle().fill(Creek.ink)
            case .off: Circle().fill(Creek.ink.opacity(scheme == .dark ? 0.22 : 0.16))
            case .idle: Circle().strokeBorder(Creek.ink, lineWidth: size < 7 ? 1.25 : 1.5)
            }
        }
        .frame(width: size, height: size)
    }
}

/// Filled dots are in use, hollow dots are idle and can come back, dim dots are neither.
struct DotMeter: View {
    let dots: [Dot]
    var size: CGFloat = 8

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(dots.enumerated()), id: \.offset) { index, dot in
                if index > 0 { Spacer(minLength: 1) }
                DotMark(dot: dot, size: size)
            }
        }
        .animation(.snappy, value: dots)
        .accessibilityHidden(true)
    }
}

/// The whole machine's meter: every category's share of the CPU in use, and the idle part of it.
/// The floor of one core in `Creek.shares` keeps a calm Mac mostly dim.
struct CoreMeter: View {
    let snapshot: Snapshot
    /// What Quick select would stop: the app's quick selection, or the widget snapshot's copy of it.
    let reclaimable: Set<ItemIdentity>
    var count = 24
    var size: CGFloat = 8

    var body: some View {
        let shares = Creek.shares(snapshot, reclaimable: reclaimable)
        DotMeter(
            dots: dots(share: shares.reduce(0) { $0 + $1.share }, idleShare: shares.reduce(0) { $0 + $1.idleShare }, count: count),
            size: size
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(shares.map { "\(Creek.name($0.id)) \(Int(($0.share * 100).rounded())) percent" }.joined(separator: ", "))
    }
}

/// What the dots stand for, with the cores behind each.
struct MeterLegend: View {
    let snapshot: Snapshot
    let reclaimable: Set<ItemIdentity>

    var body: some View {
        // The same parts the meter draws, so the legend's figures add up to its dots.
        let shown = snapshot.categories.filter { $0.id != .restart && $0.cores > 0 }
        let idle = shown.reduce(0) { $0 + min(Creek.idleCores($1, reclaimable: reclaimable), $1.cores) }
        let inUse = shown.reduce(0) { $0 + $1.cores } - idle
        HStack(spacing: 14) {
            entry(.idle, value: idle, label: "idle")
            entry(.on, value: max(inUse, 0), label: "in use")
            Spacer(minLength: 0)
        }
    }

    private func entry(_ dot: Dot, value: Double, label: String) -> some View {
        HStack(spacing: 6) {
            DotMark(dot: dot)
            Text("\(Creek.cores(value)) \(label)").lbl()
        }
        .secondary()
        .accessibilityElement(children: .combine)
    }
}

/// An inverted pill: the one loud thing on a row, "2 idle", "Limit reached".
struct InkPill: View {
    let text: String
    var size: CGFloat = 11

    var body: some View {
        Text(text).lbl(size)
            .foregroundStyle(Creek.inverse)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(Creek.ink))
            .fixedSize()
    }
}
