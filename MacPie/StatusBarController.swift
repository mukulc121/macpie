import AppKit

final class StatusBarController {
    private var statusItem: NSStatusItem!
    private let onTogglePie: () -> Void
    private var onOpenPreferences: (() -> Void)?

    init(onTogglePie: @escaping () -> Void, onOpenPreferences: (() -> Void)? = nil) {
        self.onTogglePie = onTogglePie
        self.onOpenPreferences = onOpenPreferences
        setup()
    }

    private func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🍰"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Toggle Pie", action: #selector(togglePie), keyEquivalent: "p"))
        menu.addItem(NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit MacPie", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    @objc private func togglePie() { onTogglePie() }
    @objc private func openPreferences() { onOpenPreferences?() }
    @objc private func quit() { NSApp.terminate(nil) }
} 