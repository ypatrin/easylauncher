import SwiftUI
import AppKit

/// Frosted blur plus a dim overlay used behind the launcher grid.
struct LaunchpadBackground: View {
    var body: some View {
        ZStack {
            VisualEffect()
            Color.black.opacity(0.25)
        }
        .ignoresSafeArea()
    }
}

private struct VisualEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
