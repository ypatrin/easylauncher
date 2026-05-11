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
    private let iconSize: CGFloat = 72
    private var perPage: Int { columns * rows }

    private var allApps: [AppItem] { pages.flatMap { $0 } }

    private var filtered: [AppItem] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        return allApps.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
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
                    searchResults
                } else {
                    pagerView
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

    // MARK: - Pager

    private var pagerView: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                ForEach(pages.indices, id: \.self) { idx in
                    AppGridPage(
                        apps: pages[idx],
                        columns: columns,
                        iconSize: iconSize,
                        launchingId: launchingId,
                        draggingItem: $dragTracker.item,
                        onLaunch: launch,
                        onMove: { from, to in
                            reorder(pageIndex: idx, from: from, to: to)
                        }
                    )
                    .padding(.horizontal, 80)
                    .padding(.vertical, 12)
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

    private var searchResults: some View {
        GeometryReader { geo in
            AppGridPage(
                apps: filtered,
                columns: columns,
                iconSize: iconSize,
                launchingId: launchingId,
                draggingItem: $dragTracker.item,
                onLaunch: launch,
                onMove: nil
            )
            .padding(.horizontal, 80)
            .padding(.vertical, 12)
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .onTapGesture { closeApp() }
        }
    }

    // MARK: - Actions

    private func closeApp() {
        NSApp.terminate(nil)
    }

    private func applyApps(_ scanned: [AppItem]) {
        let savedOrder = LayoutStore.load()
        let scannedById = Dictionary(uniqueKeysWithValues: scanned.map { ($0.id, $0) })

        // Take saved order first, drop any apps that aren't installed anymore.
        var ordered: [AppItem] = []
        var seen = Set<String>()
        for id in savedOrder {
            if let app = scannedById[id] {
                ordered.append(app)
                seen.insert(id)
            }
        }
        // New apps go to the end, in scan (alphabetical) order.
        for app in scanned where !seen.contains(app.id) {
            ordered.append(app)
        }

        var p: [[AppItem]] = []
        var i = 0
        while i < ordered.count {
            let end = min(i + perPage, ordered.count)
            p.append(Array(ordered[i..<end]))
            i = end
        }
        if p.isEmpty { p = [[]] }
        pages = p
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

    private func reorder(pageIndex: Int, from: Int, to: Int) {
        guard pages.indices.contains(pageIndex) else { return }
        var p = pages[pageIndex]
        guard p.indices.contains(from), p.indices.contains(to), from != to else { return }
        let item = p.remove(at: from)
        p.insert(item, at: to)
        pages[pageIndex] = p
        persistLayoutDebounced()
    }

    private func persistLayout() {
        let order = pages.flatMap { $0 }.map { $0.id }
        DispatchQueue.global(qos: .utility).async {
            LayoutStore.save(order)
        }
    }

    private func persistLayoutDebounced() {
        LayoutPersistence.scheduleSave(pages: pages)
    }
}
