import SwiftUI
import UniformTypeIdentifiers

struct AppGridPage: View {
    let apps: [AppItem]
    let columns: Int
    let iconSize: CGFloat
    let launchingId: String?
    @Binding var draggingItem: AppItem?
    let onLaunch: (AppItem) -> Void
    /// Live-reorder callback. nil disables drag (e.g. search results).
    let onMove: ((Int, Int) -> Void)?

    private let hSpacing: CGFloat = 16
    private var cellHeight: CGFloat { iconSize + 36 }

    var body: some View {
        GeometryReader { geo in
            let rowsCount = max(1, Int(ceil(Double(apps.count) / Double(columns))))
            let vSpacing: CGFloat = {
                guard rowsCount > 1 else { return 0 }
                let extra = geo.size.height - CGFloat(rowsCount) * cellHeight
                return max(12, extra / CGFloat(rowsCount - 1))
            }()
            let cellWidth = (geo.size.width - CGFloat(columns - 1) * hSpacing) / CGFloat(columns)
            let cols = Array(
                repeating: GridItem(.flexible(), spacing: hSpacing),
                count: columns
            )

            LazyVGrid(columns: cols, spacing: vSpacing) {
                ForEach(apps, id: \.id) { app in
                    cell(for: app)
                }
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.78), value: apps)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            .contentShape(Rectangle())
            .onDrop(of: [.text], delegate: GridDropDelegate(
                apps: apps,
                columns: columns,
                cellWidth: cellWidth,
                cellHeight: cellHeight,
                hSpacing: hSpacing,
                vSpacing: vSpacing,
                draggingItem: $draggingItem,
                onMove: onMove
            ))
        }
    }

    @ViewBuilder
    private func cell(for app: AppItem) -> some View {
        let dragged = draggingItem?.id == app.id
        AppIconView(
            app: app,
            iconSize: iconSize,
            isLaunching: app.id == launchingId,
            onLaunch: onLaunch
        )
        .opacity(dragged ? 0 : 1)
        .modifier(CellDragModifier(
            app: app,
            draggingItem: $draggingItem,
            enabled: onMove != nil
        ))
    }
}

private struct CellDragModifier: ViewModifier {
    let app: AppItem
    @Binding var draggingItem: AppItem?
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content
                .onDrag {
                    draggingItem = app
                    return NSItemProvider(object: app.id as NSString)
                } preview: {
                    Image(nsImage: app.icon)
                        .resizable()
                        .frame(width: 86, height: 86)
                }
        } else {
            content
        }
    }
}

/// Single drop target covering the whole page. Translates cursor location to
/// a target grid index (works both over a cell and in the gaps between cells),
/// then triggers a live reorder. This is what gives the "open up to make room"
/// feel of the original Launchpad.
private struct GridDropDelegate: DropDelegate {
    let apps: [AppItem]
    let columns: Int
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    let hSpacing: CGFloat
    let vSpacing: CGFloat
    @Binding var draggingItem: AppItem?
    let onMove: ((Int, Int) -> Void)?

    private func targetIndex(at point: CGPoint) -> Int {
        guard !apps.isEmpty else { return 0 }
        let colPitch = cellWidth + hSpacing
        let rowPitch = cellHeight + vSpacing
        let col = max(0, min(columns - 1, Int(point.x / max(1, colPitch))))
        let row = max(0, Int(point.y / max(1, rowPitch)))
        let raw = row * columns + col
        return min(max(0, raw), apps.count - 1)
    }

    private func attemptReorder(at point: CGPoint) {
        guard let dragging = draggingItem,
              let onMove,
              let from = apps.firstIndex(of: dragging)
        else { return }
        let to = targetIndex(at: point)
        guard to != from else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            onMove(from, to)
        }
    }

    func dropEntered(info: DropInfo) {
        attemptReorder(at: info.location)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        attemptReorder(at: info.location)
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        attemptReorder(at: info.location)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
            draggingItem = nil
        }
        return true
    }
}
