import SwiftUI
import AppKit
import Carbon
import ServiceManagement

final class AppCoordinator: ObservableObject {
    private let hotkeyManager = HotkeyManager()
    private var statusBar: StatusBarController!
    private var overlay: PieOverlayController?
    private let store = ConfigurationStore()
    private lazy var prefsWindow = PreferencesWindow(configurationStore: store, coordinator: self)

    // Track current hovered slice reported by overlay
    private var currentHoveredIndex: Int?

    init() {
        statusBar = StatusBarController(onTogglePie: { [weak self] in
            self?.togglePie()
        }, onOpenPreferences: { [weak self] in
            self?.openPreferences()
        })
        // Ensure Accessibility permission early
        _ = PermissionsManager.shared.ensureAccessibilityPermission(prompt: true)
        applyGeneralSettings()
    }

    private func applyGeneralSettings() {
        updateHotkey(keyCode: store.general.hotkeyKeyCode, modifiers: store.general.hotkeyModifiers)
        applyLaunchAtLogin(store.general.launchAtLogin)
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        // Best-effort: create or remove a login item
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                    } catch {
            // Launch at login toggle failed
        }
        }
    }

    func updateHotkey(keyCode: UInt32, modifiers: UInt32) {
        hotkeyManager.register(keyCode: keyCode, modifiers: modifiers, onDown: { [weak self] in
            self?.showPie()
        }, onUp: { [weak self] in
            self?.selectAndHideIfAny()
        })
        store.general.hotkeyKeyCode = keyCode
        store.general.hotkeyModifiers = modifiers
        store.save()
    }

    private func currentAppProfile() -> AppProfile? {
        let bundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
        let appName = NSWorkspace.shared.frontmostApplication?.localizedName ?? ""
        
        NSLog("Current app detection - bundleId: \(bundleId), appName: \(appName)")
        NSLog("Available app profiles: \(store.apps.map { "\($0.name) (\($0.bundleIdentifier))" })")
        
        // Try exact bundle ID match first
        if let app = store.apps.first(where: { $0.bundleIdentifier == bundleId }) {
            NSLog("Found app profile by bundle ID: \(app.name)")
            return app
        }
        
        // Try name-based matching as fallback (case-insensitive)
        if let app = store.apps.first(where: { $0.name.lowercased() == appName.lowercased() }) {
            NSLog("Found app profile by name: \(app.name)")
            return app
        }
        
        // Try partial name matching for apps like "Figma" vs "Figma.app"
        if let app = store.apps.first(where: { 
            appName.lowercased().contains($0.name.lowercased()) || 
            $0.name.lowercased().contains(appName.lowercased())
        }) {
            NSLog("Found app profile by partial name match: \(app.name)")
            return app
        }
        
        NSLog("No app profile found for current app")
        return nil
    }

    private func ensureOverlay() {
        let profile = currentAppProfile()
        let slices: [PieSlice]
        if let profile {
            NSLog("Creating overlay for profile: \(profile.name)")
            NSLog("Profile has \(profile.availableCommands.count) available commands")
            NSLog("Profile pie slots: \(profile.pieSlots)")
            
            // Only create slices for slots that have commands assigned
            let assignedSlots = profile.pieSlots.keys.sorted()
            if assignedSlots.isEmpty {
                NSLog("No commands assigned to pie slots")
                slices = []
            } else {
                slices = assignedSlots.map { idx in
                    if let actId = profile.pieSlots[idx], let cmd = profile.availableCommands.first(where: { $0.actionId == actId }) {
                        let symbol = (cmd.icon?.kind == .sfSymbol) ? cmd.icon?.name : nil
                        let nsImage = (cmd.icon?.kind == .custom) ? store.image(for: cmd.icon) : nil
                        NSLog("Slot \(idx): \(cmd.label) (actionId: \(actId), icon: \(cmd.icon?.name ?? "nil"), kind: \(cmd.icon?.kind.rawValue ?? "nil"), nsImage: \(nsImage != nil ? "loaded" : "nil"))")
                        return PieSlice(index: idx, label: cmd.label, iconName: symbol, keystrokeDisplay: cmd.keystrokeDisplay, nsImage: nsImage)
                    } else {
                        NSLog("Slot \(idx): empty (no actionId or command)")
                        return PieSlice(index: idx, label: "")
                    }
                }
            }
        } else {
            NSLog("No profile found, creating empty overlay")
            slices = []
        }
        overlay = PieOverlayController(slices: slices, onSelect: { [weak self] index in
            self?.handleSelection(index: index)
            self?.overlay?.hide()
            self?.overlay = nil
        }, onHoverChanged: { [weak self] idx in
            self?.currentHoveredIndex = idx
        })
    }

    private func handleSelection(index: Int) {
        guard let profile = currentAppProfile() else {
            NSSound.beep()
            return
        }
        
        guard let actionId = profile.pieSlots[index], let cmd = profile.availableCommands.first(where: { $0.actionId == actionId }) else {
            NSSound.beep()
            return
        }
        let bundleId = profile.bundleIdentifier
        ActionEngine.shared.execute(action: cmd.definition, forAppBundleId: bundleId)
    }

    private func showPie() {
        NSLog("showPie() called")
        if overlay?.window?.isVisible == true { 
            NSLog("Overlay already visible, returning")
            return 
        }
        ensureOverlay()
        NSLog("Overlay created, showing centered at mouse")
        overlay?.showCenteredAtMouse()
    }

    private func selectAndHideIfAny() {
        let index = currentHoveredIndex
        overlay?.hide()
        overlay = nil
        currentHoveredIndex = nil
        if let index { 
            handleSelection(index: index) 
        }
    }

    // Retain toggle for status-bar menu action
    func togglePie() {
        if overlay?.window?.isVisible == true {
            selectAndHideIfAny()
        } else {
            showPie()
        }
    }

    func openPreferences() {
        prefsWindow.show()
    }
} 