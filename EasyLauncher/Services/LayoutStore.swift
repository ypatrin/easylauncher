import Foundation

/// Debounced wrapper around `LayoutStore.save` so live-reorder dragging doesn't
/// hammer the disk on every `dropEntered`.
enum LayoutPersistence {
    private static var pending: DispatchWorkItem?
    private static let interval: TimeInterval = 0.4

    static func scheduleSave(pages: [[AppItem]], hiddenAppIDs: Set<String>) {
        pending?.cancel()
        let snapshot = pages.map { $0.map(\.id) }
        let work = DispatchWorkItem {
            LayoutStore.save(snapshot, hiddenAppIDs: hiddenAppIDs)
        }
        pending = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + interval, execute: work)
    }
}

/// Persisted page layout at `~/Library/Application Support/EasyLauncher/layout.json`.
/// The file stores both page boundaries and app order. Old flat-order files are
/// still accepted and transparently upgraded on next save.
enum LayoutStore {
    private static var directoryURL: URL {
        let support = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support")
        return support.appendingPathComponent("EasyLauncher", isDirectory: true)
    }

    private static var fileURL: URL {
        directoryURL.appendingPathComponent("layout.json")
    }

    private struct Layout: Codable {
        var order: [String]
        var pages: [[String]]?
        var hidden: [String]?
    }

    struct Snapshot {
        let pages: [[String]]
        let hiddenAppIDs: Set<String>

        var order: [String] {
            pages.flatMap { $0 }
        }
    }

    /// Returns the saved layout. Empty if the file doesn't exist or can't be decoded.
    static func load() -> Snapshot {
        guard let data = try? Data(contentsOf: fileURL) else {
            return Snapshot(pages: [], hiddenAppIDs: [])
        }
        do {
            let layout = try JSONDecoder().decode(Layout.self, from: data)
            let hiddenAppIDs = Set(layout.hidden ?? [])
            if let pages = layout.pages, !pages.isEmpty {
                return Snapshot(pages: pages, hiddenAppIDs: hiddenAppIDs)
            }
            return Snapshot(
                pages: layout.order.isEmpty ? [] : [layout.order],
                hiddenAppIDs: hiddenAppIDs
            )
        } catch {
            return Snapshot(pages: [], hiddenAppIDs: [])
        }
    }

    /// Persists page boundaries and app order, creating the directory if needed.
    static func save(_ pages: [[String]], hiddenAppIDs: Set<String>) {
        let fm = FileManager.default
        if !fm.fileExists(atPath: directoryURL.path) {
            do {
                try fm.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            } catch {
                fputs("EasyLauncher: failed to create \(directoryURL.path): \(error)\n", stderr)
                return
            }
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let nonEmptyPages = pages.filter { !$0.isEmpty }
            let order = nonEmptyPages.flatMap { $0 }
            let hidden = Array(hiddenAppIDs).sorted()
            let data = try encoder.encode(Layout(order: order, pages: nonEmptyPages, hidden: hidden))
            try data.write(to: fileURL, options: .atomic)
        } catch {
            fputs("EasyLauncher: failed to write \(fileURL.path): \(error)\n", stderr)
        }
    }
}
