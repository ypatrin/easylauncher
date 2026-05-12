import Foundation
import Combine

/// Shared drag state. Lifted out of ContentView so the AppDelegate's mouseUp
/// monitor can act as a fallback for failed drops (where no `performDrop`
/// callback ever fires and the source cell would otherwise stay invisible).
final class DragTracker: ObservableObject {
    static let shared = DragTracker()
    @Published var item: AppItem? = nil {
        didSet {
            if item == nil {
                cancelPendingPageTurn()
            }
        }
    }

    private var pendingPageTurn: DispatchWorkItem?
    private var pendingDirection: PageTurnDirection?
    private var lastPageTurnAt: TimeInterval = 0
    private let hoverDelay: TimeInterval = 0.32
    private let pageTurnCooldown: TimeInterval = 0.18

    func schedulePageTurn(
        _ direction: PageTurnDirection,
        action: @escaping () -> Void
    ) {
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastPageTurnAt < pageTurnCooldown { return }
        if pendingDirection == direction { return }

        cancelPendingPageTurn()

        let work = DispatchWorkItem { [weak self] in
            self?.pendingPageTurn = nil
            self?.pendingDirection = nil
            self?.lastPageTurnAt = ProcessInfo.processInfo.systemUptime
            action()
        }

        pendingDirection = direction
        pendingPageTurn = work
        DispatchQueue.main.asyncAfter(deadline: .now() + hoverDelay, execute: work)
    }

    func cancelPendingPageTurn() {
        pendingPageTurn?.cancel()
        pendingPageTurn = nil
        pendingDirection = nil
    }
}

enum PageTurnDirection {
    case left
    case right
}
