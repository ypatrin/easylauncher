import Foundation
import Combine

/// Shared drag state. Lifted out of ContentView so the AppDelegate's mouseUp
/// monitor can act as a fallback for failed drops (where no `performDrop`
/// callback ever fires and the source cell would otherwise stay invisible).
final class DragTracker: ObservableObject {
    static let shared = DragTracker()
    @Published var item: AppItem? = nil
}
