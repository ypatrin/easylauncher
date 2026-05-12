import Foundation
import AppKit

enum AppsService {
    static func scan() -> [AppItem] {
        let home = NSString(string: "~/Applications").expandingTildeInPath
        let roots = [
            "/Applications",
            "/Applications/Utilities",
            "/System/Applications",
            "/System/Applications/Utilities",
            home,
        ]
        var seen = Set<String>()
        var result: [AppItem] = []
        for root in roots {
            collect(root: root, depth: 0, seen: &seen, into: &result)
        }
        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func collect(root: String, depth: Int, seen: inout Set<String>, into result: inout [AppItem]) {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: root) else { return }
        for entry in entries {
            if entry.hasPrefix(".") { continue }
            let full = (root as NSString).appendingPathComponent(entry)
            if entry.hasSuffix(".app") {
                let key = entry.lowercased()
                if seen.contains(key) { continue }
                seen.insert(key)
                let url = URL(fileURLWithPath: full)
                let icon = NSWorkspace.shared.icon(forFile: full)
                icon.size = NSSize(width: 128, height: 128)
                result.append(AppItem(
                    id: full,
                    name: displayName(for: url),
                    url: url,
                    icon: icon
                ))
            } else if depth < 1 {
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: full, isDirectory: &isDir), isDir.boolValue {
                    collect(root: full, depth: depth + 1, seen: &seen, into: &result)
                }
            }
        }
    }

    private static func displayName(for url: URL) -> String {
        let plistURL = url.appendingPathComponent("Contents/Info.plist")
        if let data = try? Data(contentsOf: plistURL),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            if let s = plist["CFBundleDisplayName"] as? String, !s.isEmpty { return s }
            if let s = plist["CFBundleName"] as? String, !s.isEmpty { return s }
        }
        return url.deletingPathExtension().lastPathComponent
    }
}
