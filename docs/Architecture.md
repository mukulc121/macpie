# MacPie — Architecture

This document describes the local-only architecture for a macOS app that renders a context-aware pie menu and executes actions in the frontmost application.

## High‑Level Overview
- No network/backend required. All logic runs on-device.
- Core subsystems:
  1. Context Service (frontmost app, focus, selection metadata)
  2. Input/Hotkey Manager (global hotkey, event tap)
  3. Pie Overlay UI (SwiftUI, rendering/layout)
  4. Action Engine (dispatches keystrokes, menu commands, AppleScript, shell, Shortcuts)
  5. Configuration Store (JSON files, validation, reload)
  6. Permissions Manager (Accessibility, Automation prompts)
  7. Logging & Analytics (local logs only; optional)

```
[User Hotkey] → [Hotkey Manager] → [Context Service] → [Config Store]
                                    ↓
                              [Pie Overlay]
                                    ↓ selection
                              [Action Engine] → [Target App]
```

## Components

### 1) Context Service
- Monitors `NSWorkspace.shared.frontmostApplication` and its bundle identifier
- Optionally reads focused UI element via Accessibility APIs (AXUIElement) for richer context later
- Emits Combine publishers for app changes used to swap configurations at runtime

### 2) Input/Hotkey Manager
- Registers a global hotkey
  - Initial implementation: `CGEventTapCreate` to listen for key down/up; combine with a lightweight state machine to implement hold-to-open vs tap-to-toggle
  - Alternative: Carbon `RegisterEventHotKey` for classic global hotkey behavior
- Tracks mouse position to center the pie at the cursor
- Interprets radial selection via mouse angle or numeric keys

### 3) Pie Overlay UI
- SwiftUI rendering hosted in an always-on-top borderless `NSPanel`
  - `level = .screenSaver` or `.statusBar` depending on needs
  - `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`
- Input routing: while overlay is visible, consume mouse/keyboard events needed for selection; Esc cancels
- Accessibility: mark overlay as an accessibility element only if needed (prefer to be transparent to assistive tech)
- Animations for open/close and segment highlight; adaptable themes

### 4) Action Engine
- Dispatch layer with adapters per action type:
  - KeystrokeAdapter: posts key events via `CGEventCreateKeyboardEvent`
  - MenuItemAdapter: selects a menu item by path using Apple Events (AppleScript/JXA under the hood)
  - AppleScriptAdapter: executes provided AppleScript via `OSAScript`/`NSAppleScript`
  - ShellAdapter: runs `Process` with `/bin/zsh`, configurable environment and working directory
  - ShortcutsAdapter: runs Shortcuts via `shortcuts` CLI or `x-apple-shortcuts://` URL
- Common execution contract:
  - Timeout, success/failure result, stderr/stdout capture where applicable
  - Cancellation support if the overlay is dismissed mid‑execution (best effort)
- Safety: blocks or warns on potentially destructive shell commands unless explicitly allowed

### 5) Configuration Store
- Location: `~/Library/Application Support/MacPie/config/apps/`
- Files: JSON per app; `default.json` for fallback
- Loader validates schema and builds an in‑memory model:
  - `AppConfiguration` (app info, hotkey behavior, pie layout, actions)
  - `ActionDescriptor` (id, label, type, payload)
- File watcher (FSEvents) to support live reload
- Future: UI editor with schema validation and presets

### 6) Permissions Manager
- Accessibility: checks `AXIsProcessTrustedWithOptions` and prompts if not granted
- Automation (Apple Events): handles first‑time prompts when controlling specific apps; presents guidance when denied
- Shortcuts: validates Shortcuts availability and CLI presence

### 7) Logging & Diagnostics
- Unified logger built on `os.Logger` with categories (hotkey, overlay, action, config)
- Optional on‑disk rotating file log in `~/Library/Logs/MacPie/`

## Data Model (Swift)
- `struct AppConfiguration` — name, `bundleIdentifiers: [String]`, `hotkey`, `pie`, `actions: [ActionDescriptor]`
- `struct Hotkey` — key, modifiers, behavior
- `struct PieLayout` — segments, center action id, rings/pages
- `struct PieItemRef` — slot, actionId
- `enum ActionType` — keystroke, menuItem, appleScript, shell, shortcut
- `struct ActionDescriptor` — id, label, type, payload (associated values)
- `struct Keystroke` — key, modifiers

## Key Flows

### Show Pie and Execute
1. Hotkey down detected by Hotkey Manager
2. Context Service reads frontmost app bundle id
3. Config Store selects matching `AppConfiguration` (fallback to default)
4. Pie Overlay renders per config
5. User selects a segment (mouse direction or number key)
6. Overlay closes; Action Engine executes mapped action with a short debounce to avoid input conflicts
7. Report success/failure via subtle HUD/toast

### Menu Item Selection (Apple Events)
1. Resolve app process name from bundle id
2. Build AppleScript to click a menu item by path (e.g., ["Edit", "Paste"])
3. Execute via AppleScriptAdapter
4. If first-time, macOS prompts for Automation permission; user must allow

## Frameworks and APIs
- SwiftUI + AppKit (UI, windowing)
- Combine (state propagation)
- ApplicationServices (CGEvent for input synthesis)
- Accessibility (AX) for checking trust, optionally reading focused element
- Scripting components:
  - `OSAKit` / `NSAppleScript` for AppleScript execution
  - `Process` for shell and Shortcuts CLI
- File System Events (FSEvents) for live config reload

## Entitlements & Permissions
- Accessibility permission: requested at runtime (no entitlement)
- If sandboxed:
  - `com.apple.security.app-sandbox` = true
  - `com.apple.security.automation.apple-events` = true (to send Apple Events/AppleScript)
  - Consider user‑selected file access if you allow arbitrary script locations
- Many utilities ship unsandboxed to reduce friction with Accessibility/Automation; decide based on distribution strategy

## Performance and Responsiveness
- Keep overlay render inexpensive (vector shapes, shared gradients)
- Pre-warm AppleScript engine to reduce first-use latency
- Debounce hotkey vs app menus to avoid accidental native menu triggers
- Run action execution on background queues; keep main thread for UI

## Error Handling
- Surface actionable messages (e.g., "Menu item not found: Edit > Paste")
- Fallback to keystroke if a menu click fails (optional, configurable)
- Structured error types per adapter; include app bundle id and action id in logs

## Extensibility
- Rings/pages: multiple radial rings for sub‑menus
- Context filters: enable actions only when selection type matches (future — requires per‑app adapters or heuristics)
- Plugin actions:
  - Script plugins: executable files in `~/Library/Application Support/MacPie/plugins/` with JSON manifest
  - Environment variables: `MACPIE_FRONTMOST_BUNDLE_ID`, `MACPIE_SELECTION_HINT`
  - Return protocol: exit code 0 success; stdout for user message
- Optional sync: iCloud Drive or CloudKit for configurations

## Security Considerations
- Clearly communicate capabilities (Accessibility, Automation)
- Sign and notarize the app for distribution
- Validate configs to prevent command injection; require explicit opt-in for shell actions
- Respect per‑app Automation permissions; never attempt to bypass TCC

## Testing Strategy
- Unit tests for config parser/validator and action dispatch routing
- UI tests to verify overlay rendering and selection hit testing
- Integration tests on a test host app for keystroke/menu actions

## Minimal Technical Plan
1. Implement Hotkey Manager (event tap) and Overlay UI (SwiftUI in borderless panel)
2. Implement Config Store (load default and one app example)
3. Implement Keystroke and AppleScript adapters
4. Wire selection → action execution
5. Add status bar menu with Preferences and Reload Config
6. Add basic error heads-up messages and logging

## Nice-to-Haves
- Visual pie editor and per‑app presets
- Keyboard‑only navigation and Vim-style hints
- Multi-display support with smart placement
- Haptics via supported input devices (if available) 