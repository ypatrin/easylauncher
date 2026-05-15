import Foundation
import SwiftUI
import Combine

/// Shared page-state holder. The horizontal carousel is rendered by SwiftUI's
/// native `ScrollView(.horizontal)` + `.scrollTargetBehavior(.paging)` — gesture
/// tracking, snap, momentum and rubber-band all live in AppKit/Metal under the
/// hood, so this type is just a tiny source of truth for the current page and
/// page count (read by the indicator, written by drag-to-edge / indicator taps).
final class Pager: ObservableObject {
    static let shared = Pager()

    @Published var current: Int = 0
    @Published var pageCount: Int = 1

    /// When we last advanced the page in response to a wheel event.
    private var lastFlipAt: TimeInterval = 0
    /// Minimum time between page flips. One physical wheel notch often expands
    /// into several NSEvents spread over 100–300ms (macOS smoothing). The
    /// cooldown is wide enough that the tail of one notch can't sneak through
    /// while still letting deliberate, paced rolling page through at ~3 fps.
    private let flipCooldown: TimeInterval = 0.35

    func reset(pageCount: Int) {
        self.pageCount = max(pageCount, 1)
        if current >= self.pageCount { current = self.pageCount - 1 }
        if current < 0 { current = 0 }
    }

    func goTo(_ index: Int, animated: Bool = true) {
        let clamped = max(0, min(index, pageCount - 1))
        guard clamped != current else { return }
        if animated {
            withAnimation(Self.pageTransition) { current = clamped }
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { current = clamped }
        }
    }

    /// Advance one page in the direction of the dominant wheel axis.
    /// Trackpad scrolls bypass this — they flow into the native ScrollView,
    /// which has gesture-aware paging. Plain mouse wheels don't produce
    /// horizontal deltas, so we translate vertical wheel ticks here.
    func handleMouseWheel(deltaX: CGFloat, deltaY: CGFloat) {
        let delta = abs(deltaX) > abs(deltaY) ? deltaX : deltaY
        guard abs(delta) > 0.1 else { return }

        // Hard cap: at most one page per cooldown window. Each NSEvent flips
        // at most once regardless of its magnitude — otherwise a single notch
        // with a large delta or several events of the same notch would chain
        // multiple flips and rocket us to the last page.
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastFlipAt > flipCooldown else { return }

        let target: Int
        if delta < 0, current < pageCount - 1 {
            target = current + 1
        } else if delta > 0, current > 0 {
            target = current - 1
        } else {
            return
        }
        lastFlipAt = now
        withAnimation(Self.pageTransition) {
            current = target
        }
    }

    /// Shared page-transition animation. A critically-damped spring lands the
    /// page without the symmetrical "machine" feel of `easeInOut` — fast start,
    /// gentle settle. Used by both wheel events and indicator-tap / drag-edge
    /// goTo so the launcher's paging feels consistent everywhere.
    static let pageTransition: Animation = .spring(
        response: 0.55,
        dampingFraction: 0.86,
        blendDuration: 0
    )
}
