import CleanyCore
import SwiftUI

/// The top of the popover and the window: the mood as a headline with the one finding and the
/// battery under it, then the cores busy over their meter. Cause first, text second.
struct VerdictHeader: View {
    @Environment(AppModel.self) private var model
    var titleSize: CGFloat = 30

    private var watching: Bool {
        model.quickSelection.count == 0 && model.snapshot.watchingUntil(now: Date()) != nil
    }

    /// The finding: what is idle and what it costs, or why nothing is.
    private var sentence: String {
        guard model.hasScanned else { return "Looking around…" }
        let idle = model.quickSelection.count
        if idle > 0 {
            let cores = Creek.cores(model.quickSelection.freedCores(in: model.snapshot))
            return idle == 1 ? "1 idle thing is using \(cores) cores" : "\(idle) idle things are using \(cores) cores"
        }
        if watching, let until = model.snapshot.watchingUntil(now: Date()), let hint = WatchingHint.text(until: until, now: Date()) {
            return hint
        }
        return model.snapshot.mood == .allGood ? "Nothing idle is running" : "Busy, and everything is in use"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text((model.hasScanned ? Creek.title(model.snapshot.mood) : "Cleany").uppercased())
                    .num(titleSize)
                    .accessibilityAddTraits(.isHeader)
                Text(sentence).lbl()
                if model.hasScanned { Text(Creek.batteryLine(model.snapshot)).lbl().secondary() }
            }
            .accessibilityElement(children: .combine)
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center) {
                    Text("Cores busy").lbl()
                    Spacer(minLength: 8)
                    Creek.coresText(model.snapshot.coresBusy, size: 20)
                        .lineLimit(1)
                        .contentTransition(.numericText())
                }
                .frame(height: 20)
                .accessibilityElement(children: .combine)
                let reclaimable = model.quickSelection.ticked
                CoreMeter(snapshot: model.snapshot, reclaimable: reclaimable)
                if model.hasScanned { MeterLegend(snapshot: model.snapshot, reclaimable: reclaimable).padding(.top, 2) }
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
            .lbl()
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: .capsule)
    }
}

/// What the last Clean up did: "Stopped 3 · freed 1.2 cores", each item stopped or the reason it
/// still runs, and Undo. One lightness step above the window.
struct OutcomeCard: View {
    @Environment(AppModel.self) private var model
    let outcome: CleanupOutcome
    var maxRows = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(outcome.title).lbl()
                    if let subtitle = outcome.subtitle {
                        Text(subtitle).lbl().secondary()
                    }
                }
                Spacer(minLength: 6)
                if outcome.canUndo {
                    Button("Undo") { Task { await model.undoLast() } }
                        .buttonStyle(OutlineButtonStyle())
                        .disabled(model.isCleaning || model.cleanIdleInFlight)
                }
                Button { model.dismissOutcome() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Dismiss")
                .accessibilityLabel("Dismiss")
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(outcome.entries.prefix(maxRows)) { entry in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: entry.symbol)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(width: 18)
                        Text(entry.name).font(.fragment(12)).lineLimit(1).truncationMode(.middle)
                        Spacer(minLength: 6)
                        switch entry.result {
                        case .stopped:
                            Text("Stopped").lbl().fixedSize()
                        case .notStopped(let reason):
                            Text(reason)
                                .lbl(10, lines: 2)
                                .secondary()
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 170, alignment: .trailing)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
                if outcome.entries.count > maxRows {
                    Text("\(outcome.entries.count - maxRows) more")
                        .lbl()
                        .secondary()
                        .padding(.leading, 28)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Creek.raised))
    }
}

/// The one primary control, made primary by inversion: an ink plate with the window's color for its
/// label. Pressing dims and settles it; disabled, it drops to a hairline.
struct InkButtonStyle: ButtonStyle {
    /// Replaces the ink for the one destructive case (Stop anyway); its label turns white.
    var fill: Color?
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let plate = RoundedRectangle(cornerRadius: 8, style: .continuous)
        configuration.label
            .lbl(11.5)
            .foregroundStyle(isEnabled ? (fill == nil ? Creek.inverse : .white) : .secondary)
            .frame(maxWidth: .infinity, minHeight: 34)
            .padding(.horizontal, 12)
            .background(plate.fill(isEnabled ? (fill ?? Creek.ink) : .clear))
            .overlay(plate.strokeBorder(isEnabled ? .clear : Creek.hairline))
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
            .contentShape(plate)
    }
}

/// A secondary control: an outlined label that inverts under the pointer.
struct OutlineButtonStyle: ButtonStyle {
    var minHeight: CGFloat = 22
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        OutlineLabel(configuration: configuration, minHeight: minHeight).opacity(isEnabled ? 1 : 0.4)
    }

    private struct OutlineLabel: View {
        let configuration: Configuration
        let minHeight: CGFloat
        @State private var hovering = false
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            let inverted = hovering && isEnabled
            let plate = RoundedRectangle(cornerRadius: 6, style: .continuous)
            configuration.label
                .lbl()
                .foregroundStyle(inverted ? Creek.inverse : Creek.ink)
                .padding(.horizontal, 8)
                .frame(minHeight: minHeight)
                .background(plate.fill(inverted ? Creek.ink : .clear))
                .overlay(plate.strokeBorder(Creek.ink.opacity(0.45)))
                .opacity(configuration.isPressed ? 0.82 : 1)
                .contentShape(plate)
                .onHover { hovering = $0 }
        }
    }
}

/// "Clean up 4 idle · frees 3.1 cores", or a quiet "Nothing ticked" / "Nothing idle".
struct CleanUpButton: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let count = model.selection.count
        Button {
            Task { await model.cleanUp() }
        } label: {
            HStack(spacing: 8) {
                if model.isCleaning { ProgressView().controlSize(.small) }
                if count == 0 {
                    Text(model.hasTickable ? "Nothing ticked" : "Nothing idle")
                } else {
                    // "idle" only when it is true of every ticked item: Choose myself can tick apps
                    // the engine never calls idle.
                    Text(model.selectionIsAllIdle ? "Clean up \(count) idle" : "Clean up \(count)")
                    Text("frees \(Creek.cores(model.freedCores)) cores").opacity(0.7)
                }
            }
        }
        .buttonStyle(InkButtonStyle())
        .keyboardShortcut(.defaultAction)
        .disabled(count == 0 || model.isCleaning || model.cleanIdleInFlight)
    }
}
