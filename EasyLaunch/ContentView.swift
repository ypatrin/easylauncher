import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject private var pager = Pager.shared
    @ObservedObject private var dragTracker = DragTracker.shared

    @State private var allPages: [[AppItem]] = []
    @State private var search: String = ""
    @State private var launchingId: String? = nil
    @State private var appeared: Bool = false
    @State private var hiddenAppIDs: Set<String> = []
    @State private var showingHiddenApps: Bool = false

    private let columns = 7
    private let rows = 5
    private let baseIconSize: CGFloat = 72
    private let maxIconSize: CGFloat = 108
    private var perPage: Int { columns * rows }
    private var strings: L10n.Strings { L10n.current }

    private var allApps: [AppItem] { allPages.flatMap { $0 } }

    private var displayedPages: [DisplayedPage] {
        let includeHidden = showingHiddenApps
        var result = allPages.enumerated().compactMap { index, page -> DisplayedPage? in
            let filtered = page.filter { app in
                includeHidden ? hiddenAppIDs.contains(app.id) : !hiddenAppIDs.contains(app.id)
            }
            if filtered.isEmpty {
                let isTrailingEmptyVisiblePage = !includeHidden
                    && dragTracker.item != nil
                    && index == allPages.indices.last
                    && page.isEmpty
                return isTrailingEmptyVisiblePage ? DisplayedPage(canonicalIndex: index, apps: []) : nil
            }
            return DisplayedPage(canonicalIndex: index, apps: filtered)
        }

        if result.isEmpty {
            let fallbackIndex = allPages.indices.last ?? 0
            result = [DisplayedPage(canonicalIndex: fallbackIndex, apps: [])]
        }
        return result
    }

    private var displayedApps: [AppItem] {
        displayedPages.flatMap(\.apps)
    }

    private var filtered: [AppItem] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        return displayedApps.filter { $0.name.localizedCaseInsensitiveContains(q) }
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
                    HStack(spacing: 10) {
                        SearchField(text: $search, placeholder: strings.searchPlaceholder)
                        hiddenAppsToggle
                    }
                    .frame(maxWidth: 536)
                    .padding(.top, 48)

                    if !search.isEmpty {
                        searchResults(metrics: metrics)
                    } else {
                        pagerView(metrics: metrics)
                        PageIndicator(count: displayedPages.count, current: pager.current) { idx in
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
            let draggingBinding = Binding<AppItem?>(
                get: { dragTracker.item },
                set: { dragTracker.item = $0 }
            )
            ZStack {
                ForEach(displayedPages.indices, id: \.self) { idx in
                    let page = displayedPages[idx]
                    AppGridPage(
                        apps: page.apps,
                        pageIndex: idx,
                        columns: columns,
                        rows: rows,
                        iconSize: metrics.iconSize,
                        labelFontSize: metrics.labelFontSize,
                        launchingId: launchingId,
                        draggingItem: draggingBinding,
                        onLaunch: launch,
                        onToggleHidden: toggleHidden,
                        isHidden: { hiddenAppIDs.contains($0.id) },
                        strings: strings,
                        onMove: showingHiddenApps ? nil : { pageIndex, targetIndex in
                            moveDraggedItem(toPage: pageIndex, to: targetIndex)
                        },
                        onPageTurnRequest: showingHiddenApps ? nil : { direction in
                            handleDragPageTurn(direction)
                        }
                    )
                    .padding(.horizontal, 80)
                    .padding(.top, metrics.gridTopPadding)
                    .padding(.bottom, metrics.gridBottomPadding)
                    .frame(width: w, height: h)
                    .compositingGroup()
                    .contentShape(Rectangle())
                    .onTapGesture { closeApp() }
                    .offset(x: CGFloat(idx - pager.current) * w)
                    .allowsHitTesting(idx == pager.current)
                }
            }
            .frame(width: w, height: h)
            .clipped()
            .animation(.timingCurve(0.16, 0.84, 0.24, 1, duration: 0.8), value: pager.current)
        }
    }

    // MARK: - Search results

    private func searchResults(metrics: IconMetrics) -> some View {
        GeometryReader { geo in
            let draggingBinding = Binding<AppItem?>(
                get: { dragTracker.item },
                set: { dragTracker.item = $0 }
            )
            AppGridPage(
                apps: filtered,
                pageIndex: 0,
                columns: columns,
                rows: rows,
                iconSize: metrics.iconSize,
                labelFontSize: metrics.labelFontSize,
                launchingId: launchingId,
                draggingItem: draggingBinding,
                onLaunch: launch,
                onToggleHidden: toggleHidden,
                isHidden: { hiddenAppIDs.contains($0.id) },
                strings: strings,
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

    private var hiddenAppsToggle: some View {
        Button {
            CloseTracker.shouldClose = false
            showingHiddenApps.toggle()
            search = ""
            pager.goTo(0)
            pager.reset(pageCount: displayedPages.count)
        } label: {
            Image(systemName: showingHiddenApps ? "eye.slash.circle.fill" : "eye.slash.circle")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(showingHiddenApps ? .white : .white.opacity(0.72))
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(showingHiddenApps ? Color.white.opacity(0.16) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(showingHiddenApps ? strings.visibleApps : strings.hiddenApps)
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

        allPages = rebuildPages(from: ordered, using: savedLayout.pages)
        hiddenAppIDs = savedLayout.hiddenAppIDs.intersection(Set(scanned.map(\.id)))
        pager.reset(pageCount: displayedPages.count)

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
        guard !showingHiddenApps else { return }
        switch direction {
        case .left:
            guard pager.current > 0 else { return }
            pager.goTo(pager.current - 1)
        case .right:
            if pager.current < displayedPages.count - 1 {
                pager.goTo(pager.current + 1)
            } else {
                allPages.append([])
                pager.reset(pageCount: displayedPages.count)
                pager.goTo(displayedPages.count - 1)
            }
        }
    }

    private func moveDraggedItem(toPage pageIndex: Int, to targetIndex: Int) {
        guard !showingHiddenApps else { return }
        guard let dragging = dragTracker.item else { return }
        guard displayedPages.indices.contains(pageIndex) else { return }

        let destinationCanonicalPageIndex = displayedPages[pageIndex].canonicalIndex
        let visibleTargetPageApps = displayedPages[pageIndex].apps

        guard allPages.indices.contains(destinationCanonicalPageIndex) else { return }
        guard let sourcePageIndex = allPages.firstIndex(where: { page in
            page.contains(dragging)
        }) else { return }
        guard let sourceItemIndex = allPages[sourcePageIndex].firstIndex(of: dragging) else { return }

        var updatedPages = allPages
        let item = updatedPages[sourcePageIndex].remove(at: sourceItemIndex)

        let destinationVisibleAppsAfterRemoval: [AppItem] = {
            if sourcePageIndex == destinationCanonicalPageIndex {
                return visibleTargetPageApps.filter { $0.id != dragging.id }
            }
            return updatedPages[destinationCanonicalPageIndex].filter { !hiddenAppIDs.contains($0.id) }
        }()

        let clampedTargetIndex = max(0, min(targetIndex, destinationVisibleAppsAfterRemoval.count))
        let insertionIndex = canonicalInsertionIndex(
            in: updatedPages[destinationCanonicalPageIndex],
            visibleApps: destinationVisibleAppsAfterRemoval,
            visibleTargetIndex: clampedTargetIndex
        )

        updatedPages[destinationCanonicalPageIndex].insert(item, at: insertionIndex)
        rebalancePages(&updatedPages, startingAt: destinationCanonicalPageIndex)
        removeEmptyPages(&updatedPages)

        allPages = updatedPages
        pager.reset(pageCount: displayedPages.count)
        persistLayoutDebounced()
    }

    private func toggleHidden(_ app: AppItem) {
        if hiddenAppIDs.contains(app.id) {
            hiddenAppIDs.remove(app.id)
        } else {
            hiddenAppIDs.insert(app.id)
        }
        pager.goTo(0)
        pager.reset(pageCount: displayedPages.count)
        persistLayoutDebounced()
    }

    private func canonicalInsertionIndex(
        in page: [AppItem],
        visibleApps: [AppItem],
        visibleTargetIndex: Int
    ) -> Int {
        guard !page.isEmpty else { return 0 }
        guard !visibleApps.isEmpty else { return page.count }

        if visibleTargetIndex >= visibleApps.count {
            guard let lastVisible = visibleApps.last,
                  let lastVisibleIndex = page.firstIndex(of: lastVisible)
            else { return page.count }
            return lastVisibleIndex + 1
        }

        let nextVisible = visibleApps[visibleTargetIndex]
        return page.firstIndex(of: nextVisible) ?? page.count
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
        let snapshot = allPages.map { $0.map(\.id) }
        DispatchQueue.global(qos: .utility).async {
            LayoutStore.save(snapshot, hiddenAppIDs: hiddenAppIDs)
        }
    }

    private func persistLayoutDebounced() {
        LayoutPersistence.scheduleSave(pages: allPages, hiddenAppIDs: hiddenAppIDs)
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

private struct DisplayedPage {
    let canonicalIndex: Int
    let apps: [AppItem]
}
