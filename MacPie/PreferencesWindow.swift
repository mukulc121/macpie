import SwiftUI
import AppKit

final class PreferencesWindow: NSWindowController {
    private let rootView: PreferencesRootView

    init(configurationStore: ConfigurationStore, coordinator: AppCoordinator) {
        self.rootView = PreferencesRootView(configurationStore: configurationStore, coordinator: coordinator)
        let hosting = NSHostingView(rootView: rootView.environmentObject(configurationStore))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 780, height: 520),
                               styleMask: [.titled, .closable, .miniaturizable],
                               backing: .buffered,
                               defer: false)
        window.title = "Preferences"
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = hosting
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct PreferencesRootView: View {
    @ObservedObject var configurationStore: ConfigurationStore
    weak var coordinator: AppCoordinator?

    init(configurationStore: ConfigurationStore, coordinator: AppCoordinator) {
        self.configurationStore = configurationStore
        self.coordinator = coordinator
    }

    var body: some View {
        TabView {
            GeneralPreferencesView(coordinator: coordinator)
                .tabItem { Label("General", systemImage: "gear") }

            ConfigurationsPreferencesView(store: configurationStore)
                .tabItem { Label("Configurations", systemImage: "square.grid.2x2") }
        }
        .padding()
    }
} 