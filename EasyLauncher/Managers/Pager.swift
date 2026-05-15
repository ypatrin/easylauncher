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

    private var lastWheelChange: TimeInterval = 0
    /// Minimum time between wheel-driven page flips. Tuned just long enough
    /// to absorb the trailing tail of NSEvents that follow a single physical
    /// wheel notch (~50–80ms), but short enough that successive deliberate
    /// clicks can stack — the previous page's animation simply interrupts
    /// and continues toward the new target.
    private let wheelCooldown: TimeInterval = 0.18

    func reset(pageCount: Int) {
        self.pageCount = max(pageCount, 1)
        if current >= self.pageCount { current = self.pageCount - 1 }
        if current < 0 { current = 0 }
    }

    func goTo(_ index: Int, animated: Bool = true) {
        let clamped = max(0, min(index, pageCount - 1))
        guard clamped != current else { return }
        if animated {
            withAnimation(.easeInOut(duration: 0.32)) { current = clamped }
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
    /// Uses a slower, springy animation than `goTo` because mouse wheels
    /// don't carry a velocity signal — a snappy 0.32s easeInOut feels
    /// abrupt when the user wasn't dragging the page across the screen.
    func handleMouseWheel(deltaX: CGFloat, deltaY: CGFloat) {
        let delta = abs(deltaX) > abs(deltaY) ? deltaX : deltaY
        guard abs(delta) > 0.5 else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastWheelChange < wheelCooldown { return }

        let target: Int
        if delta < 0, current < pageCount - 1 {
            target = current + 1
        } else if delta > 0, current > 0 {
            target = current - 1
        } else {
            return
        }
        lastWheelChange = now
        withAnimation(.easeInOut(duration: 0.8)) {
            current = target
        }
    }
}
