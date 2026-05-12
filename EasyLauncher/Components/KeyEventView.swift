import SwiftUI
import AppKit

/// Invisible NSView that installs a local key-event monitor and routes ESC to
/// application termination. Embed it anywhere in the SwiftUI hierarchy.
struct KeyEventView: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        context.coordinator.install()
        return NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    final class Coordinator {
        private var monitor: Any?

        func install() {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 53 { // ESC
                    AppDelegate.shared?.hideLauncher()
                    return nil
                }
                return event
            }
        }

        deinit {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }
    }
}
