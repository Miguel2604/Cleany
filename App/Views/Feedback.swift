import CleanyCore
import SwiftUI

/// The top of the popover and the window: the raccoon, the mood, one sentence, then the creek band
/// with the value it measures. Cause first, text second.
struct CreekHeader: View {
    @Environment(AppModel.self) private var model
    var raccoonSize: CGFloat = 52
    var bandHeight: CGFloat = 14

    private var watching: Bool {
        model.quickSelection.count == 0 && model.snapshot.watchingUntil(now: Date()) != nil
    }

    private var sentence: String {
        guard model.hasScanned else { return "Looking around…" }
        let idle = model.quickSelection.count
        if idle > 0 { return idle == 1 ? "1 idle thing is clouding the water." : "\(idle) idle things are clouding the water." }
        if watching, let until = model.snapshot.watchingUntil(now: Date()), let hint = WatchingHint.text(until: until, now: Date()) {
            return hint
        }
        return model.snapshot.mood == .allGood ? "The water's clear." : "Busy, but everything is in use."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                LiveRaccoon(mood: Creek.raccoon(model.snapshot.mood, watching: watching), size: raccoonSize)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.hasScanned ? Creek.title(model.snapshot.mood) : "Cleany")
                        .font(raccoonSize > 60 ? .title2.weight(.semibold) : .title3.weight(.semibold))
                        .foregroundStyle(model.snapshot.mood == .drainingFast ? Creek.lantern : .primary)
                    Text(sentence)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    CoresLabel(cores: model.snapshot.coresBusy, size: raccoonSize > 60 ? 24 : 20)
                    Spacer(minLength: 8)
                    if model.hasScanned {
                        Text(Creek.batteryLine(model.snapshot))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                CreekBand(snapshot: model.snapshot, height: bandHeight, washes: model.washes)
            }
        }
    }
}

/// The raccoon, washing its paws for a few seconds after each cleanup.
struct LiveRaccoon: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let mood: RaccoonMood
    let size: CGFloat
    @State private var washingUntil: Date?

    var body: some View {
        TimelineView(.animation(paused: washingUntil == nil || reduceMotion)) { context in
            let washing = washingUntil.map { context.date < $0 } ?? false
            Raccoon(
                mood: washing ? .washing : mood, size: size,
                pawPhase: context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 0.7) / 0.7
            )
        }
        .onChange(of: model.washes) {
            let until = Date().addingTimeInterval(3.5)
            washingUntil = until
            Task {
                try? await Task.sleep(for: .seconds(3.6))
                if washingUntil == until { washingUntil = nil }
            }
        }
    }
}

/// A short message after an action: "Always kept", "Couldn't undo 1".
struct ToastState: Equatable, Identifiable {
    let id = UUID()
    let text: String

    init(_ text: String) { self.text = text }
}

struct ToastView: View {
    let toast: ToastState

    var body: some View {
        Text(toast.text)
            .font(.callout)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: .capsule)
    }
}

/// What the last Clean up did: "Stopped 3 · freed 1.2 cores", each item stopped or the reason it
/// still runs, and Undo.
struct OutcomeCard: View {
    @Environment(AppModel.self) private var model
    let outcome: CleanupOutcome
    var maxRows = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: outcome.allStopped ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(outcome.allStopped ? Creek.reed : Creek.lantern)
                VStack(alignment: .leading, spacing: 1) {
                    Text(outcome.title).font(.headline)
                    if let subtitle = outcome.subtitle {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 6)
                if outcome.canUndo {
                    Button("Undo") { Task { await model.undoLast() } }
                        .buttonStyle(.glass)
                        .controlSize(.small)
                }
                Button { model.dismissOutcome() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 24, height: 24)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Dismiss")
                .accessibilityLabel("Dismiss")
            }

            VStack(alignment: .leading, spacing: 5) {
                ForEach(outcome.entries.prefix(maxRows)) { entry in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Stone(symbol: entry.symbol, color: Creek.color(entry.category), size: 20)
                            .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
                        Text(entry.name).font(.callout).lineLimit(1).truncationMode(.middle)
                        Spacer(minLength: 6)
                        switch entry.result {
                        case .stopped:
                            Label("Stopped", systemImage: "checkmark")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Creek.reed)
                                .fixedSize()
                        case .notStopped(let reason):
                            Text(reason)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                                .lineLimit(2)
                                .frame(maxWidth: 170, alignment: .trailing)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
                if outcome.entries.count > maxRows {
                    Text("\(outcome.entries.count - maxRows) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 28)
                }
            }
        }
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }
}

/// "Clean up 4 idle · frees 3.1 cores", or a disabled "Nothing ticked" / "Nothing idle".
struct CleanUpButton: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 6) {
            let count = model.selection.count
            Button {
                Task { await model.cleanUp() }
            } label: {
                HStack(spacing: 4) {
                    if model.isCleaning { ProgressView().controlSize(.small) }
                    if count == 0 {
                        Text(model.hasTickable ? "Nothing ticked" : "Nothing idle")
                    } else {
                        Text("Clean up \(count) idle")
                        Text("· frees \(Creek.cores(model.freedCores)) cores").opacity(0.85)
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.glassProminent)
            .tint(Creek.action)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .disabled(count == 0 || model.isCleaning || model.cleanIdleInFlight)
        }
    }
}
