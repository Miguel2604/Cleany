import AppIntents
import CleanyCore
import SwiftUI
import WidgetKit

enum BackgroundOption: String, AppEnum {
    case `default`, tinted, clear

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Background"
    static let caseDisplayRepresentations: [BackgroundOption: DisplayRepresentation] = [
        .default: "Default", .tinted: "Tinted glass", .clear: "Fully clear",
    ]

    /// Default follows the choice in Cleany's Settings.
    var style: Backdrop { Backdrop(rawValue: rawValue) ?? Backdrop.saved(in: Creek.groupDefaults) }
}

struct BackgroundIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Cleany"
    @Parameter(title: "Background", default: .default) var background: BackgroundOption
}

struct CleanyProvider: AppIntentTimelineProvider {
    /// How often the widget re-reads the snapshot on its own; the app also asks for a reload whenever
    /// the mood or the idle count changes.
    static let refreshInterval: TimeInterval = 5 * 60

    func placeholder(in context: Context) -> CleanyEntry {
        CleanyEntry(date: .now, snapshot: .widgetCalmSample(), background: .default)
    }

    func snapshot(for intent: BackgroundIntent, in context: Context) async -> CleanyEntry {
        let now = Date.now
        return CleanyEntry(date: now, snapshot: context.isPreview ? .widgetBusySample(date: now) : Self.load(), background: intent.background)
    }

    func timeline(for intent: BackgroundIntent, in context: Context) async -> Timeline<CleanyEntry> {
        let now = Date.now
        let snapshot = Self.load()
        var entries = [CleanyEntry(date: now, snapshot: snapshot, background: intent.background)]
        // Flip to "Open Cleany" on time even if the app never wakes the widget again.
        if let snapshot, now.timeIntervalSince(snapshot.date) <= CleanyEntry.staleAfter {
            entries.append(CleanyEntry(date: snapshot.date.addingTimeInterval(CleanyEntry.staleAfter + 1), snapshot: snapshot, background: intent.background))
        }
        return Timeline(entries: entries, policy: .after(now.addingTimeInterval(Self.refreshInterval)))
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
    let background: BackgroundOption

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
        AppIntentConfiguration(kind: "app.cleany.Cleany.Widget", intent: BackgroundIntent.self, provider: CleanyProvider()) { entry in
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
        let content = Group {
            if let snapshot = entry.fresh {
                switch family {
                case .systemMedium: MediumWidget(snapshot: snapshot)
                default: SmallWidget(snapshot: snapshot)
                }
            } else {
                StaleWidget()
            }
        }
        switch entry.background.style {
        case .tinted: content.containerBackground(for: .widget) { TintedGlass(shape: ContainerRelativeShape()) }
        case .clear: content.clearShadow().containerBackground(for: .widget) { Color.clear }
        }
    }
}

// MARK: - Families

/// Runs the intent: the widget is sandboxed and can't stop anything itself.
struct IdleAction: View {
    let count: Int

    var body: some View {
        Button(intent: CleanUpIdleIntent()) {
            InkPill(text: "Clean up \(count)")
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
