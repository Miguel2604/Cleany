import AppKit
import Carbon.HIToolbox
import CleanyCore
import SwiftUI

/// The AppKit shell: the status item and its popover, the glass main window, Settings, the app
/// menu and the global hotkey. SwiftUI only draws the content; this owns every window.
@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    private let model = AppModel.shared
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var mainWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var hotKey: HotKey?

    private lazy var actions = ShellActions(
        openWindow: { [weak self] item in self?.showMainWindow(explaining: item) },
        openSettings: { [weak self] in self?.showSettings() }
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMainMenu()
        model.openMainWindow = { [weak self] in self?.showMainWindow(explaining: nil) }
        model.start()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.imagePosition = .imageLeading
        observeStatusItem()

        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        let host = NSHostingController(rootView: PopoverView(actions: actions).environment(model))
        host.sizingOptions = .preferredContentSize
        popover.contentViewController = host

        // ⌃⌥⌘C opens the popover from anywhere.
        hotKey = HotKey(keyCode: UInt32(kVK_ANSI_C), modifiers: UInt32(controlKey | optionKey | cmdKey)) { [weak self] in
            self?.togglePopover()
        }

        #if DEBUG
        DebugSnapshot.runIfRequested(model, shell: self)
        if UserDefaults.standard.string(forKey: "debugAppearance") == "dark" { NSApp.appearance = NSAppearance(named: .darkAqua) }
        if UserDefaults.standard.string(forKey: "debugAppearance") == "light" { NSApp.appearance = NSAppearance(named: .aqua) }
        popover.appearance = NSApp.appearance   // the popover otherwise follows the system
        // `-debugOpen main` or `-debugOpen popover` shows it at launch, for screenshots.
        switch UserDefaults.standard.string(forKey: "debugOpen") {
        case "main": showMainWindow(explaining: nil)
        case "popover":
            // The status item can be hidden in a full menu bar: anchor to the window instead.
            showMainWindow(explaining: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                guard let view = self.mainWindow?.contentView else { return }
                self.popover.show(relativeTo: NSRect(x: view.bounds.midX, y: view.bounds.maxY - 40, width: 1, height: 1), of: view, preferredEdge: .minY)
            }
        default: break
        }
        if UserDefaults.standard.bool(forKey: "debugSimulateWarning") {
            Task {
                try? await Task.sleep(for: .seconds(3))
                model.simulateDrainWarning()
            }
        }
        #endif
    }

    /// Launching Cleany again while it runs (Finder, Spotlight) opens the window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow(explaining: nil)
        return false
    }

    // MARK: Status item

    /// Redraws the mark and the minutes whenever the idle count or the battery estimate changes.
    private func observeStatusItem() {
        withObservationTracking {
            updateStatusItem()
        } onChange: {
            Task { @MainActor [weak self] in self?.observeStatusItem() }
        }
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }
        let snapshot = model.snapshot
        let idle = model.hasScanned && model.quickSelection.count > 0
        button.image = MenuBarGlyph.image(idle: idle)
        var minutes: String?
        if model.hasScanned, let battery = snapshot.battery, battery.onBattery, let left = battery.minutesLeft {
            minutes = Creek.minutes(left)
        }
        button.title = minutes.map { " \($0)" } ?? ""
        let idleText = idle ? "\(model.quickSelection.count) idle" : nil
        button.setAccessibilityLabel(["Cleany", Creek.title(snapshot.mood), idleText, minutes.map { "\($0) left" }].compactMap { $0 }.joined(separator: ", "))
    }

    @objc func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            NSApp.activate()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func popoverDidShow(_ notification: Notification) { model.popoverVisible = true }
    func popoverDidClose(_ notification: Notification) { model.popoverVisible = false }

    // MARK: Windows

    func showMainWindow(explaining item: Item?) {
        popover.performClose(nil)
        let window = mainWindow ?? makeMainWindow()
        mainWindow = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        if let item { model.explaining = item }
    }

    /// A glass window tinted with a true-neutral ground; the content draws edge to edge under the title bar.
    private func makeMainWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.title = "Cleany"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentMinSize = NSSize(width: 440, height: 520)
        window.contentMaxSize = NSSize(width: 440, height: 4000)
        window.setFrameAutosaveName("CleanyMain")

        let glass = NSGlassEffectView()
        glass.cornerRadius = 0
        glass.tintColor = NSColor(Creek.ground).withAlphaComponent(0.6)
        glass.contentView = NSHostingView(rootView: MainView(actions: actions).environment(model))
        window.contentView = glass
        if !window.setFrameUsingName("CleanyMain") { window.center() }
        return window
    }

    func showSettings() {
        popover.performClose(nil)
        let window = settingsWindow ?? {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView().environment(model)))
            window.title = "Cleany Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            return window
        }()
        settingsWindow = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: Menu

    /// Shown while a Cleany window is in front: Settings (⌘,), Close (⌘W), Quit (⌘Q), and Edit for copying text.
    private func makeMainMenu() -> NSMenu {
        let menu = NSMenu()
        let app = NSMenu()
        app.addItem(withTitle: "Settings…", action: #selector(openSettingsFromMenu), keyEquivalent: ",").target = self
        app.addItem(.separator())
        app.addItem(withTitle: "Quit Cleany", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(withTitle: "Cleany", action: nil, keyEquivalent: "").submenu = app

        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        menu.addItem(withTitle: "Edit", action: nil, keyEquivalent: "").submenu = edit

        let window = NSMenu(title: "Window")
        window.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        window.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        menu.addItem(withTitle: "Window", action: nil, keyEquivalent: "").submenu = window
        return menu
    }

    @objc private func openSettingsFromMenu() { showSettings() }
}

/// The menu bar mark: a template image, so the menu bar tints it. The split-off stretch appears
/// while something idle can be cleaned up.
@MainActor
enum MenuBarGlyph {
    private static var cache: [Bool: NSImage] = [:]

    static func image(idle: Bool) -> NSImage {
        if let cached = cache[idle] { return cached }
        let renderer = ImageRenderer(content: CleanyMark(size: 16, segment: idle, ink: .black, accent: .black).padding(1))
        renderer.scale = NSScreen.screens.first?.backingScaleFactor ?? 2
        let image = renderer.nsImage ?? NSImage(size: NSSize(width: 18, height: 18))
        image.isTemplate = true
        cache[idle] = image
        return image
    }
}

/// One system-wide hotkey through Carbon (still the supported way to register one without
/// Accessibility permission).
@MainActor
final class HotKey {
    private var ref: EventHotKeyRef?
    private static var action: (() -> Void)?

    init(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        Self.action = action
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { MainActor.assumeIsolated { HotKey.action?() } }
            return noErr
        }, 1, &spec, nil, nil)
        let id = EventHotKeyID(signature: OSType(0x434C_4E59), id: 1)   // "CLNY"
        RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &ref)
    }
}
