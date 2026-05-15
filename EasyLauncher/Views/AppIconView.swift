import SwiftUI
import AppKit

struct AppIconView: View {
    let app: AppItem
    let iconSize: CGFloat
    let labelFontSize: CGFloat
    let isLaunching: Bool
    let onLaunch: (AppItem) -> Void

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Image(nsImage: app.icon)
                    .resizable()
                    .frame(width: iconSize, height: iconSize)
                // The launch "puff" overlay only matters for the icon being
                // tapped — skip it for everyone else so we render one image
                // per cell, not two.
                if isLaunching {
                    LaunchPuff(icon: app.icon, iconSize: iconSize)
                }
            }
            Text(app.name)
                .font(.system(size: labelFontSize))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: iconSize + 28)
        }
        .padding(8)
        .contentShape(Rectangle())
        .onTapGesture {
            CloseTracker.shouldClose = false
            onLaunch(app)
        }
    }
}

/// Animated scale-up + fade-out copy of the icon that materialises only while
/// `isLaunching` is true. Owns its own animation state so the puff starts
/// from scale 1 / opacity 1 on insertion and finishes at scale 2.4 / opacity 0.
private struct LaunchPuff: View {
    let icon: NSImage
    let iconSize: CGFloat
    @State private var animated = false

    var body: some View {
        Image(nsImage: icon)
            .resizable()
            .frame(width: iconSize, height: iconSize)
            .scaleEffect(animated ? 2.4 : 1.0)
            .opacity(animated ? 0 : 1)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeOut(duration: 0.18)) {
                    animated = true
                }
            }
    }
}
