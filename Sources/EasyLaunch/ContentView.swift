import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject private var pager = Pager.shared
    @ObservedObject private var dragTracker = DragTracker.shared

    @State private var pages: [[AppItem]] = []
    @State private var search: String = ""
    @State private var launchingId: String? = nil
    @State private var appeared: Bool = false

    private let columns = 7
    private let rows = 5
    private let baseIconSize: CGFloat = 72
    private let maxIconSize: CGFloat = 108
    private var perPage: Int { columns * rows }

    private var allApps: [AppItem] { pages.flatMap { $0 } }

    private var filtered: [AppItem] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        return allApps.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        GeometryReader { geo in
            let metrics = iconMetrics(for: geo.size)

            ZStack {
                VisualEffectBackground()
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { closeApp() }
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { closeApp() }

                VStack(spacing: 16) {
                    SearchField(text: $search)
                        .frame(maxWidth: 480)
                        .padding(.top, 48)

                    if !search.isEmpty {
                        searchResults(metrics: metrics)
                    } else {
                        pagerView(metrics: metrics)
                        PageIndicator(count: pages.count, current: pager.current) { idx in
                            pager.goTo(idx)
                        }
                        .padding(.bottom, 28)
                    }
                }
            }
            .opacity(appeared ? 1 : 0)
//        .scaleEffect(appeared ? 1 : 0.94)
            .onAppear {
                DispatchQueue.global(qos: .userInitiated).async {
                    let apps = AppScanner.scan()
                    DispatchQueue.main.async {
                        applyApps(apps)
                        withAnimation(.easeOut(duration: 0.10)) {
                            appeared = true
                        }
                    }
                }
            }
        }
    }

    // MARK: - Pager

    private func pagerView(metrics: IconMetrics) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                ForEach(pages.indices, id: \.self) { idx in
                    AppGridPage(
                        apps: pages[idx],
                        pageIndex: idx,
                        columns: columns,
                        rows: rows,
                        iconSize: metrics.iconSize,
                        labelFontSize: metrics.labelFontSize,
                        launchingId: launchingId,
                        draggingItem: $dragTracker.item,
                        onLaunch: launch,
                        onMove: moveDraggedItem,
                        onPageTurnRequest: handleDragPageTurn
                    )
                    .padding(.horizontal, 80)
                    .padding(.top, metrics.gridTopPadding)
                    .padding(.bottom, metrics.gridBottomPadding)
                    .frame(width: w, height: h)
                    .contentShape(Rectangle())
                    .onTapGesture { closeApp() }
                    .offset(x: CGFloat(idx - pager.current) * w)
                    .allowsHitTesting(idx == pager.current)
                }
            }
            .frame(width: w, height: h)
            .clipped()
            .animation(.spring(response: 0.32, dampingFraction: 0.85), value: pager.current)
        }
    }

    // MARK: - Search results

    private func searchResults(metrics: IconMetrics) -> some View {
        GeometryReader { geo in
            AppGridPage(
                apps: filtered,
                pageIndex: 0,
                columns: columns,
                rows: rows,
                iconSize: metrics.iconSize,
                labelFontSize: metrics.labelFontSize,
                launchingId: launchingId,
                draggingItem: $dragTracker.item,
                onLaunch: launch,
                onMove: nil,
                onPageTurnRequest: nil
            )
            .padding(.horizontal, 80)
            .padding(.top, metrics.gridTopPadding)
            .padding(.bottom, metrics.gridBottomPadding)
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .onTapGesture { closeApp() }
        }
    }

    // MARK: - Actions

    private func closeApp() {
        NSApp.terminate(nil)
    }

    private func iconMetrics(for size: CGSize) -> IconMetrics {
        let baseline = CGSize(width: 1440, height: 900)
        let scale = min(size.width / baseline.width, size.height / baseline.height)
        let iconSize = min(max(baseIconSize, floor(baseIconSize * pow(scale, 0.78))), maxIconSize)
        let labelFontSize = min(max(12, floor(iconSize * 0.18)), 17)
        let gridTopPadding = min(max(28, floor(size.height * 0.055)), 72)
        let gridBottomPadding = min(max(42, floor(size.height * 0.085)), 110)
        return IconMetrics(
            iconSize: iconSize,
            labelFontSize: labelFontSize,
            gridTopPadding: gridTopPadding,
            gridBottomPadding: gridBottomPadding
        )
    }

    private func applyApps(_ scanned: [AppItem]) {
        let savedLayout = LayoutStore.load()
        let scannedById = Dictionary(uniqueKeysWithValues: scanned.map { ($0.id, $0) })

        // Take saved order first, drop any apps that aren't installed anymore.
        var ordered: [AppItem] = []
        var seen = Set<String>()
        for id in savedLayout.order {
            if let app = scannedById[id] {
                ordered.append(app)
                seen.insert(id)
            }
        }
        // New apps go to the end, in scan (alphabetical) order.
        for app in scanned where !seen.contains(app.id) {
            ordered.append(app)
        }

        pages = rebuildPages(from: ordered, using: savedLayout.pages)
        pager.reset(pageCount: pages.count)

        // Persist immediately so a freshly-installed app shows up in the file
        // (and a missing-now app is pruned from it).
        persistLayout()
    }

    private func launch(_ app: AppItem) {
        guard launchingId == nil else { return }
        withAnimation(.easeOut(duration: 0.11)) {
            launchingId = app.id
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            NSApp.windows.forEach { $0.orderOut(nil) }
            NSWorkspace.shared.open(app.url)
            NSApp.terminate(nil)
        }
    }

    private func handleDragPageTurn(_ direction: PageTurnDirection) {
        switch direction {
        case .left:
            guard pager.current > 0 else { return }
            pager.goTo(pager.current - 1)
        case .right:
            if pager.current < pages.count - 1 {
                pager.goTo(pager.current + 1)
            } else {
                pages.append([])
                pager.reset(pageCount: pages.count)
                pager.goTo(pages.count - 1)
            }
        }
    }

    private func moveDraggedItem(toPage pageIndex: Int, to targetIndex: Int) {
        guard let dragging = dragTracker.item else { return }
        guard pages.indices.contains(pageIndex) else { return }
        guard let sourcePageIndex = pages.firstIndex(where: { page in
            page.contains(dragging)
        }) else { return }
        guard let sourceItemIndex = pages[sourcePageIndex].firstIndex(of: dragging) else { return }

        let clampedTargetIndex = max(0, min(targetIndex, pages[pageIndex].count))
        if sourcePageIndex == pageIndex, sourceItemIndex == clampedTargetIndex { return }

        var updatedPages = pages
        let item = updatedPages[sourcePageIndex].remove(at: sourceItemIndex)

        var destinationPageIndex = pageIndex
        if sourcePageIndex == pageIndex, sourceItemIndex < clampedTargetIndex {
            destinationPageIndex = pageIndex
        }

        let adjustedTargetIndex: Int = {
            if sourcePageIndex == destinationPageIndex, sourceItemIndex < clampedTargetIndex {
                return clampedTargetIndex - 1
            }
            return clampedTargetIndex
        }()

        let finalTargetIndex = max(0, min(adjustedTargetIndex, updatedPages[destinationPageIndex].count))
        updatedPages[destinationPageIndex].insert(item, at: finalTargetIndex)

        rebalancePages(&updatedPages, startingAt: destinationPageIndex)
        removeEmptyPages(&updatedPages)

        pages = updatedPages
        pager.reset(pageCount: pages.count)
        persistLayoutDebounced()
    }

    private func rebalancePages(_ pages: inout [[AppItem]], startingAt startIndex: Int) {
        guard pages.indices.contains(startIndex) else { return }

        var index = startIndex
        while index < pages.count {
            if pages[index].count <= perPage { break }

            let overflow = pages[index].removeLast()
            if index + 1 >= pages.count {
                pages.append([])
            }
            pages[index + 1].insert(overflow, at: 0)
            index += 1
        }
    }

    private func removeEmptyPages(_ pages: inout [[AppItem]]) {
        pages.removeAll(where: { $0.isEmpty })
        if pages.isEmpty {
            pages = [[]]
        }
    }

    private func persistLayout() {
        let snapshot = pages.map { $0.map(\.id) }
        DispatchQueue.global(qos: .utility).async {
            LayoutStore.save(snapshot)
        }
    }

    private func persistLayoutDebounced() {
        LayoutPersistence.scheduleSave(pages: pages)
    }

    private func rebuildPages(from ordered: [AppItem], using savedPages: [[String]]) -> [[AppItem]] {
        guard !ordered.isEmpty else { return [[]] }

        if savedPages.isEmpty {
            return chunkedPages(from: ordered)
        }

        let orderedById = Dictionary(uniqueKeysWithValues: ordered.map { ($0.id, $0) })
        var rebuilt: [[AppItem]] = []
        var consumed = Set<String>()

        for savedPage in savedPages {
            var page: [AppItem] = []
            for id in savedPage {
                guard let app = orderedById[id], !consumed.contains(id) else { continue }
                page.append(app)
                consumed.insert(id)
            }
            rebuilt.append(page)
        }

        let newApps = ordered.filter { !consumed.contains($0.id) }
        if !newApps.isEmpty {
            if rebuilt.isEmpty {
                rebuilt = chunkedPages(from: newApps)
            } else {
                for app in newApps {
                    if rebuilt[rebuilt.count - 1].count >= perPage {
                        rebuilt.append([])
                    }
                    rebuilt[rebuilt.count - 1].append(app)
                }
            }
        }

        if rebuilt.isEmpty {
            rebuilt = [[]]
        }
        return rebuilt
    }

    private func chunkedPages(from apps: [AppItem]) -> [[AppItem]] {
        var result: [[AppItem]] = []
        var index = 0
        while index < apps.count {
            let end = min(index + perPage, apps.count)
            result.append(Array(apps[index..<end]))
            index = end
        }
        return result.isEmpty ? [[]] : result
    }
}

private struct IconMetrics {
    let iconSize: CGFloat
    let labelFontSize: CGFloat
    let gridTopPadding: CGFloat
    let gridBottomPadding: CGFloat
}
