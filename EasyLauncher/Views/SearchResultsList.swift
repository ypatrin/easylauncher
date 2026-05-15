import SwiftUI

/// Spotlight-style dropdown that materialises under the search field when a
/// query is active. Height adapts to the number of results — small for one
/// match, taller for many, capped at `maxListHeight` beyond which it scrolls.
struct SearchResultsList: View {
    let apps: [AppItem]
    @Binding var selectedIndex: Int
    let onLaunch: (AppItem) -> Void
    let emptyMessage: String

    private let rowHeight: CGFloat = 52
    private let rowSpacing: CGFloat = 2
    private let outerPadding: CGFloat = 8
    private let maxListHeight: CGFloat = 520

    /// Natural height of the list before clamping — the scroll view will only
    /// kick in when there are more results than fit in `maxListHeight`.
    private var contentHeight: CGFloat {
        guard !apps.isEmpty else { return rowHeight + outerPadding * 2 }
        let rowsHeight = CGFloat(apps.count) * rowHeight
        let spacingHeight = CGFloat(max(0, apps.count - 1)) * rowSpacing
        return rowsHeight + spacingHeight + outerPadding * 2
    }

    var body: some View {
        panelBackground {
            if apps.isEmpty {
                emptyState
            } else {
                resultsList
            }
        }
        .frame(height: min(contentHeight, maxListHeight))
        .animation(.easeOut(duration: 0.12), value: apps.count)
    }

    // MARK: - Sub-views

    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: rowSpacing) {
                    ForEach(apps.indices, id: \.self) { i in
                        row(for: apps[i], index: i)
                            .id(i)
                    }
                }
                .padding(outerPadding)
            }
            .onChange(of: selectedIndex) { _, newIndex in
                guard apps.indices.contains(newIndex) else { return }
                withAnimation(.easeOut(duration: 0.12)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
            .onChange(of: apps) { _, _ in
                if !apps.indices.contains(selectedIndex) {
                    selectedIndex = 0
                }
            }
        }
    }

    private var emptyState: some View {
        HStack {
            Spacer()
            Text(emptyMessage)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.65))
            Spacer()
        }
        .frame(height: rowHeight)
        .padding(outerPadding)
    }

    @ViewBuilder
    private func panelBackground<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.28))
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            )
    }

    @ViewBuilder
    private func row(for app: AppItem, index: Int) -> some View {
        let isSelected = index == selectedIndex
        HStack(spacing: 14) {
            Image(nsImage: app.icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 32, height: 32)
            Text(app.name)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(height: rowHeight)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.85) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            CloseTracker.shouldClose = false
            selectedIndex = index
            onLaunch(app)
        }
    }
}
