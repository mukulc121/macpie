import Foundation
import AppKit

struct MenuCommand: Identifiable, Hashable {
    let id = UUID()
    let path: [String] // e.g., ["Edit", "Paste"]
}

enum MenuIntrospection {
    static func listMenuCommands(appName: String) -> [MenuCommand] {
        // This AppleScript walks the menu bar hierarchy two levels deep for speed; extend as needed
        let script = """
        tell application "System Events"
            if not (exists process "\(appName)") then return ""
            set menuItems to {}
            tell process "\(appName)"
                repeat with mBarItem in menu bar items of menu bar 1
                    set topName to name of mBarItem
                    try
                        repeat with mi in menu items of menu 1 of mBarItem
                            set end of menuItems to (topName & "::" & name of mi)
                        end repeat
                    end try
                end repeat
            end tell
        end tell
        return menuItems as string
        """
        var err: NSDictionary?
        guard let asObj = NSAppleScript(source: script) else { return [] }
        let out = asObj.executeAndReturnError(&err)
        if err != nil { return [] }
        let raw = out.stringValue ?? ""
        let parts = raw.split(separator: ",")
        let commands: [MenuCommand] = parts.compactMap { line in
            let components = line.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "::").map(String.init)
            guard components.count == 2 else { return nil }
            return MenuCommand(path: [components[0], components[1]])
        }
        return commands
    }
} 