import SwiftUI
import AppKit

/// Single key-event monitor used by the launcher. Lives in the SwiftUI tree so
/// the closures it dispatches into see the freshest LauncherView state on every
/// re-render.
///
/// We use a local `NSEvent` monitor instead of SwiftUI's `.onKeyPress` because
/// the search NSTextField is the key responder and would swallow ↑/↓/⏎ before
/// the SwiftUI layer ever saw them — local monitors run before the responder
/// chain, so we can intercept and return `nil` to consume the event.
struct LauncherKeys: NSViewRepresentable {
    /// Each closure returns `true` to consume the event, `false` to let it
    /// continue down the responder chain (e.g. into the text field).
    let onUp: () -> Bool
    let onDown: () -> Bool
    let onEnter: () -> Bool
    let onEscape: () -> Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSView {
        context.coordinator.install()
        return NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.parent = self
    }

    final class Coordinator {
        var parent: LauncherKeys
        private var monitor: Any?

        init(_ parent: LauncherKeys) { self.parent = parent }

        func install() {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                switch event.keyCode {
                case 53:  // ESC
                    return self.parent.onEscape() ? nil : event
                case 126: // ↑
                    return self.parent.onUp() ? nil : event
                case 125: // ↓
                    return self.parent.onDown() ? nil : event
                case 36, 76: // Return / keypad Enter
                    return self.parent.onEnter() ? nil : event
                default:
                    return event
                }
            }
        }

        deinit {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }
    }
}
