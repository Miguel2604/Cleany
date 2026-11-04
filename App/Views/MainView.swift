import AppKit
import CleanyCore
import SwiftUI

/// The main window: the creek header, Quick select | Choose myself, every category, Clean up.
struct MainView: View {
    @Environment(AppModel.self) private var model
    let actions: ShellActions

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    CreekHeader(raccoonSize: 72, bandHeight: 22)
                    Picker("Selection", selection: $model.mode) {
                        Text("Quick select").tag(AppModel.Mode.quick)
                        Text("Choose myself").tag(AppModel.Mode.manual)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
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
        .background(Creek.depth.ignoresSafeArea())
        .frame(width: 440)
        .frame(minHeight: 520, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) {
            Button(action: actions.openSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .glassEffect(.regular.interactive(), in: .circle)
            .padding(.trailing, 14)
            .padding(.top, 8)
            .help("Settings")
            .accessibilityLabel("Settings")
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
            Text("Nothing running in the background.")
                .foregroundStyle(.secondary)
                .padding(.top, 24)
        } else {
            GlassEffectContainer(spacing: 8) {
                VStack(spacing: 8) {
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
            }
        }
    }
}
