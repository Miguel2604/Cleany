import CleanyCore
import SwiftUI

/// The "?" sheet: what it is, why we think it's idle or in use, whether it's safe to stop, and
/// Keep / Stop. The verdict comes from the engine; only the plain-words text comes from the explainer.
struct ExplainSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let original: Item
    @State private var explanation: Explanation?

    init(item: Item) {
        original = item
    }

    /// The latest version of the item, so the verdict stays current while the sheet is open.
    private var item: Item { model.snapshot.item(withID: original.id) ?? original }
    private var verdict: Verdict { item.judgement.verdict }

    private var signalsTitle: String {
        switch verdict {
        case .idle: "Why we think it's idle"
        case .inUse: "Why we think it's in use"
        case .manual, .check, .advice: "What we see"
        }
    }

    private var safety: String {
        switch verdict {
        case .idle: "Safe"
        case .inUse: "Probably being used"
        case .manual, .check, .advice: "Your call"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ItemMedia(item: item, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name).font(.fragment(15)).lineLimit(2)
                    Text("\(Creek.name(item.category)) · \(item.judgement.fact)")
                        .lbl()
                        .secondary()
                }
            }

            section("What is this?") {
                if let explanation {
                    Text(explanation.whatIsIt).fixedSize(horizontal: false, vertical: true)
                } else {
                    ProgressView().controlSize(.small)
                }
            }

            if !item.judgement.signals.isEmpty {
                section(signalsTitle) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(item.judgement.signals.enumerated()), id: \.offset) { _, signal in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                DotMark(dot: signalDot(signal.kind), size: 7)
                                Text(signal.text).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }

            section("Safe to stop?") {
                VStack(alignment: .leading, spacing: 6) {
                    if verdict == .idle {
                        InkPill(text: safety)
                    } else {
                        Text(safety).lbl()
                    }
                    if let explanation {
                        Text(explanation.whatYouLose)
                            .secondary()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if verdict == .check {
                Text(Self.tabAdvice(browser: item.detail["browser"]))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if explanation?.byAI == true {
                Label("Explained by Apple Intelligence, on this Mac", systemImage: "apple.intelligence")
                    .lbl(10, lines: 2)
                    .secondary()
            }

            buttons
        }
        .font(.fragment(12))
        .padding(20)
        .frame(width: 400)
        .task(id: original.id) {
            explanation = await model.explain(original)
        }
    }

    @ViewBuilder
    private var buttons: some View {
        HStack(spacing: 10) {
            switch verdict {
            case .advice:
                Button { dismiss() } label: {
                    Text("Not now").frame(maxWidth: .infinity)
                }
                .buttonStyle(OutlineButtonStyle(minHeight: 34))
                Button {
                    dismiss()
                    Task { await model.showRestartDialog() }
                } label: {
                    Text("Restart…").frame(maxWidth: .infinity)
                }
                .buttonStyle(InkButtonStyle())
            case .check:
                // Cleany can't tell which tab it is; the browser's own task manager can close it.
                Button { dismiss() } label: {
                    Text("OK").frame(maxWidth: .infinity)
                }
                .buttonStyle(InkButtonStyle())
            case .inUse where item.isEngine:
                // Quitting an engine stops everything in it, so it is never forced: no "Stop anyway".
                VStack(alignment: .trailing, spacing: 8) {
                    if item.category == .containers {
                        Text("Stop its containers first").lbl().secondary()
                    }
                    Button {
                        model.keep(item)
                        dismiss()
                    } label: {
                        Text("Keep").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(OutlineButtonStyle(minHeight: 34))
                }
            case .idle, .inUse, .manual:
                Button {
                    model.keep(item)
                    dismiss()
                } label: {
                    Text("Keep").frame(maxWidth: .infinity)
                }
                .buttonStyle(OutlineButtonStyle(minHeight: 34))
                Button {
                    let target = item
                    let force = verdict == .inUse
                    dismiss()
                    Task { await model.stop(target, force: force) }
                } label: {
                    Text(verdict == .inUse ? "Stop anyway" : "Stop").frame(maxWidth: .infinity)
                }
                .buttonStyle(InkButtonStyle(fill: verdict == .inUse ? Creek.negativeFill : nil))
                .disabled(model.isCleaning || model.cleanIdleInFlight)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    /// Chromium browsers have a task manager (Shift+Esc); Safari and Firefox don't show one per tab.
    static func tabAdvice(browser: String?) -> String {
        let chromium: Set<String> = ["Chrome", "Brave", "Edge", "Chromium", "Arc", "Vivaldi", "Opera"]
        if let browser, chromium.contains(browser) {
            return "Open the browser's task manager to close it (Shift+Esc in Chrome, Brave, Edge)."
        }
        return "Close the busy tab in the browser."
    }

    /// The same dots as the meters: hollow is idle, filled is in use, dim says neither.
    private func signalDot(_ kind: Signal.Kind) -> Dot {
        switch kind {
        case .idle: .idle
        case .inUse: .on
        case .neutral: .off
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).lbl().secondary().accessibilityAddTraits(.isHeader)
            content()
        }
    }
}
