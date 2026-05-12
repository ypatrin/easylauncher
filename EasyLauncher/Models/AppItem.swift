import Foundation
import AppKit

struct AppItem: Identifiable, Hashable {
    let id: String        // full path, stable
    let name: String
    let url: URL
    let icon: NSImage

    static func == (lhs: AppItem, rhs: AppItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
