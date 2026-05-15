import SwiftUI

/// Abstract, brightly-coloured backdrop. A handful of saturated radial
/// gradients are stacked over a deep base colour and then heavily blurred,
/// producing a soft aurora/frosted-glass look that doesn't depend on the
/// user's wallpaper or any screen-capture permissions.
struct LaunchpadBackground: View {
    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let r = max(size.width, size.height)

            ZStack {
                // Dark base — keeps the overall mood deep so the bright
                // blobs read as glowing accents rather than flooding the
                // whole screen.
                Color(red: 0.06, green: 0.05, blue: 0.12)

                blob(color: Color(red: 0.78, green: 0.36, blue: 1.00),
                     at: UnitPoint(x: 0.12, y: 0.18),
                     size: size, scale: 1.05)

                blob(color: Color(red: 0.20, green: 1.00, blue: 1.00),
                     at: UnitPoint(x: 0.88, y: 0.22),
                     size: size, scale: 1.15)

                blob(color: Color(red: 1.00, green: 0.42, blue: 0.82),
                     at: UnitPoint(x: 0.20, y: 0.85),
                     size: size, scale: 1.10)

                blob(color: Color(red: 1.00, green: 0.78, blue: 0.28),
                     at: UnitPoint(x: 0.82, y: 0.88),
                     size: size, scale: 1.00)

                blob(color: Color(red: 0.55, green: 0.60, blue: 1.00),
                     at: UnitPoint(x: 0.50, y: 0.50),
                     size: size, scale: 1.00)
            }
            .frame(width: size.width, height: size.height)
            .blur(radius: r * 0.08)
            // Darken the whole composition so the blobs become coloured
            // light rather than solid washes.
            .overlay(Color.black.opacity(0.42))
            // Rasterise the whole composition (5 radial gradients + .screen
            // blends + heavy blur + overlay) into a single Metal-backed
            // bitmap so the GPU doesn't recompute it every frame while
            // pages slide.
            .drawingGroup(opaque: true)
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }

    private func blob(color: Color, at point: UnitPoint, size: CGSize, scale: CGFloat) -> some View {
        let r = max(size.width, size.height) * 0.55 * scale
        return RadialGradient(
            gradient: Gradient(colors: [color.opacity(1.0), color.opacity(0.0)]),
            center: point,
            startRadius: 0,
            endRadius: r
        )
        .blendMode(.screen)
    }
}
