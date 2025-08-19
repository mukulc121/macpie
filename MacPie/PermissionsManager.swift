import Foundation
import AppKit
import ApplicationServices

final class PermissionsManager {
    static let shared = PermissionsManager()

    @discardableResult
    func ensureAccessibilityPermission(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: prompt] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted && prompt {
            openAccessibilityPreferences()
        }
        return trusted
    }

    func openAccessibilityPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}


