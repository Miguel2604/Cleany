import AppIntents
import CleanyCore
import SwiftUI
import WidgetKit

struct CleanyProvider: TimelineProvider {
    /// How often the widget re-reads the snapshot on its own; the app also asks for a reload whenever
    /// the mood or the idle count changes.
    static let refreshInterval: TimeInterval = 5 * 60

    func placeholder(in context: Context) -> CleanyEntry {
        CleanyEntry(date: .now, snapshot: .widgetCalmSample())
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (CleanyEntry) -> Void) {
        let now = Date.now
        completion(CleanyEntry(date: now, snapshot: context.isPreview ? .widgetBusySample(date: now) : Self.load()))
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<CleanyEntry>) -> Void) {
        let now = Date.now
        let snapshot = Self.load()
        var entries = [CleanyEntry(date: now, snapshot: snapshot)]
        // Flip to "Open Cleany" on time even if the app never wakes the widget again.
        if let snapshot, now.timeIntervalSince(snapshot.date) <= CleanyEntry.staleAfter {
            entries.append(CleanyEntry(date: snapshot.date.addingTimeInterval(CleanyEntry.staleAfter + 1), snapshot: snapshot))
        }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(Self.refreshInterval))))
    }

    /// The app's latest snapshot from the App Group container; nil when there is none yet.
    private static func load() -> Snapshot? {
        guard let groupID = Bundle.main.object(forInfoDictionaryKey: "CleanyAppGroup") as? String,
              !groupID.hasPrefix(".") else { return nil }
        return SnapshotStore.read(groupID: groupID)
    }
}

/// The app's latest snapshot, or nothing when the app hasn't written one.
struct CleanyEntry: TimelineEntry {
    let date: Date
    let snapshot: Snapshot?

    /// Snapshots older than this mean the app isn't running; its numbers would be misleading.
    static let staleAfter: TimeInterval = 15 * 60

    var fresh: Snapshot? {
        guard let snapshot, date.timeIntervalSince(snapshot.date) <= Self.staleAfter else { return nil }
        return snapshot
    }
}

@main
struct CleanyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "app.cleany.Cleany.Widget", provider: CleanyProvider()) { entry in
            CleanyWidgetView(entry: entry)
        }
        .configurationDisplayName("Cleany")
        .description("What is draining the battery, and a button to stop the idle culprits.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct CleanyWidgetView: View {
    let entry: CleanyEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        // Tapping anywhere but the button opens the app.
        Group {
            if let snapshot = entry.fresh {
                switch family {
                case .systemMedium: MediumWidget(snapshot: snapshot)
                default: SmallWidget(snapshot: snapshot)
                }
            } else {
                StaleWidget()
            }
        }
        .containerBackground(for: .widget) { TintedGlass() }
    }
}

// MARK: - Families

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
                    CleanButton(count: snapshot.idleCount)
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
                if snapshot.idleCount > 0 { CleanButton(count: snapshot.idleCount) }
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
                        .accessibilityElement(children: .combine)
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

// MARK: - Pieces

private struct CleanButton: View {
    let count: Int

    var body: some View {
        Button(intent: CleanUpIdleIntent()) {
            InkPill(text: "Clean up \(count)")
        }
        .buttonStyle(.plain)
    }
}

/// The tinted-glass fill: a dark or light translucent layer over a blur, solid under Reduce Transparency.
private struct TintedGlass: View {
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
        .overlay(ContainerRelativeShape().strokeBorder(.white.opacity(scheme == .dark ? 0.1 : 0.6), lineWidth: 1))
    }
}

// MARK: - Samples

extension Snapshot {
    private static func sampleItem(_ category: CategoryID, _ name: String, cores: Double) -> Item {
        Item(
            id: .app(bundleID: "sample.\(name)"), category: category, name: name, symbol: Creek.symbol(category),
            judgement: Judgement(verdict: .idle, fact: "Sample", signals: []),
            cores: cores, memoryBytes: 0, processes: [], detail: [:]
        )
    }

    /// The placeholder: a calm Mac, six hours left.
    static func widgetCalmSample(date: Date = .now) -> Snapshot {
        Snapshot(
            date: date,
            battery: BatteryReading(onBattery: true, percent: 82, drainWatts: 5.2, minutesLeft: 370, healthPercent: 93, cycleCount: 221),
            coresBusy: 0.4, swapUsedBytes: 0, swapTotalBytes: 0, uptime: 3_600,
            categories: [
                CategorySummary(id: .apps, items: [sampleItem(.apps, "Safari", cores: 0.2)]),
                CategorySummary(id: .devServers, items: [sampleItem(.devServers, "Dev server", cores: 0.1)]),
            ],
            mood: .allGood
        )
    }

    /// The widget gallery: the day this app was written for. Illustrative numbers.
    static func widgetBusySample(date: Date = .now) -> Snapshot {
        let categories = [
            CategorySummary(id: .simulators, items: [sampleItem(.simulators, "Simulators", cores: 5.4)]),
            CategorySummary(id: .containers, items: [sampleItem(.containers, "Containers", cores: 1.9)]),
            CategorySummary(id: .devServers, items: [sampleItem(.devServers, "Dev servers", cores: 1.6)]),
        ]
        let items = categories.flatMap(\.items)
        return Snapshot(
            date: date,
            battery: BatteryReading(onBattery: true, percent: 64, drainWatts: 38, minutesLeft: 35, healthPercent: 93, cycleCount: 221),
            coresBusy: 10.5, swapUsedBytes: 0, swapTotalBytes: 0, uptime: 3_600,
            categories: categories,
            mood: .drainingFast,
            idleCount: 11, freedCores: items.reduce(0) { $0 + $1.cores }, reclaimable: Set(items.map(\.id))
        )
    }
}
