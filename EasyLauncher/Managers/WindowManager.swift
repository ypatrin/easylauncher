import Cocoa
import SwiftUI

/// Borderless NSWindow that's allowed to become key/main so SwiftUI text fields
/// and focus work as expected.
final class LauncherWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Owns the fullscreen, borderless launcher window's lifecycle and chrome.
final class WindowManager {
    private(set) var window: NSWindow?

    func showLauncher<Content: View>(rootView: Content) {
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let frame = screen.frame

        let window = LauncherWindow(
            contentRect: frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        // Opaque fullscreen window — the window server can then skip
        // compositing everything behind us, which is a huge perf win on
        // a 5K display during paging scroll. The content fills the window
        // with an opaque background so nothing leaks through.
        window.isOpaque = true
        window.backgroundColor = .black
        window.hasShadow = false
        window.level = .popUpMenu  // above (almost) everything, like Launchpad
        window.collectionBehavior = [
            .canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle,
        ]
        window.isMovable = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden

        let hosting = NSHostingView(rootView: rootView)
        hosting.frame = frame
        hosting.autoresizingMask = [.width, .height]
        window.contentView = hosting

        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(hosting)

        self.window = window
    }

    func presentLauncher() {
        guard let window else { return }
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        if let hosting = window.contentView {
            window.makeFirstResponder(hosting)
        }
    }

    func hideLauncher() {
        window?.orderOut(nil)
        NSApp.hide(nil)
    }
}
