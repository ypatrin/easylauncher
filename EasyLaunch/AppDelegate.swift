import Cocoa
import SwiftUI

/// Borderless NSWindow that's allowed to become key/main so SwiftUI text fields
/// and focus work as expected.
final class LauncherWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var scrollMonitor: Any?
    private var keyMonitor: Any?
    private var mouseDownMonitor: Any?
    private var mouseUpMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let frame = screen.frame

        window = LauncherWindow(
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

        let hosting = NSHostingView(rootView: ContentView())
        hosting.frame = frame
        hosting.autoresizingMask = [.width, .height]
        window.contentView = hosting

        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(hosting)

        NSApp.activate(ignoringOtherApps: true)
        NSApp.presentationOptions = [.autoHideDock, .autoHideMenuBar]

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {  // ESC
                NSApp.terminate(nil)
                return nil
            }
            return event
        }

        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            Pager.shared.handleScroll(event)
            return event
        }

        mouseDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            CloseTracker.shouldClose = true
            CloseTracker.downPosition = NSEvent.mouseLocation

            // Clicks on the search field shouldn't close — the NSTextField swallows
            // the event before SwiftUI's gesture system can flip the flag.
            let screenH = NSScreen.main?.frame.height ?? 0
            let swiftUIPos = CGPoint(
                x: NSEvent.mouseLocation.x,
                y: screenH - NSEvent.mouseLocation.y
            )
            if SearchFieldGeometry.frame.contains(swiftUIPos) {
                CloseTracker.shouldClose = false
            }
            return event
        }

        mouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { event in
            let pos = NSEvent.mouseLocation
            let dist = hypot(
                pos.x - CloseTracker.downPosition.x,
                pos.y - CloseTracker.downPosition.y)
            // Click, not drag
            if dist < 5 {
                // Defer so SwiftUI tap handlers (icons, dots) can flip the flag first.
                DispatchQueue.main.async {
                    if CloseTracker.shouldClose {
                        NSApp.terminate(nil)
                    }
                }
            }

            // Drag fallback: if performDrop never fires (drop into a void area),
            // the source cell would stay invisible. Clear it after a short delay
            // so a successful drop has time to land first.
            if DragTracker.shared.item != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if DragTracker.shared.item != nil {
                        withAnimation(.easeOut(duration: 0.18)) {
                            DragTracker.shared.item = nil
                        }
                    }
                }
            }
            return event
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        for m in [scrollMonitor, keyMonitor, mouseDownMonitor, mouseUpMonitor] {
            if let m { NSEvent.removeMonitor(m) }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
