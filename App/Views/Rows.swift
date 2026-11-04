import AppKit
import CleanyCore
import SwiftUI

/// A 16 pt checkbox in ink: empty, partly ticked (a bar), or ticked.
struct TickBox: View {
    let state: TickState
    var size: CGFloat = 16

    var body: some View {
        ZStack {
            switch state {
            case .all, .some:
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous).fill(Color.primary)
                Image(systemName: state == .all ? "checkmark" : "minus")
                    .font(.system(size: size * 0.6, weight: .bold))
                    .foregroundStyle(Color(nsColor: .textBackgroundColor))
            case .none:
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.4), lineWidth: 1.5)
            }
        }
        .frame(width: size, height: size)
        .animation(.snappy(duration: 0.18), value: state)
    }
}

/// An item's picture in a fixed 18 pt slot: the real app icon for apps, a plain grey symbol otherwise.
struct ItemMedia: View {
    let item: Item
    var size: CGFloat = 18

    var body: some View {
        Group {
            if let path = item.detail["bundlePath"] {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path)).resizable().interpolation(.high)
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

/// One category: tick, name over "3 running · 2 idle", its cores over the idle part, chevron.
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

    private var subtitle: String {
        if category.id == .restart { return category.items.first?.judgement.fact ?? "" }
        let running = "\(category.items.count) running"
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
                                .font(.callout)
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
        HStack(spacing: 10) {
            if category.id == .restart {
                Image(systemName: Creek.symbol(.restart))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 16)
            } else {
                Button { model.toggleCategory(category.id) } label: {
                    TickBox(state: state)
                        .opacity(canTickAll ? 1 : 0.35)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, -4)
                .disabled(!canTickAll)
                .help(canTickAll ? "Tick the idle ones" : "Nothing idle here: open it to tick items yourself")
                .accessibilityLabel("Tick idle \(Creek.name(category.id))")
                .accessibilityAddTraits(state == .all ? .isSelected : [])
            }

            Button { withAnimation(.snappy(duration: 0.25)) { isOpen.toggle() } } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Creek.name(category.id)).font(.body.weight(.semibold))
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    if category.cores >= 0.05 {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(Creek.cores(category.cores))
                                .font(.body.weight(.medium))
                                .contentTransition(.numericText())
                            if idleCores >= 0.05 {
                                Text("\(Creek.cores(idleCores)) idle")
                                    .font(.caption)
                                    .foregroundStyle(Creek.idle)
                            }
                        }
                        .monospacedDigit()
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
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
                Button { model.toggle(item) } label: {
                    TickBox(state: model.isTicked(item) ? .all : .none)
                        .opacity(tickable ? 1 : 0.35)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, -4)
                .disabled(!tickable)
                .accessibilityLabel("Tick \(item.name)")
                .accessibilityAddTraits(model.isTicked(item) ? .isSelected : [])
            }

            ItemMedia(item: item)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if !item.judgement.fact.isEmpty, verdict != .manual || !VerdictBadge.factFits(item) {
                    Text(item.judgement.fact)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if verdict == .advice {
                Button("Restart…") { Task { await model.showRestartDialog() } }
                    .buttonStyle(.glass)
                    .controlSize(.small)
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

/// One status mark per item: "idle" in a pale green pill; "in use", "check" and a short fact in
/// plain grey.
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

    private var hue: Color? {
        switch item.judgement.verdict {
        case .idle: Creek.idle
        case .inUse, .manual, .check, .advice: nil
        }
    }

    var body: some View {
        Text(Self.text(for: item))
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .foregroundStyle(hue ?? .secondary)
            .padding(.horizontal, hue == nil ? 0 : 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(hue?.opacity(0.14) ?? .clear))
            .fixedSize()
    }
}
