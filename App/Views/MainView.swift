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
                VStack(spacing: 20) {
                    CreekHeader(titleSize: 22, figureSize: 30)
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
            Text("Nothing running in the background.")
                .foregroundStyle(.secondary)
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
