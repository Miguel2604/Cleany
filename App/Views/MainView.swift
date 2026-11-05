import AppKit
import CleanyCore
import SwiftUI

/// The main window: the verdict header, Quick select | Choose myself, every category, Clean up.
struct MainView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    let actions: ShellActions

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    VerdictHeader(titleSize: 38)
                    ModePicker(mode: $model.mode)
                        .help("Quick select ticks everything idle; Choose myself leaves the ticks to you")
                    checklist
                }
                .padding(.horizontal, 20)
                .padding(.top, 36)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.automatic)

            if let outcome = model.outcome {
                OutcomeCard(outcome: outcome)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .id(outcome.id)
            }

            CleanUpButton()
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 20)
        }
        .animation(.snappy, value: model.outcome?.id)
        .foregroundStyle(Creek.ink)
        // Light glass over a dark wallpaper settles on mid grey, too dark for ink at secondary opacity.
        .background(scheme == .light ? Color.white.opacity(0.6) : .clear, ignoresSafeAreaEdges: .all)
        .frame(width: 440)
        .frame(minHeight: 520, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) {
            PlainIconButton(symbol: "gearshape", label: "Settings", action: actions.openSettings)
                .padding(.trailing, 12)
                .padding(.top, 6)
        }
        .overlay(alignment: .bottom) {
            if let toast = model.toast {
                ToastView(toast: toast)
                    .padding(.bottom, 84)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .id(toast.id)
            }
        }
        .animation(.snappy, value: model.toast?.id)
        .sheet(item: $model.explaining) { item in
            ExplainSheet(item: item).environment(model)
        }
        .background(WindowVisibility { model.windowVisible = $0 })
    }

    @ViewBuilder
    private var checklist: some View {
        if !model.hasScanned {
            ProgressView().controlSize(.small).padding(.top, 24)
        } else if model.snapshot.categories.isEmpty {
            Text("Nothing running in the background")
                .lbl()
                .secondary()
                .padding(.top, 24)
        } else {
            VStack(spacing: 4) {
                ForEach(model.snapshot.categories, id: \.id) { category in
                    CategoryRow(
                        category: category,
                        isOpen: Binding(
                            get: { model.expanded.contains(category.id) },
                            set: { open in if open { model.expanded.insert(category.id) } else { model.expanded.remove(category.id) } }
                        ),
                        onExplain: { model.explaining = $0 }
                    )
                }
            }
            .padding(.horizontal, -10)
        }
    }
}

/// Quick select | Choose myself: the selected side is an ink plate.
private struct ModePicker: View {
    @Binding var mode: AppModel.Mode

    var body: some View {
        HStack(spacing: 2) {
            segment("Quick select", .quick)
            segment("Choose myself", .manual)
        }
        .padding(2)
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Creek.hairline))
    }

    private func segment(_ title: String, _ value: AppModel.Mode) -> some View {
        Button { mode = value } label: {
            Text(title)
                .lbl()
                .foregroundStyle(mode == value ? Creek.inverse : Creek.ink)
                .frame(maxWidth: .infinity, minHeight: 24)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(mode == value ? Creek.ink : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(mode == value ? .isSelected : [])
    }
}
