import Foundation
import AppKit
import ApplicationServices
import Carbon

enum ActionType: String, Codable {
    case keystroke
    case menuItem
}

struct KeystrokeAction: Codable {
    let keyCode: UInt32
    let modifiers: UInt32 // Carbon mask (cmdKey, shiftKey, etc.)
}

struct MenuItemAction: Codable {
    let menuPath: [String]
}

struct ActionDefinition: Codable {
    let type: ActionType
    let keystroke: KeystrokeAction?
    let menuItem: MenuItemAction?
}

final class ActionEngine {
    static let shared = ActionEngine()

    func execute(action: ActionDefinition, forAppBundleId bundleId: String) {
        // Ensure we have Accessibility permission for synthetic input
        guard PermissionsManager.shared.ensureAccessibilityPermission(prompt: true) else { return }
        switch action.type {
        case .keystroke:
            guard let ks = action.keystroke else { return }
            postKeystroke(keyCode: ks.keyCode, modifiers: ks.modifiers)
        case .menuItem:
            guard let mi = action.menuItem else { return }
            selectMenuItem(path: mi.menuPath, bundleId: bundleId)
        }
    }

    private func postKeystroke(keyCode: UInt32, modifiers: UInt32) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let flags = cgFlags(fromCarbon: modifiers)
        if let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: true) {
            down.flags = flags
            down.post(tap: .cghidEventTap)
        }
        if let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: false) {
            up.flags = flags
            up.post(tap: .cghidEventTap)
        }
    }

    private func cgFlags(fromCarbon mask: UInt32) -> CGEventFlags {
        var flags: CGEventFlags = []
        if (mask & UInt32(cmdKey)) != 0 { flags.insert(.maskCommand) }
        if (mask & UInt32(shiftKey)) != 0 { flags.insert(.maskShift) }
        if (mask & UInt32(optionKey)) != 0 { flags.insert(.maskAlternate) }
        if (mask & UInt32(controlKey)) != 0 { flags.insert(.maskControl) }
        return flags
    }

    private func selectMenuItem(path: [String], bundleId: String) {
        guard let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first,
              let appName = running.localizedName else { return }
        // Path script for debugging (commented out to avoid unused variable warning)
        // let pathScript = path.map { "\"\($0)\"" }.joined(separator: ", ")
        // Validate path has at least 2 elements
        guard path.count >= 2 else {
            NSLog("Menu selection failed: invalid path length %d", path.count)
            return
        }
        
        let script = """
        tell application "System Events"
            tell process "\(appName)"
                click menu item \(path.last!.debugDescription) of menu 1 of menu bar item \(path.first!.debugDescription) of menu bar 1
            end tell
        end tell
        """
        // More robust path-walk omitted for brevity; above assumes two-level path
        var error: NSDictionary?
        let asObj = NSAppleScript(source: script)
        _ = asObj?.executeAndReturnError(&error)
        if error != nil {
            NSLog("Menu selection failed for path: %@", path.joined(separator: " > "))
        }
    }
} 