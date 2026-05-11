import SwiftUI
import UniformTypeIdentifiers

struct AppGridPage: View {
    let apps: [AppItem]
    let pageIndex: Int
    let columns: Int
    let rows: Int
    let iconSize: CGFloat
    let labelFontSize: CGFloat
    let launchingId: String?
    @Binding var draggingItem: AppItem?
    let onLaunch: (AppItem) -> Void
    let onToggleHidden: (AppItem) -> Void
    let isHidden: (AppItem) -> Bool
    let strings: L10n.Strings
    /// Live-reorder callback. nil disables drag (e.g. search results).
    let onMove: ((Int, Int) -> Void)?
    let onPageTurnRequest: ((PageTurnDirection) -> Void)?

    private let hSpacing: CGFloat = 16
    private var cellHeight: CGFloat { iconSize + labelFontSize + 32 }

    var body: some View {
        GeometryReader { geo in
            let rowsCount = max(1, rows)
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
                pageIndex: pageIndex,
                columns: columns,
                pageWidth: geo.size.width,
                cellWidth: cellWidth,
                cellHeight: cellHeight,
                hSpacing: hSpacing,
                vSpacing: vSpacing,
                draggingItem: $draggingItem,
                onMove: onMove,
                onPageTurnRequest: onPageTurnRequest
            ))
        }
    }

    @ViewBuilder
    private func cell(for app: AppItem) -> some View {
        let dragged = draggingItem?.id == app.id
        AppIconView(
            app: app,
            iconSize: iconSize,
            labelFontSize: labelFontSize,
            isLaunching: app.id == launchingId,
            isHidden: isHidden(app),
            strings: strings,
            onLaunch: onLaunch,
            onToggleHidden: onToggleHidden
        )
        .opacity(dragged ? 0 : 1)
        .modifier(CellDragModifier(
            app: app,
            draggingItem: $draggingItem,
            iconSize: iconSize,
            enabled: onMove != nil
        ))
    }
}

private struct CellDragModifier: ViewModifier {
    let app: AppItem
    @Binding var draggingItem: AppItem?
    let iconSize: CGFloat
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
                        .frame(width: iconSize * 1.2, height: iconSize * 1.2)
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
    let pageIndex: Int
    let columns: Int
    let pageWidth: CGFloat
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    let hSpacing: CGFloat
    let vSpacing: CGFloat
    @Binding var draggingItem: AppItem?
    let onMove: ((Int, Int) -> Void)?
    let onPageTurnRequest: ((PageTurnDirection) -> Void)?

    private let edgeTurnZone: CGFloat = 72

    private func targetIndex(at point: CGPoint) -> Int {
        let colPitch = cellWidth + hSpacing
        let rowPitch = cellHeight + vSpacing
        let col = max(0, min(columns - 1, Int(point.x / max(1, colPitch))))
        let row = max(0, Int(point.y / max(1, rowPitch)))
        let raw = row * columns + col
        return min(max(0, raw), apps.count)
    }

    private func attemptReorder(at point: CGPoint) {
        guard draggingItem != nil, let onMove else { return }
        let to = targetIndex(at: point)
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            onMove(pageIndex, to)
        }
    }

    private func handleEdgeTurnIfNeeded(at point: CGPoint) -> Bool {
        guard draggingItem != nil, let onPageTurnRequest else { return false }

        if point.x <= edgeTurnZone {
            DragTracker.shared.schedulePageTurn(.left) {
                onPageTurnRequest(.left)
            }
            return true
        }

        if point.x >= pageWidth - edgeTurnZone {
            DragTracker.shared.schedulePageTurn(.right) {
                onPageTurnRequest(.right)
            }
            return true
        }

        DragTracker.shared.cancelPendingPageTurn()
        return false
    }

    func dropEntered(info: DropInfo) {
        if handleEdgeTurnIfNeeded(at: info.location) { return }
        attemptReorder(at: info.location)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        if handleEdgeTurnIfNeeded(at: info.location) {
            return DropProposal(operation: .move)
        }
        attemptReorder(at: info.location)
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        DragTracker.shared.cancelPendingPageTurn()
        attemptReorder(at: info.location)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
            draggingItem = nil
        }
        return true
    }
}
