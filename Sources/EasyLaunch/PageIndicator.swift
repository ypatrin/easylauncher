import SwiftUI

struct PageIndicator: View {
    let count: Int
    let current: Int
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<max(count, 1), id: \.self) { i in
                let active = i == current
                Circle()
                    .fill(active ? Color.white : Color.white.opacity(0.4))
                    .frame(width: active ? 11 : 6, height: active ? 11 : 6)
                    .animation(.easeInOut(duration: 0.15), value: active)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        CloseTracker.shouldClose = false
                        onSelect(i)
                    }
            }
        }
        .frame(height: 14)
    }
}
