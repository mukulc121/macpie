# MacPie — Contextual Pie Menu for macOS

## What it does
MacPie shows a radial "pie" menu when you press a global hotkey. The menu is context-aware: it loads actions based on the currently active app (e.g., Figma, Xcode, Safari). Each pie segment triggers an action such as a keystroke, selecting a menu item, running AppleScript, running a shell command, or invoking a Shortcut.

- The app runs locally—no server required
- Works across apps by sending permitted keystrokes or Apple Events, or by running scripts
- Users define per‑app configurations in simple JSON files

## Requirements
- macOS 13 Ventura or later (recommended: macOS 14+)
- Xcode 15+ to build from source
- Permissions (requested on first run):
  - Accessibility (to post synthetic keystrokes, read focused element)
  - Automation/Apple Events (to select menu items or control apps via AppleScript)

Optional
- Shortcuts app installed to run system Shortcuts

## Install / Build
1. Open `MacPie.xcodeproj` in Xcode.
2. Set a unique bundle identifier if needed (Targets → MacPie → General).
3. Build and run. On first launch, grant Accessibility and Automation permissions when prompted:
   - System Settings → Privacy & Security → Accessibility: enable MacPie
   - System Settings → Privacy & Security → Automation: allow MacPie to control target apps when macOS prompts

## Usage
- Press the global hotkey (default proposal: Control+Space, editable later) to show the pie overlay centered at the mouse cursor.
- Move the mouse in the direction of the desired segment or press number keys 1–8 to select.
- Release the hotkey or click to execute the selected action.
- Press Esc to cancel.

## Configuration
Configurations are per‑app and live in the app support folder:

- Path: `~/Library/Application Support/MacPie/config/apps/`
- File naming: one JSON file per target app, recommended name is the app's bundle identifier, e.g. `com.figma.Desktop.json`
- A `default.json` file provides fallback actions for apps without a dedicated file

### Schema (high‑level)
```json
{
  "app": {
    "name": "Figma",
    "bundleIdentifiers": ["com.figma.Desktop"]
  },
  "hotkey": {
    "key": "space",
    "modifiers": ["control"],
    "behavior": "hold-to-open" // or "tap-to-toggle"
  },
  "pie": {
    "segments": 8,
    "centerActionId": "",
    "rings": [
      {
        "id": "main",
        "items": [
          { "slot": 0, "actionId": "copy" },
          { "slot": 1, "actionId": "paste" },
          { "slot": 2, "actionId": "pasteReplace" },
          { "slot": 3, "actionId": "createComponent" },
          { "slot": 4, "actionId": "group" },
          { "slot": 5, "actionId": "ungroup" },
          { "slot": 6, "actionId": "rename" },
          { "slot": 7, "actionId": "quickActions" }
        ]
      }
    ]
  },
  "actions": [
    {
      "id": "copy",
      "label": "Copy",
      "type": "keystroke",
      "keystroke": { "key": "c", "modifiers": ["command"] }
    },
    {
      "id": "paste",
      "label": "Paste",
      "type": "menu_item",
      "menuPath": ["Edit", "Paste"]
    },
    {
      "id": "pasteReplace",
      "label": "Paste to Replace",
      "type": "menu_item",
      "menuPath": ["Edit", "Paste to Replace"]
    },
    {
      "id": "createComponent",
      "label": "Create Component",
      "type": "keystroke",
      "keystroke": { "key": "k", "modifiers": ["option", "command"] }
    },
    {
      "id": "group",
      "label": "Group",
      "type": "keystroke",
      "keystroke": { "key": "g", "modifiers": ["command"] }
    },
    {
      "id": "ungroup",
      "label": "Ungroup",
      "type": "keystroke",
      "keystroke": { "key": "g", "modifiers": ["shift", "command"] }
    },
    {
      "id": "rename",
      "label": "Rename",
      "type": "keystroke",
      "keystroke": { "key": "r", "modifiers": ["command"] }
    },
    {
      "id": "quickActions",
      "label": "Quick Actions",
      "type": "applescript",
      "script": "tell application \"System Events\" to keystroke 'p' using {command down, shift down}"
    }
  ]
}
```

Notes
- `type: "keystroke"` posts synthetic key events via the Accessibility API.
- `type: "menu_item"` selects a menu item by path using Apple Events (AppleScript under the hood). macOS may prompt you to allow MacPie to control that app.
- `type: "applescript"` runs AppleScript directly.
- `type: "shell"` runs a shell command via `/bin/zsh` (PATH is inherited from the app; you can override via `env`).
- `type: "shortcut"` runs a macOS Shortcut by name.

### Minimal default config example (`default.json`)
```json
{
  "app": { "name": "Default", "bundleIdentifiers": ["*"] },
  "pie": { "segments": 6, "rings": [ { "id": "main", "items": [] } ] },
  "actions": [
    { "id": "copy", "label": "Copy", "type": "keystroke", "keystroke": { "key": "c", "modifiers": ["command"] } },
    { "id": "paste", "label": "Paste", "type": "keystroke", "keystroke": { "key": "v", "modifiers": ["command"] } }
  ]
}
```

### App bundle identifiers
Locate an app's bundle identifier:
- Run: `osascript -e 'id of app "Figma"'`
- Or inspect the app's `Info.plist`

### Creating/Editing configs from the UI
- MacPie will include a simple editor (Preferences → Configurations) to edit JSON with validation
- Until the editor ships, edit files in `~/Library/Application Support/MacPie/config/apps/` and relaunch (or use Reload in the status bar)

## Advanced Actions
- AppleScript: Useful for non‑shortcuttable menu items or scripted flows. Example to click a menu item:
```applescript
tell application "System Events"
  tell process "Figma"
    click menu item "Paste to Replace" of menu 1 of menu bar item "Edit" of menu bar 1
  end tell
end tell
```
- Shell: Example
```sh
open -a "Figma" --args --disable-gpu
```
- Shortcut: Example
```json
{ "id": "export", "label": "Export", "type": "shortcut", "shortcutName": "Export Selected" }
```

## UI/Behavior Options
- Pie size, label font size, theme (light/dark/system)
- Segment count (4–12), angle snap strength, center action
- Hotkey behavior: hold-to-open vs tap-to-toggle, repeat-on-hold
- Sound/haptic feedback (if supported)

## Troubleshooting
- Pie doesn’t show: ensure the hotkey isn’t occupied by another app
- Actions don’t run: check Accessibility and Automation permissions
- Menu item not found: verify `menuPath` matches exactly and the item is enabled in the target app
- Apple Events denied: open System Settings → Privacy & Security → Automation and enable control for the target app

## Roadmap (suggested)
- Built‑in config editor with per‑app presets (Figma, Sketch, Photoshop, Xcode)
- Sub‑menus (multiple rings) and contextual pages (based on selection/type)
- Import/export and optional iCloud Drive sync
- Plugin SDK for custom Swift or script actions
- Multi‑monitor placement options and keyboard‑only navigation 