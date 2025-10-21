import SwiftUI
import AppKit

final class PreferencesWindow: NSWindowController {
    private let rootView: PreferencesRootView

    init(configurationStore: ConfigurationStore, coordinator: AppCoordinator) {
        self.rootView = PreferencesRootView(configurationStore: configurationStore, coordinator: coordinator)
        let hosting = NSHostingView(rootView: rootView.environmentObject(configurationStore))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1086, height: 650),
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
    @State private var selectedTab = 1 // 0=General, 1=Pie, 2=Actions

    init(configurationStore: ConfigurationStore, coordinator: AppCoordinator) {
        self.configurationStore = configurationStore
        self.coordinator = coordinator
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with version and tabs - Full width background
            VStack(spacing: 0) {
                // Full width background container
                VStack(spacing: 12) {
                    // Version
                    Text("Macpie 1.0.0")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Color(hex: "858585"))
                    
                    // Tabs - Left aligned
                    HStack(spacing: 19) {
                        // General Tab
                        Button(action: { selectedTab = 0 }) {
                            HStack(spacing: 8) {
                                Image(systemName: "gear")
                                    .font(.system(size: 16))
                                Text("General")
                                    .font(.system(size: 16, weight: .regular))
                            }
                            .foregroundColor(selectedTab == 0 ? .white : Color(hex: "8b8b8b"))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                selectedTab == 0 ? 
                                AnyView(Color(hex: "444444")
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                                    .shadow(color: .black.opacity(0.2), radius: 11, x: 0, y: 4))
                                : AnyView(Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                        
                        // Pie Configuration Tab
                        Button(action: { selectedTab = 1 }) {
                            HStack(spacing: 8) {
                                Image(systemName: "circle.grid.cross")
                                    .font(.system(size: 16))
                                Text("Pie Configuration")
                                    .font(.system(size: 16, weight: .regular))
                            }
                            .foregroundColor(selectedTab == 1 ? .white : Color(hex: "8b8b8b"))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                selectedTab == 1 ? 
                                AnyView(Color(hex: "444444")
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                                    .shadow(color: .black.opacity(0.2), radius: 11, x: 0, y: 4))
                                : AnyView(Color.clear)
                            )
                        }
                        .buttonStyle(.plain)

                        // Actions Tab (Logi-style)
                        Button(action: { selectedTab = 2 }) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.grid.2x2")
                                    .font(.system(size: 16))
                                Text("Actions")
                                    .font(.system(size: 16, weight: .regular))
                            }
                            .foregroundColor(selectedTab == 2 ? .white : Color(hex: "8b8b8b"))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                selectedTab == 2 ?
                                AnyView(Color(hex: "444444")
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                                    .shadow(color: .black.opacity(0.2), radius: 11, x: 0, y: 4))
                                : AnyView(Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "303032"))
                .shadow(color: .black.opacity(0.1), radius: 5.55, x: 0, y: 4)
            }
            
            // Content
            Group {
                if selectedTab == 0 {
                    GeneralPreferencesView(coordinator: coordinator)
                        .environmentObject(configurationStore)
                } else if selectedTab == 1 {
                    PieConfigurationView()
                        .environmentObject(configurationStore)
                } else {
                    ActionsConfigurationView()
                        .environmentObject(configurationStore)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(hex: "222425"))
        .frame(width: 1086, height: 650)
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }
} 