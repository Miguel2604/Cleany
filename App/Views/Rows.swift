import CleanyCore
import SwiftUI

/// Full / half / empty circle in the category color.
struct TickCircle: View {
    let state: TickState
    let color: Color
    var size: CGFloat = 18

    var body: some View {
        ZStack {
            switch state {
            case .all:
                Circle().fill(color)
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.55, weight: .bold))
                    .foregroundStyle(Creek.deepWater)
            case .some:
                Circle().fill(Creek.track)
                Circle().fill(color).mask(alignment: .leading) { Rectangle().frame(width: size / 2) }
            case .none:
                Circle().strokeBorder(Color.secondary.opacity(0.7), lineWidth: 1.5)
            }
        }
        .frame(width: size, height: size)
        .animation(.snappy(duration: 0.2), value: state)
    }
}

/// One category on glass: header tick, stone, name, "2 of 5 ticked", cores, chevron. Opens into
/// its items, each in fixed columns: tick, stone, name plate + one-line note, state, "?".
struct CategoryRow: View {
    @Environment(AppModel.self) private var model
    let category: CategorySummary
    @Binding var isOpen: Bool
    /// Items shown when open before "+N more"; nil shows all.
    var maxItems: Int?
    var onMore: () -> Void = {}
    let onExplain: (Item) -> Void

    private var color: Color { Creek.color(category.id) }
    private var state: TickState { model.selection.state(of: category.id, in: model.snapshot) }
    private var canTickAll: Bool { model.hasIdle(category.id) || state != .none }
    private var shown: [Item] { maxItems.map { Array(category.items.prefix($0)) } ?? category.items }

    private var subtitle: String {
        if category.id == .restart { return category.items.first?.judgement.fact ?? "" }
        return "\(category.items.filter(model.isTicked).count) of \(category.items.count) ticked"
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if isOpen {
                VStack(spacing: 0) {
                    ForEach(shown) { item in
                        Divider().padding(.leading, 28)
                        ItemRow(item: item, onExplain: { onExplain(item) })
                    }
                    if shown.count < category.items.count {
                        Divider().padding(.leading, 28)
                        Button(action: onMore) {
                            Text("\(category.items.count - shown.count) more in the window")
                                .font(.callout)
                                .foregroundStyle(Creek.reed)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 28)
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: -6)), removal: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
        // Items fade in inside the row as it grows; without the clip they'd draw over the rows above.
        .clipShape(.rect(cornerRadius: 14))
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }

    private var header: some View {
        HStack(spacing: 10) {
            if category.id == .restart {
                Color.clear.frame(width: 18, height: 18)
            } else {
                Button { model.toggleCategory(category.id) } label: {
                    TickCircle(state: state, color: color)
                        .opacity(canTickAll ? 1 : 0.4)
                        .frame(width: 24, height: 24)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, -3)
                .disabled(!canTickAll)
                .help(canTickAll ? "Tick the idle ones" : "Nothing idle here: open it to tick items yourself")
                .accessibilityLabel("Tick idle \(Creek.name(category.id))")
                .accessibilityAddTraits(state == .all ? .isSelected : [])
            }

            Button { withAnimation(.snappy(duration: 0.25)) { isOpen.toggle() } } label: {
                HStack(spacing: 10) {
                    Stone(symbol: Creek.symbol(category.id), color: color)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(Creek.name(category.id)).font(.headline)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    if category.cores >= 0.05 {
                        Text(Creek.cores(category.cores))
                            .font(.system(.callout, design: .rounded).weight(.medium))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    }
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(Creek.name(category.id)), \(subtitle), \(Creek.cores(category.cores)) cores")
            .accessibilityValue(isOpen ? "Expanded" : "Collapsed")
        }
        .padding(.vertical, 8)
    }
}

/// One item: tick, stone, name plate with its one-line note, state, "?".
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
                Color.clear.frame(width: 18, height: 18)
            } else {
                Button { model.toggle(item) } label: {
                    TickCircle(state: model.isTicked(item) ? .all : .none, color: Creek.color(item.category))
                        .opacity(tickable ? 1 : 0.4)
                        .frame(width: 24, height: 24)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, -3)
                .disabled(!tickable)
                .accessibilityLabel("Tick \(item.name)")
                .accessibilityAddTraits(model.isTicked(item) ? .isSelected : [])
            }

            Stone(symbol: item.symbol, color: Creek.color(item.category), size: 22)

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

            Button(action: onExplain) {
                Image(systemName: "questionmark")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Creek.track))
                    .frame(width: 26, height: 26)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, -3)
            .foregroundStyle(.secondary)
            .help("Why does Cleany think this?")
            .accessibilityLabel("Why is \(item.name) \(VerdictBadge.text(for: item))?")
        }
        .padding(.vertical, 6)
    }
}

/// idle (reed), in use (plain), a short fact for manual items, check (lantern).
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

    private var color: Color {
        switch item.judgement.verdict {
        case .idle: Creek.reed
        case .check: Creek.lantern
        case .inUse, .manual, .advice: .secondary
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            if item.judgement.verdict == .idle { Image(systemName: "moon.zzz.fill") }
            Text(Self.text(for: item))
        }
        .font(.caption.weight(.semibold))
        .lineLimit(1)
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(Capsule().fill(item.judgement.verdict == .idle ? Creek.reed.opacity(0.16) : Creek.track))
        .fixedSize()
    }
}
