import Cocoa
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let windowManager = WindowManager()
    private var monitors: [Any] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        windowManager.showLauncher(rootView: LauncherView())

        NSApp.activate(ignoringOtherApps: true)
        NSApp.presentationOptions = [.autoHideDock, .autoHideMenuBar]

        installScrollMonitor()
        installMouseMonitors()
    }

    private func installScrollMonitor() {
        addMonitor(matching: .scrollWheel) { event in
            Pager.shared.handleScroll(event) ? nil : event
        }
    }

    private func installMouseMonitors() {
        addMonitor(matching: .leftMouseDown) { event in
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

        addMonitor(matching: .leftMouseUp) { event in
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

    private func addMonitor(
        matching mask: NSEvent.EventTypeMask,
        handler: @escaping (NSEvent) -> NSEvent?
    ) {
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: mask, handler: handler) {
            monitors.append(monitor)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors.removeAll()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
