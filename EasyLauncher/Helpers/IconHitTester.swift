import AppKit
import Foundation
import SwiftUI

/// Reports a view's frame in SwiftUI `.global` coordinates. LauncherView reads
/// this off the pager strip so it can translate a right-click cursor position
/// into a cell index.
struct GridAreaFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

/// Receives right-clicks from a global event monitor and shows an `NSMenu`
/// for whichever icon sits under the cursor.
///
/// Replaces SwiftUI's `.contextMenu` per cell, which attaches a menu trampoline
/// to every icon (100+ on a typical install). Here a single closure does the
/// hit test using grid layout math instead.
final class IconHitTester {
    static let shared = IconHitTester()

    /// Returns the app under `point` in SwiftUI `.global` coordinates
    /// (top-left origin, in the launcher window). LauncherView rebinds this
    /// whenever layout or the visible page changes.
    var hitTest: ((CGPoint) -> AppItem?)?
    var isHidden: ((AppItem) -> Bool)?
    var labels: (launch: String, hide: String, show: String) = ("Launch", "Hide", "Show")

    func handleRightClick(_ event: NSEvent) {
        guard let view = (event.window ?? NSApp.keyWindow)?.contentView else { return }

        let screenH = NSScreen.main?.frame.height ?? 0
        let cursor = CGPoint(
            x: NSEvent.mouseLocation.x,
            y: screenH - NSEvent.mouseLocation.y
        )

        guard let app = hitTest?(cursor) else { return }
        let hidden = isHidden?(app) ?? false

        let menu = NSMenu()

        let launchTarget = MenuTarget {
            CloseTracker.shouldClose = false
            NotificationCenter.default.post(name: .menuLaunchApp, object: app)
        }
        let launchItem = NSMenuItem(
            title: labels.launch,
            action: #selector(MenuTarget.fire(_:)),
            keyEquivalent: ""
        )
        launchItem.target = launchTarget
        menu.addItem(launchItem)

        let toggleTarget = MenuTarget {
            CloseTracker.shouldClose = false
            NotificationCenter.default.post(name: .menuToggleHiddenApp, object: app)
        }
        let toggleItem = NSMenuItem(
            title: hidden ? labels.show : labels.hide,
            action: #selector(MenuTarget.fire(_:)),
            keyEquivalent: ""
        )
        toggleItem.target = toggleTarget
        menu.addItem(toggleItem)

        // popUpContextMenu is synchronous — it blocks until dismissal, so the
        // local targets stay alive for the duration of the menu.
        NSMenu.popUpContextMenu(menu, with: event, for: view)
        _ = launchTarget
        _ = toggleTarget
    }
}

private final class MenuTarget: NSObject {
    let action: () -> Void
    init(_ action: @escaping () -> Void) {
        self.action = action
        super.init()
    }
    @objc func fire(_ sender: Any) { action() }
}

extension Notification.Name {
    static let menuLaunchApp = Notification.Name("EasyLauncher.menuLaunchApp")
    static let menuToggleHiddenApp = Notification.Name("EasyLauncher.menuToggleHiddenApp")
}
