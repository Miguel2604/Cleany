import AppKit
import CleanyCore
import SwiftUI

/// Desktop panel mode: the widget's layouts in a borderless, transparent window just above the
/// wallpaper, on every Space. Unlike a WidgetKit widget, macOS never dims it or adds a backing.
enum DesktopLayout: String, CaseIterable {
    case small, medium

    var title: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        }
    }

    var size: CGSize {
        switch self {
        case .small: CGSize(width: 170, height: 170)
        case .medium: CGSize(width: 364, height: 170)
        }
    }
}

enum DesktopKeys {
    static let show = "desktopPanel"
    static let layout = "desktopPanelLayout"
    static let locked = "desktopPanelLocked"
}

@MainActor
final class DesktopPanel {
    private let model: AppModel
    private var panel: NSPanel?
    private var shownLayout: DesktopLayout?
    private var observer: NSObjectProtocol?

    init(model: AppModel) {
        self.model = model
        observer = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.sync() }
        }
        sync()
    }

    private func sync() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: DesktopKeys.show) else {
            panel?.orderOut(nil)
            panel = nil
            shownLayout = nil
            return
        }
        let layout = defaults.string(forKey: DesktopKeys.layout).flatMap(DesktopLayout.init) ?? .small
        let panel = self.panel ?? makePanel()
        self.panel = panel
        if layout != shownLayout {
            shownLayout = layout
            panel.setContentSize(layout.size)
            panel.contentView = DraggableHostingView(rootView: DesktopContent(layout: layout).environment(model))
        }
        // Locked: clicks go through to the desktop. Unlocked: drag it anywhere.
        panel.ignoresMouseEvents = defaults.bool(forKey: DesktopKeys.locked)
        panel.orderFront(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: NSRect(x: 80, y: 300, width: 170, height: 170),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)))
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.setFrameAutosaveName("CleanyDesktopPanel")
        panel.setFrameUsingName("CleanyDesktopPanel")
        return panel
    }
}

private final class DraggableHostingView<Content: View>: NSHostingView<Content> {
    override var mouseDownCanMoveWindow: Bool { true }
}

private struct DesktopContent: View {
    let layout: DesktopLayout
    @Environment(AppModel.self) private var model
    @AppStorage(Backdrop.key, store: Creek.groupDefaults) private var backdrop = Backdrop.tinted

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        Group {
            if model.hasScanned {
                let quick = model.quickSelection
                let snapshot = model.snapshot.withQuickSummary(
                    idleCount: quick.count, freedCores: quick.freedCores(in: model.snapshot), reclaimable: quick.ticked
                )
                switch layout {
                case .small: SmallWidget(snapshot: snapshot)
                case .medium: MediumWidget(snapshot: snapshot)
                }
            }
        }
        .foregroundStyle(Creek.ink)
        .frame(width: layout.size.width, height: layout.size.height)
        .modifier(BackdropStyle(style: backdrop, shape: shape))
    }
}

private struct BackdropStyle<S: InsettableShape>: ViewModifier {
    let style: Backdrop
    let shape: S

    func body(content: Content) -> some View {
        switch style {
        case .tinted: content.background(TintedGlass(shape: shape))
        case .clear: content.clearShadow()
        }
    }
}

/// On the panel the idle count only informs: a one-click stop on the desktop is too easy to hit while
/// dragging it, and a locked panel lets clicks through anyway. The popover and the widget do the job.
struct IdleAction: View {
    let count: Int

    var body: some View {
        InkPill(text: "\(count) idle")
    }
}
