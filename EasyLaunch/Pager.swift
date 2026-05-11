import Foundation
import AppKit
import SwiftUI
import Combine

/// Shared page state. The AppDelegate forwards scroll-wheel (trackpad and mouse)
/// events here; the ContentView observes `current` and renders the active page.
final class Pager: ObservableObject {
    static let shared = Pager()

    @Published var current: Int = 0
    var pageCount: Int = 1

    // Trackpad gesture state
    private var accumulatedDX: CGFloat = 0
    private var locked = false

    // Mouse wheel state
    private var lastMouseWheelChange: TimeInterval = 0
    private let mouseWheelCooldown: TimeInterval = 0.45

    func reset(pageCount: Int) {
        self.pageCount = max(pageCount, 1)
        if current >= self.pageCount { current = self.pageCount - 1 }
    }

    func goTo(_ index: Int) {
        let clamped = max(0, min(index, pageCount - 1))
        if clamped != current { current = clamped }
    }

    func handleScroll(_ event: NSEvent) {
        guard pageCount > 1 else { return }

        // Ignore trackpad inertia — no matter how hard the swipe, advance only one page.
        if !event.momentumPhase.isEmpty { return }

        // Mouse wheel events have empty `phase` (no .began/.ended). Trackpad gestures
        // do set `phase`. Route them through separate paths.
        if event.phase.isEmpty {
            handleMouseWheel(event)
            return
        }

        handleTrackpad(event)
    }

    private func handleTrackpad(_ event: NSEvent) {
        switch event.phase {
        case .began:
            accumulatedDX = 0
            locked = false
        case .ended, .cancelled:
            accumulatedDX = 0
            locked = false
            return
        default:
            break
        }

        guard !locked else { return }

        let dx = event.scrollingDeltaX
        let dy = event.scrollingDeltaY
        // Ignore mostly-vertical gestures
        if abs(dy) > abs(dx) * 1.5 { return }

        accumulatedDX += dx
        let threshold: CGFloat = 28

        if accumulatedDX <= -threshold, current < pageCount - 1 {
            current += 1
            locked = true
        } else if accumulatedDX >= threshold, current > 0 {
            current -= 1
            locked = true
        }
    }

    private func handleMouseWheel(_ event: NSEvent) {
        // Hard time-window cooldown so a single wheel click (which often produces
        // several rapid scrollWheel events) flips only one page.
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastMouseWheelChange < mouseWheelCooldown { return }

        // Mouse wheels usually only have Y, but horizontal wheels exist — take the dominant axis.
        let dx = event.scrollingDeltaX
        let dy = event.scrollingDeltaY
        let delta = abs(dx) > abs(dy) ? dx : dy
        guard abs(delta) > 0.5 else { return }

        if delta < 0, current < pageCount - 1 {
            current += 1
            lastMouseWheelChange = now
        } else if delta > 0, current > 0 {
            current -= 1
            lastMouseWheelChange = now
        }
    }
}
