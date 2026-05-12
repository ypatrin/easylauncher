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
    private var window: NSWindow?

    func showLauncher<Content: View>(rootView: Content) {
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let frame = screen.frame

        let window = LauncherWindow(
            contentRect: frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
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
}
