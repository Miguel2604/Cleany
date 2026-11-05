import AppKit
import CleanyCore
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    /// Mirrors the system's real login item status, re-read whenever the pane appears.
    @State private var openAtLogin = LoginItem.isEnabled
    @State private var loginError: String?

    static let upstreamURL = URL(string: "https://github.com/TheoInTech/CleanUp")!
    static let repoURL = URL(string: "https://github.com/Miguel2604/Cleany")!

    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                Toggle("Open at login", isOn: loginBinding)
                if let loginError {
                    Text(loginError).font(.fragment(11)).foregroundStyle(Creek.negative)
                }
                Toggle("Use Apple Intelligence for explanations", isOn: $model.useAI)
                LabeledContent("Open the menu from anywhere", value: "⌃⌥⌘C")
            }

            Section {
                if model.keepList.entries.isEmpty {
                    Text("Nothing yet. Choose Keep on an item to add it.").foregroundStyle(.secondary)
                } else {
                    ForEach(model.keepList.entries, id: \.id) { entry in
                        HStack {
                            Text(entry.name)
                            Spacer()
                            Button("Remove") { model.unkeep(entry.id) }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Remove \(entry.name)")
                        }
                    }
                }
            } header: {
                header("Always kept")
            }

            Section {
                let week = model.history.totals(since: Date().addingTimeInterval(-7 * 86_400))
                if model.history.entries.isEmpty {
                    Text("Nothing yet. Each cleanup shows up here.").foregroundStyle(.secondary)
                } else {
                    LabeledContent("Last 7 days", value: "\(week.stopped) stopped · \(Creek.cores(week.freedCores)) cores freed")
                    ForEach(Array(model.history.entries.prefix(8).enumerated()), id: \.offset) { _, entry in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(entry.date, format: .relative(presentation: .named))
                                Spacer()
                                Text("\(entry.stopped) stopped · \(Creek.cores(entry.freedCores)) cores")
                                    .foregroundStyle(.secondary)
                            }
                            Text(entry.names.joined(separator: ", "))
                                .font(.fragment(11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                }
            } header: {
                header("Cleaned up")
            }

            if let battery = model.snapshot.battery, let health = battery.healthPercent {
                Section {
                    LabeledContent("Health", value: battery.cycleCount.map { "\(health)% · \($0) cycles" } ?? "\(health)%")
                    if health >= 80 {
                        Text("Your battery is healthy. A fast drain comes from what is running.")
                            .lbl(10, lines: 2).secondary()
                    }
                } header: {
                    header("Battery")
                }
            }

            Section {
                HStack(spacing: 12) {
                    CleanyMark(size: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CLEANY").num(20)
                        Text("Its detection engine comes from CleanUp by TheoInTech (MIT).")
                            .lbl(10, lines: 2).secondary()
                    }
                }
                Link("Cleany on GitHub", destination: Self.repoURL)
                Link("CleanUp on GitHub", destination: Self.upstreamURL)
            }
        }
        .formStyle(.grouped)
        .font(.fragment(12))
        .tint(.primary)
        .frame(width: 460)
        .frame(minHeight: 420)
        .onAppear(perform: syncLoginItem)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            syncLoginItem()
        }
    }

    private func header(_ title: String) -> some View { Text(title).lbl() }

    /// Turning it on or off asks the system; if it refuses, the switch snaps back and says why.
    private var loginBinding: Binding<Bool> {
        Binding(
            get: { openAtLogin },
            set: { on in
                do {
                    try LoginItem.set(on)
                    loginError = LoginItem.needsApproval ? LoginItem.approvalMessage : nil
                } catch {
                    loginError = LoginItem.message(for: error)
                }
                openAtLogin = LoginItem.isEnabled
            }
        )
    }

    /// The user can change it in System Settings too, so the switch follows the system.
    private func syncLoginItem() {
        openAtLogin = LoginItem.isEnabled
        if LoginItem.needsApproval { loginError = LoginItem.approvalMessage }
        else if loginError == LoginItem.approvalMessage { loginError = nil }
    }
}
