import Foundation

/// Debounced wrapper around `LayoutStore.save` so live-reorder dragging doesn't
/// hammer the disk on every `dropEntered`.
enum LayoutPersistence {
    private static var pending: DispatchWorkItem?
    private static let interval: TimeInterval = 0.4

    static func scheduleSave(pages: [[AppItem]]) {
        pending?.cancel()
        let snapshot = pages.flatMap { $0 }.map { $0.id }
        let work = DispatchWorkItem {
            LayoutStore.save(snapshot)
        }
        pending = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + interval, execute: work)
    }
}

/// Persisted page layout at `~/Library/Application Support/EasyLaunch/layout.json`.
/// The file stores an ordered list of app paths; new apps not present in the
/// list are appended at the end on next launch.
enum LayoutStore {
    private static var directoryURL: URL {
        let support = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support")
        return support.appendingPathComponent("EasyLaunch", isDirectory: true)
    }

    private static var fileURL: URL {
        directoryURL.appendingPathComponent("layout.json")
    }

    private struct Layout: Codable {
        var order: [String]
    }

    /// Returns the saved order of app ids (paths). Empty if the file doesn't exist
    /// or can't be decoded.
    static func load() -> [String] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        do {
            return try JSONDecoder().decode(Layout.self, from: data).order
        } catch {
            return []
        }
    }

    /// Persists the order, creating the directory if needed.
    static func save(_ order: [String]) {
        let fm = FileManager.default
        if !fm.fileExists(atPath: directoryURL.path) {
            do {
                try fm.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            } catch {
                fputs("EasyLaunch: failed to create \(directoryURL.path): \(error)\n", stderr)
                return
            }
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let data = try encoder.encode(Layout(order: order))
            try data.write(to: fileURL, options: .atomic)
        } catch {
            fputs("EasyLaunch: failed to write \(fileURL.path): \(error)\n", stderr)
        }
    }
}
