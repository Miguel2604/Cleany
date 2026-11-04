#if DEBUG
import AppKit
import CleanyCore
import SwiftUI

/// Debug builds only. Launched with `-debugSnapshotDir <dir>`, the app renders its own windows to PNGs
/// (no Screen Recording permission needed): the main window, the popover, an opened category, a "?"
/// sheet and Settings. Never presses Clean up or Stop. `-debugSnapshotQuit YES` quits when done.
@MainActor
enum DebugSnapshot {
    static func runIfRequested(_ model: AppModel, shell: AppDelegate) {
        guard let path = UserDefaults.standard.string(forKey: "debugSnapshotDir") else { return }
        let dir = URL(fileURLWithPath: path, isDirectory: true)
        Task { await run(model, shell: shell, dir: dir) }
    }

    private static func run(_ model: AppModel, shell: AppDelegate, dir: URL) async {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        while !model.hasScanned { await pause(0.5) }
        await pause(7)   // the first scan has no CPU deltas yet
        shell.showMainWindow(explaining: nil)
        await pause(1.5)
        capture("main", into: dir)
        shell.togglePopover()
        await pause(1.5)
        capture("popover", into: dir)
        shell.togglePopover()

        if let category = model.snapshot.categories.first(where: { $0.id != .restart }) {
            model.expanded.insert(category.id)
            await pause(1.2)
            capture("main-expanded", into: dir)
            if let item = category.items.first {
                model.explaining = item
                await pause(10)   // the explainer gives up on the model after 8 s
                capture("explain", into: dir)
                model.explaining = nil
            }
        }
        shell.showSettings()
        await pause(1.5)
        capture("settings", into: dir)
        if UserDefaults.standard.bool(forKey: "debugSnapshotQuit") { NSApp.terminate(nil) }
    }

    private static func pause(_ seconds: Double) async { try? await Task.sleep(for: .seconds(seconds)) }

    /// One PNG per visible window, e.g. `main-Cleany.png`.
    private static func capture(_ name: String, into dir: URL) {
        for window in NSApp.windows where window.isVisible && window.frame.width > 120 {
            guard let view = window.contentView?.superview ?? window.contentView,
                  let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
            view.cacheDisplay(in: view.bounds, to: rep)
            let label = window.title.isEmpty ? "\(window.windowNumber)" : window.title.replacingOccurrences(of: " ", with: "-")
            try? rep.representation(using: .png, properties: [:])?.write(to: dir.appendingPathComponent("\(name)-\(label).png"))
        }
    }
}
#endif
