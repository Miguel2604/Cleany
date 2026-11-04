import CleanyCore
import SwiftUI

/// The top of the popover and the window: the mood with the one finding, then the cores busy over
/// the creek band and its legend. Cause first, text second.
struct CreekHeader: View {
    @Environment(AppModel.self) private var model
    var titleSize: CGFloat = 17
    var figureSize: CGFloat = 26

    private var watching: Bool {
        model.quickSelection.count == 0 && model.snapshot.watchingUntil(now: Date()) != nil
    }

    /// The finding: what is idle and what it costs, or why nothing is.
    private var sentence: String {
        guard model.hasScanned else { return "Looking around…" }
        let idle = model.quickSelection.count
        if idle > 0 {
            let cores = Creek.cores(model.quickSelection.freedCores(in: model.snapshot))
            return idle == 1 ? "1 idle thing is using \(cores) cores." : "\(idle) idle things are using \(cores) cores."
        }
        if watching, let until = model.snapshot.watchingUntil(now: Date()), let hint = WatchingHint.text(until: until, now: Date()) {
            return hint
        }
        return model.snapshot.mood == .allGood ? "Nothing idle is running." : "Busy, and everything is in use."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(model.hasScanned ? Creek.title(model.snapshot.mood) : "Cleany")
                    .font(.system(size: titleSize, weight: .semibold))
                Text(sentence)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    CoresLabel(cores: model.snapshot.coresBusy, size: figureSize)
                    Spacer(minLength: 8)
                    if model.hasScanned {
                        Text(Creek.batteryLine(model.snapshot))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                CreekBand(snapshot: model.snapshot)
                if model.hasScanned { BandLegend(snapshot: model.snapshot) }
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
/// still runs, and Undo. One lightness step above the window.
struct OutcomeCard: View {
    @Environment(AppModel.self) private var model
    let outcome: CleanupOutcome
    var maxRows = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: outcome.allStopped ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(outcome.allStopped ? Creek.idle : .secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(outcome.title).font(.body.weight(.semibold))
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
                        Text(entry.name).font(.callout).lineLimit(1).truncationMode(.middle)
                        Spacer(minLength: 6)
                        switch entry.result {
                        case .stopped:
                            Text("Stopped")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Creek.idle)
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
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Creek.raised))
    }
}

/// The one primary control, made primary by inversion: an ink pill with the window's color for its
/// label. Pressing dims and settles it; disabled, it drops to a quiet fill.
struct InkButtonStyle: ButtonStyle {
    /// Replaces the ink for the one destructive case (Stop anyway); its label turns white.
    var fill: Color?
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(isEnabled ? (fill == nil ? Color(nsColor: .textBackgroundColor) : .white) : .secondary)
            .frame(maxWidth: .infinity, minHeight: 36)
            .padding(.horizontal, 16)
            .background(Capsule().fill(isEnabled ? (fill ?? .primary) : Creek.track))
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
            .contentShape(Capsule())
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
            HStack(spacing: 6) {
                if model.isCleaning { ProgressView().controlSize(.small) }
                if count == 0 {
                    Text(model.hasTickable ? "Nothing ticked" : "Nothing idle")
                } else {
                    Text("Clean up \(count) idle")
                    Text("frees \(Creek.cores(model.freedCores)) cores").fontWeight(.regular).opacity(0.7)
                }
            }
            .monospacedDigit()
        }
        .buttonStyle(InkButtonStyle())
        .keyboardShortcut(.defaultAction)
        .disabled(count == 0 || model.isCleaning || model.cleanIdleInFlight)
    }
}
