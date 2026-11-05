import CleanyCore
import SwiftUI

// The widget's layouts and backgrounds, shared with the app's desktop panel. `IdleAction` is the one
// difference: a button that runs the intent in the widget, a plain pill on the panel.

/// 170×170: how long the battery lasts, or the cores busy, over the machine's meter.
struct SmallWidget: View {
    let snapshot: Snapshot

    private var minutesLeft: Int? {
        guard let battery = snapshot.battery, battery.onBattery else { return nil }
        return battery.minutesLeft
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(minutesLeft == nil ? "Cores busy" : "Left on battery").lbl().secondary()
            Spacer(minLength: 0)
            Group {
                if let minutesLeft {
                    Text(Creek.minutes(minutesLeft).uppercased()).font(.doto(50))
                } else {
                    Creek.coresText(snapshot.coresBusy, size: 50)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(height: 50, alignment: .leading)
            CoreMeter(snapshot: snapshot, reclaimable: snapshot.reclaimable, count: 14, size: 7).padding(.top, 12)
            Group {
                if snapshot.idleCount > 0 {
                    IdleAction(count: snapshot.idleCount)
                } else {
                    Text(Creek.title(snapshot.mood)).lbl().secondary()
                }
            }
            .frame(height: 20)
            .padding(.top, 10)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// 364×170: the mood as a headline, then the three categories using the most CPU.
struct MediumWidget: View {
    let snapshot: Snapshot

    /// The three categories using the most CPU; Restart is advice, not work.
    private var top: [CategorySummary] {
        Array(snapshot.categories
            .filter { $0.id != .restart && $0.cores > 0 }
            .sorted { ($0.cores, $1.id.rawValue) > ($1.cores, $0.id.rawValue) }
            .prefix(3))
    }

    private var line: String {
        let cores = "\(Creek.cores(snapshot.coresBusy)) cores"
        guard let battery = snapshot.battery, battery.onBattery, let minutes = battery.minutesLeft else { return cores }
        return "\(Creek.minutes(minutes)) left · \(cores)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Creek.title(snapshot.mood).uppercased()).num(34).accessibilityAddTraits(.isHeader)
            HStack {
                Text(line).lbl()
                Spacer(minLength: 8)
                if snapshot.idleCount > 0 { IdleAction(count: snapshot.idleCount) }
            }
            .frame(height: 20)
            .padding(.top, 4)
            Spacer(minLength: 0)
            if top.isEmpty {
                Text("Nothing is using the CPU").lbl().secondary()
            } else {
                VStack(spacing: 4) {
                    ForEach(top, id: \.id) { category in
                        HStack(spacing: 12) {
                            Text(Creek.name(category.id)).lbl().frame(width: 92, alignment: .leading)
                            DotMeter(dots: Creek.dots(category.id, in: snapshot, reclaimable: snapshot.reclaimable, count: 16), size: 6)
                            Creek.coresText(category.cores, size: 17).lineLimit(1).frame(width: 42, alignment: .trailing)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(Creek.name(category.id)), \(Creek.cores(category.cores)) cores, \(Creek.cores(Creek.idleCores(category, reclaimable: snapshot.reclaimable))) idle")
                    }
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// The app isn't running (or hasn't written a snapshot): no stale numbers, just a way in.
struct StaleWidget: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CleanyMark(size: 28, segment: false)
            Spacer(minLength: 0)
            Text("OPEN CLEANY").num(26)
            Text("Numbers are out of date").lbl(10, lines: 2).secondary().padding(.top, 6)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// The tinted-glass fill: a dark or light translucent layer over a blur, solid under Reduce Transparency.
struct TintedGlass<S: InsettableShape>: View {
    let shape: S
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var solid

    var body: some View {
        Group {
            if solid {
                scheme == .dark ? Color(white: 0.11) : Color(white: 0.95)
            } else {
                ZStack {
                    Rectangle().fill(.ultraThinMaterial)
                    scheme == .dark ? Color(white: 12 / 255).opacity(0.46) : Color.white.opacity(0.5)
                }
            }
        }
        .overlay(shape.strokeBorder(.white.opacity(scheme == .dark ? 0.1 : 0.6), lineWidth: 1))
        .clipShape(shape)
    }
}

extension View {
    /// The fully clear look: no fill, a soft shadow behind the content for legibility.
    func clearShadow() -> some View { modifier(ClearShadow()) }
}

private struct ClearShadow: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content.shadow(color: scheme == .dark ? .black.opacity(0.55) : .white.opacity(0.7), radius: 8, y: 1)
    }
}
