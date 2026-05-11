import Foundation
import AppKit

/// Shared state for the "click on background closes the app" behaviour.
///
/// SwiftUI's gesture system on a borderless window proved unreliable for catching
/// clicks on non-interactive areas, so we drive it with a global `NSEvent` monitor
/// in `AppDelegate`. Interactive SwiftUI elements (icons, page dots) set
/// `shouldClose = false` from their tap handlers; the search field reports its
/// screen frame so the monitor can short-circuit clicks that land on it (the
/// underlying NSTextField swallows events before SwiftUI sees them).
enum CloseTracker {
    static var shouldClose: Bool = true
    static var downPosition: CGPoint = .zero
}

enum SearchFieldGeometry {
    /// Frame of the search field in SwiftUI `.global` coordinates (top-left origin).
    static var frame: CGRect = .zero
}
