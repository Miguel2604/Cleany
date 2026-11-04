import AppKit
import CleanyCore
import SwiftUI

/// The menu bar popover: the creek header, the three categories using the most CPU with their
/// ticks, the Clean up button, and a way into the window. Does the whole job on its own.
struct PopoverView: View {
    @Environment(AppModel.self) private var model
    /// The one category opened into its items (one at a time keeps the popover short).
    @State private var opened: CategoryID?
    let actions: ShellActions

    /// The three categories using the most CPU, in a stable order (ties by id, so rows never swap).
    /// Restart is advice, not something to tick.
    private var top: [CategorySummary] {
        Array(model.snapshot.categories
            .filter { $0.id != .restart }
            .sorted { ($0.cores, $1.id.rawValue) > ($1.cores, $0.id.rawValue) }
            .prefix(3))
    }

    var body: some View {
        VStack(spacing: 12) {
            CreekHeader()
            list
            if let outcome = model.outcome {
                OutcomeCard(outcome: outcome, maxRows: 4)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .id(outcome.id)
            } else if let toast = model.toast {
                ToastView(toast: toast)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .id(toast.id)
            }
            CleanUpButton()
            footer
        }
        .animation(.snappy, value: model.toast?.id)
        .animation(.snappy, value: model.outcome?.id)
        .padding(16)
        .frame(width: 360)
        .background(Creek.depth.ignoresSafeArea())
    }

    @ViewBuilder
    private var list: some View {
        if !model.hasScanned {
            ProgressView().controlSize(.small).frame(maxWidth: .infinity, minHeight: 60)
        } else if top.isEmpty {
            Text("Nothing running in the background.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 60)
        } else {
            GlassEffectContainer(spacing: 6) {
                VStack(spacing: 6) {
                    ForEach(top, id: \.id) { category in
                        CategoryRow(
                            category: category,
                            isOpen: Binding(get: { opened == category.id }, set: { opened = $0 ? category.id : nil }),
                            maxItems: 5,
                            onMore: { actions.openWindow(nil) },
                            onExplain: { actions.openWindow($0) }
                        )
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button { actions.openWindow(nil) } label: {
                Text("Open Cleany")
                    .font(.callout)
                    .foregroundStyle(Creek.reed)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Text("⌃⌥⌘C")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .help("Opens this from anywhere")
            Spacer(minLength: 0)
            #if DEBUG
            iconButton("bell.badge", label: "Simulate drain warning") { model.simulateDrainWarning() }
            #endif
            iconButton("gearshape", label: "Settings") { actions.openSettings() }
            iconButton("power", label: "Quit Cleany") { NSApp.terminate(nil) }
        }
    }

    private func iconButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .glassEffect(.regular.interactive(), in: .circle)
        .help(label)
        .accessibilityLabel(label)
    }
}

/// What the views can ask of the AppKit shell, which owns the windows and the popover.
struct ShellActions {
    /// Opens the main window, optionally on an item's "?" sheet, and closes the popover.
    var openWindow: (Item?) -> Void
    var openSettings: () -> Void
}
