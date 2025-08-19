import Foundation
import AppKit

struct DiscoveredApp {
    let name: String
    let bundleIdentifier: String
    let path: String
}

enum AppDiscovery {
    static func findInstalledApps() -> [DiscoveredApp] {
        let dirs: [URL] = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            URL(fileURLWithPath: "/Applications/Utilities", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications/Utilities", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        ]
        var results: [DiscoveredApp] = []
        let fm = FileManager.default
        for dir in dirs {
            guard let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { continue }
            for case let url as URL in enumerator {
                if url.pathExtension == "app" {
                    if let infoPlistURL = url.appendingPathComponent("Contents/Info.plist", isDirectory: false) as URL?,
                       let dict = NSDictionary(contentsOf: infoPlistURL) as? [String: Any],
                       let bundleId = dict["CFBundleIdentifier"] as? String {
                        let name = (dict["CFBundleDisplayName"] as? String)
                            ?? (dict["CFBundleName"] as? String)
                            ?? url.deletingPathExtension().lastPathComponent
                        results.append(DiscoveredApp(name: name, bundleIdentifier: bundleId, path: url.path))
                    }
                }
            }
        }
        // Deduplicate by bundle id
        var seen: Set<String> = []
        var unique: [DiscoveredApp] = []
        for app in results {
            if !seen.contains(app.bundleIdentifier) {
                unique.append(app)
                seen.insert(app.bundleIdentifier)
            }
        }
        return unique.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
} 