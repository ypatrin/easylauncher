import SwiftUI
import AppKit

struct LauncherView: View {
    // The pager is intentionally NOT observed here: progress updates fire up to
    // 120 times per second during a trackpad swipe, and re-running the parent
    // body that often (re-allocating displayedPages, re-instantiating every
    // page view) is what created the perceived "jerks". Pager observation
    // lives inside PagerStripView / PageIndicatorBar so only their small
    // bodies re-render on scroll.
    private let pager = Pager.shared
    @ObservedObject private var dragTracker = DragTracker.shared

    @State private var allPages: [[AppItem]] = []
    @State private var search: String = ""
    @State private var launchingId: String? = nil
    @State private var appeared: Bool = false
    @State private var hiddenAppIDs: Set<String> = []
    @State private var showingHiddenApps: Bool = false
    @State private var pagerStripFrame: CGRect = .zero
    @State private var lastMetrics: IconMetrics = IconMetrics(iconSize: 72, labelFontSize: 13, gridTopPadding: 24, gridBottomPadding: 24)
    @State private var searchSelectedIndex: Int = 0

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
            // Compute once per body call rather than re-evaluating the
            // computed property multiple times below.
            let pages = displayedPages

            ZStack {
                LaunchpadBackground()
                    .contentShape(Rectangle())
                    .onTapGesture { closeApp() }

                LauncherKeys(
                    onUp: {
                        guard !search.isEmpty else { return false }
                        moveSearchSelection(by: -1)
                        return true
                    },
                    onDown: {
                        guard !search.isEmpty else { return false }
                        moveSearchSelection(by: 1)
                        return true
                    },
                    onEnter: {
                        guard !search.isEmpty else { return false }
                        let results = filtered
                        guard results.indices.contains(searchSelectedIndex) else { return false }
                        launch(results[searchSelectedIndex])
                        return true
                    },
                    onEscape: {
                        if !search.isEmpty {
                            search = ""
                            searchSelectedIndex = 0
                            return true
                        }
                        closeApp()
                        return true
                    }
                )
                .frame(width: 0, height: 0)

                VStack(spacing: 16) {
                    HStack(spacing: 10) {
                        SearchField(text: $search, placeholder: strings.searchPlaceholder)
                        hiddenAppsToggle
                    }
                    .frame(maxWidth: 536)
                    .padding(.top, 48)

                    // The pager stays mounted regardless of search state so
                    // the icon grid keeps showing behind the dropdown and the
                    // search field doesn't shift position when results appear.
                    ZStack(alignment: .top) {
                        VStack(spacing: 16) {
                            PagerStripView(
                                pager: pager,
                                pages: pages,
                                metrics: metrics,
                                columns: columns,
                                rows: rows,
                                launchingId: launchingId,
                                draggingItem: Binding(
                                    get: { dragTracker.item },
                                    set: { dragTracker.item = $0 }
                                ),
                                isDragging: dragTracker.item != nil,
                                onLaunch: launch,
                                onTapBackground: { closeApp() },
                                onMove: showingHiddenApps ? nil : { pageIndex, targetIndex in
                                    moveDraggedItem(toPage: pageIndex, to: targetIndex)
                                },
                                onPageTurnRequest: showingHiddenApps ? nil : { direction in
                                    handleDragPageTurn(direction)
                                }
                            )
                            PageIndicatorBar(pager: pager, count: pages.count)
                                .padding(.bottom, 28)
                        }
                        .allowsHitTesting(search.isEmpty)

                        if !search.isEmpty {
                            SearchResultsList(
                                apps: filtered,
                                selectedIndex: $searchSelectedIndex,
                                onLaunch: launch,
                                emptyMessage: strings.noResults
                            )
                            .frame(maxWidth: 720)
                            .padding(.horizontal, 40)
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .onChange(of: search) { _, _ in searchSelectedIndex = 0 }
            .opacity(appeared ? 1 : 0)
            .onAppear {
                DispatchQueue.global(qos: .userInitiated).async {
                    let apps = AppsService.scan()
                    DispatchQueue.main.async {
                        applyApps(apps)
                        withAnimation(.easeOut(duration: 0.10)) {
                            appeared = true
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .launcherWillHide)) { _ in
                launchingId = nil
                search = ""
                pager.goTo(0, animated: false)
            }
            .onPreferenceChange(GridAreaFramePreferenceKey.self) { frame in
                pagerStripFrame = frame
                bindIconHitTester()
            }
            .onChange(of: lastMetrics) { _, _ in bindIconHitTester() }
            .onAppear {
                lastMetrics = iconMetrics(for: geo.size)
                bindIconHitTester()
            }
            .onChange(of: geo.size) { _, newSize in
                lastMetrics = iconMetrics(for: newSize)
            }
            .onReceive(NotificationCenter.default.publisher(for: .menuLaunchApp)) { note in
                if let app = note.object as? AppItem { launch(app) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .menuToggleHiddenApp)) { note in
                if let app = note.object as? AppItem { toggleHidden(app) }
            }
        }
    }

    /// Rebuild the hit-test closure used by the global right-click monitor.
    /// Cheap: a single closure capture, no per-cell tracking.
    private func bindIconHitTester() {
        let frame = pagerStripFrame
        let metrics = lastMetrics
        let cols = columns
        let rws = rows
        let hPad: CGFloat = 80
        let hSpacing: CGFloat = 16
        let cellHeight = metrics.iconSize + metrics.labelFontSize + 32
        let pageInnerW = max(0, frame.width - hPad * 2)
        let pageInnerH = max(0, frame.height - metrics.gridTopPadding - metrics.gridBottomPadding)
        let vSpacing: CGFloat = rws > 1
            ? max(12, (pageInnerH - CGFloat(rws) * cellHeight) / CGFloat(rws - 1))
            : 0
        let cellWidth = (pageInnerW - CGFloat(cols - 1) * hSpacing) / CGFloat(cols)
        let originX = frame.minX + hPad
        let originY = frame.minY + metrics.gridTopPadding

        IconHitTester.shared.hitTest = { point in
            // Resolve from current state at call-time so we don't get stale
            // page contents after a reorder or page switch.
            let visiblePages = displayedPages
            let current = pager.current
            guard visiblePages.indices.contains(current) else { return nil }
            let apps = visiblePages[current].apps
            let localX = point.x - originX
            let localY = point.y - originY
            guard localX >= 0, localY >= 0 else { return nil }
            let colPitch = cellWidth + hSpacing
            let rowPitch = cellHeight + vSpacing
            guard colPitch > 0, rowPitch > 0 else { return nil }
            let col = Int(localX / colPitch)
            let row = Int(localY / rowPitch)
            guard col >= 0, col < cols, row >= 0, row < rws else { return nil }
            // Reject clicks that land in the gap between cells.
            let cellLocalX = localX - CGFloat(col) * colPitch
            let cellLocalY = localY - CGFloat(row) * rowPitch
            guard cellLocalX <= cellWidth, cellLocalY <= cellHeight else { return nil }
            let idx = row * cols + col
            guard idx < apps.count else { return nil }
            return apps[idx]
        }
        IconHitTester.shared.isHidden = { app in hiddenAppIDs.contains(app.id) }
        IconHitTester.shared.labels = (
            launch: strings.launch,
            hide: strings.hide,
            show: strings.show
        )
    }

    // MARK: - Pager
    // (PagerStripView / PageIndicatorBar below own all per-frame pager state)

    // MARK: - Search keyboard nav

    private func moveSearchSelection(by delta: Int) {
        let results = filtered
        guard !results.isEmpty else { return }
        let next = searchSelectedIndex + delta
        searchSelectedIndex = max(0, min(results.count - 1, next))
    }

    // MARK: - Actions

    private func closeApp() {
        AppDelegate.shared?.hideLauncher()
    }

    private var hiddenAppsToggle: some View {
        Button {
            CloseTracker.shouldClose = false
            showingHiddenApps.toggle()
            search = ""
            pager.goTo(0, animated: false)
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
        let url = app.url
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            AppDelegate.shared?.hideLauncher()
            NSWorkspace.shared.open(url)
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
        pager.goTo(0, animated: false)
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

private struct IconMetrics: Equatable {
    let iconSize: CGFloat
    let labelFontSize: CGFloat
    let gridTopPadding: CGFloat
    let gridBottomPadding: CGFloat
}

private struct DisplayedPage {
    let canonicalIndex: Int
    let apps: [AppItem]
}

/// Owns the horizontal scrolling carousel. Built on SwiftUI's native paging
/// ScrollView so the gesture tracking, snap, and momentum are driven by
/// AppKit's hardware-accelerated scroller — completely bypassing SwiftUI's
/// per-frame body re-evaluation cycle that causes visible jitter when we
/// hand-roll the scroll math.
private struct PagerStripView: View {
    @ObservedObject var pager: Pager
    let pages: [DisplayedPage]
    let metrics: IconMetrics
    let columns: Int
    let rows: Int
    let launchingId: String?
    @Binding var draggingItem: AppItem?
    let isDragging: Bool
    let onLaunch: (AppItem) -> Void
    let onTapBackground: () -> Void
    let onMove: ((Int, Int) -> Void)?
    let onPageTurnRequest: ((PageTurnDirection) -> Void)?

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(pages.indices, id: \.self) { idx in
                        let page = pages[idx]
                        AppGridPage(
                            apps: page.apps,
                            pageIndex: idx,
                            columns: columns,
                            rows: rows,
                            iconSize: metrics.iconSize,
                            labelFontSize: metrics.labelFontSize,
                            launchingId: launchingId,
                            draggingItem: $draggingItem,
                            onLaunch: onLaunch,
                            onMove: onMove,
                            onPageTurnRequest: onPageTurnRequest
                        )
                        .padding(.horizontal, 80)
                        .padding(.top, metrics.gridTopPadding)
                        .padding(.bottom, metrics.gridBottomPadding)
                        .frame(width: w, height: h)
                        .contentShape(Rectangle())
                        .onTapGesture { onTapBackground() }
                        .id(idx)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.never)
            // Apple's view-aligned snap with a hard "one view per gesture"
            // cap. It uses a fixed-duration spring animation that doesn't
            // collapse to a frame when the gesture velocity is high, so fast
            // flicks still visibly animate to the next page rather than
            // jumping.
            .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
            .scrollPosition(id: scrollPositionBinding)
            .scrollClipDisabled(false)
            // Publishes the strip's screen frame upward — LauncherView uses
            // it to translate right-click cursor positions into cell indices.
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: GridAreaFramePreferenceKey.self,
                        value: proxy.frame(in: .global)
                    )
                }
            )
        }
    }

    /// Two-way binding into `pager.current`. ScrollView writes here when the
    /// snap commits to a new page; external writes (page-indicator taps,
    /// drag-to-edge) animate the ScrollView the same way.
    private var scrollPositionBinding: Binding<Int?> {
        Binding(
            get: { pager.current },
            set: { newValue in
                guard let newValue, newValue != pager.current else { return }
                pager.current = newValue
            }
        )
    }
}

/// Page-dot indicator. Isolated so only this view re-renders when
/// `pager.current` changes — not the entire launcher.
private struct PageIndicatorBar: View {
    @ObservedObject var pager: Pager
    let count: Int

    var body: some View {
        PageIndicator(count: count, current: pager.current) { idx in
            pager.goTo(idx)
        }
    }
}

