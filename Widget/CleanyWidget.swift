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
        .containerBackground(for: .widget) { Creek.ground }
    }
}

// MARK: - Families

struct SmallWidget: View {
    let snapshot: Snapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Creek.title(snapshot.mood))
                .font(.headline)
            Text(detail(snapshot))
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            CreekBand(snapshot: snapshot, height: 8)
            Spacer(minLength: 0)
            if snapshot.idleCount > 0 { CleanButton(count: snapshot.idleCount) }
            else { Text(snapshot.mood == .allGood ? "Nothing idle is running." : "Everything is in use.").font(.caption).foregroundStyle(.secondary) }
        }
    }
}

struct MediumWidget: View {
    let snapshot: Snapshot

    /// The three categories using the most CPU; Restart is advice, not work.
    private var top: [CategorySummary] {
        Array(snapshot.categories
            .filter { $0.id != .restart && $0.cores > 0 }
            .sorted { ($0.cores, $1.id.rawValue) > ($1.cores, $0.id.rawValue) }
            .prefix(3))
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(Creek.title(snapshot.mood))
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(detail(snapshot)).font(.caption).foregroundStyle(.secondary).monospacedDigit()
                Spacer(minLength: 0)
                if snapshot.idleCount > 0 { CleanButton(count: snapshot.idleCount) }
            }
            .frame(width: 112, alignment: .leading)
            VStack(alignment: .leading, spacing: 7) {
                CoresLabel(cores: snapshot.coresBusy, size: 20)
                CreekBand(snapshot: snapshot, height: 8)
                if top.isEmpty {
                    Text("Nothing is using the CPU").font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(top, id: \.id) { category in
                        HStack(spacing: 8) {
                            Text(Creek.name(category.id)).font(.callout.weight(.medium)).lineLimit(1)
                            Spacer(minLength: 4)
                            let idle = Creek.idleCores(category)
                            if idle >= 0.05 {
                                Text("\(Creek.cores(idle)) idle").font(.caption).foregroundStyle(Creek.idle)
                            }
                            Text(Creek.cores(category.cores)).font(.callout)
                        }
                        .monospacedDigit()
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// The app isn't running (or hasn't written a snapshot): no stale numbers, just a way in.
struct StaleWidget: View {
    var body: some View {
        VStack(spacing: 6) {
            CleanyMark(size: 32, segment: false)
            Text("Open Cleany").font(.headline)
            Text("Numbers are out of date").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Pieces

/// "35m left" on battery, "10.5 cores" otherwise, as in the menu bar.
private func detail(_ snapshot: Snapshot) -> String {
    if let battery = snapshot.battery, battery.onBattery, let minutes = battery.minutesLeft { return "\(Creek.minutes(minutes)) left" }
    return "\(Creek.cores(snapshot.coresBusy)) cores"
}

private struct CleanButton: View {
    let count: Int

    var body: some View {
        Button(intent: CleanUpIdleIntent()) {
            Text("Clean up \(count)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(nsColor: .textBackgroundColor))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.primary, in: Capsule())
        }
        .buttonStyle(.plain)
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
        Snapshot(
            date: date,
            battery: BatteryReading(onBattery: true, percent: 64, drainWatts: 38, minutesLeft: 35, healthPercent: 93, cycleCount: 221),
            coresBusy: 10.5, swapUsedBytes: 0, swapTotalBytes: 0, uptime: 3_600,
            categories: [
                CategorySummary(id: .simulators, items: [sampleItem(.simulators, "Simulators", cores: 5.4)]),
                CategorySummary(id: .containers, items: [sampleItem(.containers, "Containers", cores: 1.9)]),
                CategorySummary(id: .devServers, items: [sampleItem(.devServers, "Dev servers", cores: 1.6)]),
            ],
            mood: .drainingFast,
            idleCount: 11, freedCores: 8.0
        )
    }
}
