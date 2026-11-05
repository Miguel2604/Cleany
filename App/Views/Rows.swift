import AppKit
import CleanyCore
import SwiftUI

/// A 16 pt checkbox in ink: empty, partly ticked (a bar), or ticked. One that can't tick right now
/// (in use, nothing idle yet) has a dashed outline; clicking it explains why instead.
struct TickBox: View {
    let state: TickState
    var available = true
    var size: CGFloat = 16

    var body: some View {
        ZStack {
            switch state {
            case .all, .some:
                RoundedRectangle(cornerRadius: size * 0.2, style: .continuous).fill(Creek.ink)
                Image(systemName: state == .all ? "checkmark" : "minus")
                    .font(.system(size: size * 0.6, weight: .bold))
                    .foregroundStyle(Creek.inverse)
            case .none where available:
                RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                    .strokeBorder(Creek.ink.opacity(0.45), lineWidth: 1.5)
            case .none:
                RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                    .strokeBorder(Creek.ink.opacity(0.3), style: StrokeStyle(lineWidth: 1.2, dash: [2.5, 2]))
            }
        }
        .frame(width: size, height: size)
        .animation(.snappy(duration: 0.18), value: state)
    }
}

/// An item's picture in a fixed 18 pt slot: the real app icon in greys for apps, a plain grey symbol otherwise.
struct ItemMedia: View {
    let item: Item
    var size: CGFloat = 18

    var body: some View {
        Group {
            if let path = item.detail["bundlePath"] {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path)).resizable().interpolation(.high).saturation(0)
            } else {
                Image(systemName: item.symbol)
                    .font(.system(size: size * 0.72))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Hover feedback for a row: one lightness step, nothing else moves.
private struct RowHover: ViewModifier {
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(hovering ? Creek.raised : .clear))
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

/// One category: tick, then "SIMULATORS 3 RUNNING (2 IDLE)  5.4" over its dots.
/// Opens into its items on one lightness step: tick, picture, name over its fact, verdict, "?".
struct CategoryRow: View {
    @Environment(AppModel.self) private var model
    let category: CategorySummary
    @Binding var isOpen: Bool
    /// Items shown when open before "+N more"; nil shows all.
    var maxItems: Int?
    var onMore: () -> Void = {}
    let onExplain: (Item) -> Void

    private var state: TickState { model.selection.state(of: category.id, in: model.snapshot) }
    private var canTickAll: Bool { model.hasIdle(category.id) || state != .none }
    private var shown: [Item] { maxItems.map { Array(category.items.prefix($0)) } ?? category.items }
    private var idleCount: Int { category.items.filter { $0.judgement.verdict == .idle }.count }
    private var idleCores: Double { Creek.idleCores(category, reclaimable: model.quickSelection.ticked) }

    private var running: String { "\(category.items.count) running" }

    private var subtitle: String {
        if category.id == .restart { return category.items.first?.judgement.fact ?? "" }
        return idleCount > 0 ? "\(running) · \(idleCount) idle" : running
    }

    var body: some View {
        VStack(spacing: 2) {
            header.modifier(RowHover())
            if isOpen {
                VStack(spacing: 0) {
                    ForEach(shown) { item in
                        ItemRow(item: item, onExplain: { onExplain(item) })
                    }
                    if shown.count < category.items.count {
                        Button(action: onMore) {
                            Text("\(category.items.count - shown.count) more in the window")
                                .lbl()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 34)
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Creek.raised))
                .transition(.opacity.combined(with: .offset(y: -4)))
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            if category.id == .restart {
                Image(systemName: Creek.symbol(.restart))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 20)
            } else {
                Button {
                    if canTickAll {
                        model.toggleCategory(category.id)
                    } else {
                        withAnimation(.snappy(duration: 0.25)) { isOpen = true }
                        model.explainNothingToTick(category.id)
                    }
                } label: {
                    TickBox(state: state, available: canTickAll)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, -4)
                .padding(.vertical, -2)
                .help(canTickAll ? "Tick the idle ones" : "Nothing idle here yet: click to see why")
                .accessibilityLabel(canTickAll ? "Tick idle \(Creek.name(category.id))" : "Nothing idle in \(Creek.name(category.id)): show why")
                .accessibilityAddTraits(state == .all ? .isSelected : [])
            }

            Button { withAnimation(.snappy(duration: 0.25)) { isOpen.toggle() } } label: {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        Text(Creek.name(category.id)).lbl().fixedSize()
                        if category.id != .restart {
                            Text(running).lbl().secondary()
                            if idleCount > 0 { InkPill(text: "\(idleCount) idle") }
                        }
                        Spacer(minLength: 4)
                        if category.cores >= 0.05 {
                            Creek.coresText(category.cores, size: 20)
                                .lineLimit(1)
                                .contentTransition(.numericText())
                        }
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(isOpen ? 180 : 0))
                    }
                    .frame(height: 20)
                    if category.id == .restart {
                        Text(subtitle).lbl().secondary()
                    } else {
                        DotMeter(
                            dots: Creek.dots(category.id, in: model.snapshot, reclaimable: model.quickSelection.ticked, count: 24),
                            size: 8
                        )
                        .help("\(Creek.cores(idleCores)) of \(Creek.cores(category.cores)) cores idle")
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(Creek.name(category.id)), \(subtitle), \(Creek.cores(category.cores)) cores")
            .accessibilityValue(isOpen ? "Expanded" : "Collapsed")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}

/// One item: tick, picture, name over its one-line note, verdict, "?".
/// Advice (Restart) gets a "Restart…" button instead of a tick.
struct ItemRow: View {
    @Environment(AppModel.self) private var model
    let item: Item
    let onExplain: () -> Void

    private var verdict: Verdict { item.judgement.verdict }
    private var tickable: Bool { Selection.isTickable(item) }

    var body: some View {
        HStack(spacing: 10) {
            if verdict == .advice || verdict == .check {
                Color.clear.frame(width: 16, height: 16)
            } else {
                // In use can't be ticked (uncertain means in use); its box opens the "?" sheet, which
                // says why and offers Stop anyway.
                Button { if tickable { model.toggle(item) } else { onExplain() } } label: {
                    TickBox(state: model.isTicked(item) ? .all : .none, available: tickable)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, -4)
                .help(tickable ? "Tick to clean up" : "In use: see why, or stop it anyway")
                .accessibilityLabel(tickable ? "Tick \(item.name)" : "\(item.name) is in use: show why")
                .accessibilityAddTraits(model.isTicked(item) ? .isSelected : [])
            }

            ItemMedia(item: item)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.fragment(12))
                    .lineLimit(1)
                    .truncationMode(.middle)
                if !item.judgement.fact.isEmpty, verdict != .manual || !VerdictBadge.factFits(item) {
                    Text(item.judgement.fact)
                        .lbl(10, lines: 2)
                        .secondary()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if verdict == .advice {
                Button("Restart…") { Task { await model.showRestartDialog() } }
                    .buttonStyle(OutlineButtonStyle())
            } else {
                VerdictBadge(item: item)
            }

            ExplainButton(label: "Why is \(item.name) \(VerdictBadge.text(for: item))?", action: onExplain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}

/// The "?" on every item: a plain glyph that brightens under the pointer.
struct ExplainButton: View {
    let label: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 14))
                .foregroundStyle(hovering ? .primary : .tertiary)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, -4)
        .onHover { hovering = $0 }
        .help("Why does Cleany think this?")
        .accessibilityLabel(label)
    }
}

/// One status mark per item: "idle" in an inverted pill; "in use", "check" and a short fact in plain
/// grey.
struct VerdictBadge: View {
    let item: Item

    /// "not used 5 h" fits the badge; a longer fact goes on the note line instead.
    static func factFits(_ item: Item) -> Bool { item.judgement.fact.count <= 16 }

    static func text(for item: Item) -> String {
        switch item.judgement.verdict {
        case .idle: "idle"
        case .inUse: "in use"
        case .manual: factFits(item) ? item.judgement.fact : "not used"
        case .check: "check"
        case .advice: ""
        }
    }

    var body: some View {
        if item.judgement.verdict == .idle {
            InkPill(text: Self.text(for: item), size: 10)
        } else {
            Text(Self.text(for: item)).lbl(10).secondary().fixedSize()
        }
    }
}
