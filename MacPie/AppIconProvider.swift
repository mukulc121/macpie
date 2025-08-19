import AppKit

enum AppIconProvider {
    static func icon(for bundleIdentifier: String, size: CGFloat = 20) -> NSImage {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            let img = NSWorkspace.shared.icon(forFile: url.path)
            img.size = NSSize(width: size, height: size)
            return img
        }
        // Fallback to generic app icon
        let generic = NSWorkspace.shared.icon(forFileType: "app")
        generic.size = NSSize(width: size, height: size)
        return generic
    }
} 