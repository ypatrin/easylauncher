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
            Image(nsImage: app.icon)
                .resizable()
                .interpolation(.high)
                .frame(width: iconSize, height: iconSize)
                .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
            Text(app.name)
                .font(.system(size: labelFontSize))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.tail)
                .shadow(color: .black.opacity(0.6), radius: 2, y: 1)
                .frame(maxWidth: iconSize + 28)
        }
        .padding(8)
        .scaleEffect(isLaunching ? 2.4 : 1.0)
        .opacity(isLaunching ? 0 : 1)
        .contentShape(Rectangle())
        .onTapGesture {
            CloseTracker.shouldClose = false
            onLaunch(app)
        }
    }
}
