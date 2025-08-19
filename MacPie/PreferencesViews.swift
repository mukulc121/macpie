import SwiftUI
import Carbon
import UniformTypeIdentifiers
import AppKit

private struct InfoRow: View {
    let title: String
    let value: String
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
        }
    }
}

struct GeneralPreferencesView: View {
    weak var coordinator: AppCoordinator?
    @EnvironmentObject private var store: ConfigurationStore

    @State private var showHotkeyCapture: Bool = false
    @State private var capturing: Bool = false
    @State private var capturedKeyCode: UInt32? = nil
    @State private var capturedModifiers: UInt32 = 0
    @State private var launchAtLogin: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // App header with icon
            HStack(spacing: 16) {
                if let appIcon = NSApplication.shared.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)
                        .cornerRadius(12)
                        .shadow(radius: 2)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.blue.gradient)
                        .frame(width: 64, height: 64)
                        .overlay(
                            Image(systemName: "circle.grid.3x3")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(.white)
                        )
                        .shadow(radius: 2)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("MacPie")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                    Text("Customizable Pie Menu for macOS")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    HStack(spacing: 8) {
                        Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text("•")
                            .foregroundColor(.secondary)
                        Text("Build \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            Divider()
            
            // Settings
            VStack(alignment: .leading, spacing: 16) {
                // Hotkey Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Global Hotkey")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Button(action: { capturedKeyCode = nil; capturedModifiers = 0; capturing = true; showHotkeyCapture = true }) {
                        HStack {
                            Image(systemName: "command")
                                .foregroundColor(.accentColor)
                                .font(.system(size: 16, weight: .medium))
                            Text(hotkeyDisplay)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "pencil")
                                .foregroundColor(.secondary)
                                .font(.system(size: 14))
                        }
                        .padding(12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.quaternary, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Text("Press this key combination to show the pie menu")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                // Startup Section  
                VStack(alignment: .leading, spacing: 8) {
                    Text("Startup")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    HStack {
                        Image(systemName: "power")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 16, weight: .medium))
                        Toggle("Start MacPie at login", isOn: $launchAtLogin)
                            .onChange(of: launchAtLogin) { _ in
                                store.general.launchAtLogin = launchAtLogin
                                store.save()
                                coordinator?.updateHotkey(keyCode: store.general.hotkeyKeyCode, modifiers: store.general.hotkeyModifiers)
                            }
                            .toggleStyle(.switch)
                    }
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .onAppear { loadDefaultsFromStore() }
        .sheet(isPresented: $showHotkeyCapture) { HotkeyCaptureSheet }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func loadDefaultsFromStore() {
        launchAtLogin = store.general.launchAtLogin
    }

    private var hotkeyDisplay: String {
        let mods = store.general.hotkeyModifiers
        let parts = [
            (mods & UInt32(cmdKey)) != 0 ? "⌘" : nil,
            (mods & UInt32(shiftKey)) != 0 ? "⇧" : nil,
            (mods & UInt32(optionKey)) != 0 ? "⌥" : nil,
            (mods & UInt32(controlKey)) != 0 ? "⌃" : nil,
            keyToLabel(store.general.hotkeyKeyCode)
        ].compactMap { $0 }
        return parts.joined()
    }

    private var HotkeyCaptureSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Record Hotkey").font(.title3).fontWeight(.semibold)
            KeystrokeField(display: captureDisplay, isCapturing: $capturing) { keyCode, mods in
                capturedKeyCode = keyCode
                capturedModifiers = mods
            }
            HStack {
                Spacer()
                Button("Cancel") { showHotkeyCapture = false }
                Button("Save") {
                    guard let key = capturedKeyCode else { return }
                    coordinator?.updateHotkey(keyCode: key, modifiers: capturedModifiers)
                    showHotkeyCapture = false
                }
                .keyboardShortcut(.return)
            }
        }
        .padding(16)
        .frame(width: 420)
    }

    private var captureDisplay: String {
        guard let key = capturedKeyCode else { return capturing ? "Recording…" : "Click to record" }
        let parts = [
            (capturedModifiers & UInt32(cmdKey)) != 0 ? "⌘" : nil,
            (capturedModifiers & UInt32(shiftKey)) != 0 ? "⇧" : nil,
            (capturedModifiers & UInt32(optionKey)) != 0 ? "⌥" : nil,
            (capturedModifiers & UInt32(controlKey)) != 0 ? "⌃" : nil,
            keyToLabel(key)
        ].compactMap { $0 }
        return parts.joined()
    }

    private func keyToLabel(_ keyCode: UInt32) -> String {
        switch keyCode {
        case UInt32(kVK_ANSI_A): return "A"; case UInt32(kVK_ANSI_B): return "B"; case UInt32(kVK_ANSI_C): return "C";
        case UInt32(kVK_ANSI_D): return "D"; case UInt32(kVK_ANSI_E): return "E"; case UInt32(kVK_ANSI_F): return "F";
        case UInt32(kVK_ANSI_G): return "G"; case UInt32(kVK_ANSI_H): return "H"; case UInt32(kVK_ANSI_I): return "I";
        case UInt32(kVK_ANSI_J): return "J"; case UInt32(kVK_ANSI_K): return "K"; case UInt32(kVK_ANSI_L): return "L";
        case UInt32(kVK_ANSI_M): return "M"; case UInt32(kVK_ANSI_N): return "N"; case UInt32(kVK_ANSI_O): return "O";
        case UInt32(kVK_ANSI_P): return "P"; case UInt32(kVK_ANSI_Q): return "Q"; case UInt32(kVK_ANSI_R): return "R";
        case UInt32(kVK_ANSI_S): return "S"; case UInt32(kVK_ANSI_T): return "T"; case UInt32(kVK_ANSI_U): return "U";
        case UInt32(kVK_ANSI_V): return "V"; case UInt32(kVK_ANSI_W): return "W"; case UInt32(kVK_ANSI_X): return "X";
        case UInt32(kVK_ANSI_Y): return "Y"; case UInt32(kVK_ANSI_Z): return "Z";
        default: return "#\(keyCode)"
        }
    }
}

struct ConfigurationsPreferencesView: View {
    @ObservedObject var store: ConfigurationStore
    @State private var selectedApp: AppProfile?
    @State private var discovering = false
    @State private var search = ""
    @State private var softwareSearch = ""
    @State private var showAddCommand = false
    @State private var pendingAppIdForNewCommand: String?

    private var filteredApps: [AppProfile] {
        if softwareSearch.isEmpty {
            return store.apps
        } else {
            return store.apps.filter { app in
                app.name.localizedCaseInsensitiveContains(softwareSearch) ||
                app.bundleIdentifier.localizedCaseInsensitiveContains(softwareSearch)
            }
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            Sidebar
            Divider()
            Content
        }
        .onChange(of: selectedApp?.id) { _ in
            autoPopulateIfNeeded()
        }
        .onAppear { if selectedApp == nil { selectedApp = store.apps.first; autoPopulateIfNeeded() } }
        .sheet(isPresented: $showAddCommand) {
            if let appId = pendingAppIdForNewCommand {
                AddCommandSheet(onSave: { newCmd in
                    addCommand(newCmd, to: appId)
                    showAddCommand = false
                }, store: store)
            } else {
                AddCommandSheet(onSave: { _ in showAddCommand = false }, store: store)
            }
        }
    }

    private var Sidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Softwares").font(.headline)
                Spacer()
                Button(action: addSoftware) { Image(systemName: "plus") }.help("Add")
                Button(action: discoverSoftwares) { Image(systemName: "magnifyingglass") }.help("Discover apps")
                    .disabled(discovering)
            }
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search software...", text: $softwareSearch)
                    .textFieldStyle(.plain)
                if !softwareSearch.isEmpty {
                    Button(action: { softwareSearch = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.regularMaterial))
            
            List(selection: Binding(get: { selectedApp?.id }, set: { id in
                if let id, let found = filteredApps.first(where: { $0.id == id }) { selectedApp = found }
            })) {
                ForEach(filteredApps) { app in
                    HStack(spacing: 8) {
                        Image(nsImage: AppIconProvider.icon(for: app.bundleIdentifier, size: 18))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 18, height: 18)
                            .cornerRadius(4)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.name).font(.body)
                            Text(app.bundleIdentifier).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .tag(app.id)
                }
            }
            .listStyle(.inset)
        }
        .padding(12)
        .frame(width: 300)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.regularMaterial))
    }

    private var Content: some View {
        Group {
            if var app = selectedApp ?? store.apps.first {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(app.name).font(.title3).fontWeight(.semibold)
                            Text(app.bundleIdentifier).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Auto‑fill Pie") { autofillPie(for: app) }
                    }
                    HStack(alignment: .top, spacing: 16) {
                        PieCanvas(app: Binding(get: { app }, set: { _ in }), slots: Array(0..<8), onSave: { save(app) }, store: store)
                            .frame(width: 320, height: 320)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.regularMaterial))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.gray.opacity(0.2)))
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Commands").font(.headline)
                                Spacer()
                                TextField("Search", text: $search)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 220)
                                Button("Add command") { pendingAppIdForNewCommand = app.id; showAddCommand = true }
                            }
                            CommandsList(app: Binding(get: { app }, set: { _ in }), store: store, onSave: { save(app) }, search: search)
                                .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.regularMaterial))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.gray.opacity(0.2)))
                        }
                    }
                }
                .padding(12)
            } else {
                Text("Select or add a software to configure its pie").foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func addSoftware() {
        let new = AppProfile(name: "New App", bundleIdentifier: "com.example.app", availableCommands: [], pieSlots: [:])
        store.apps.append(new)
        selectedApp = new
        store.save()
    }

    private func autoPopulateIfNeeded() {
        guard var app = selectedApp else { return }
        // No automatic command discovery
        // Auto-fill pie if no mapping
        if app.pieSlots.isEmpty {
            for i in 0..<min(8, app.availableCommands.count) {
                app.pieSlots[i] = app.availableCommands[i].actionId
            }
        }
        if let idx = store.apps.firstIndex(where: { $0.id == app.id }) {
            store.apps[idx] = app
            store.save()
            selectedApp = app
        }
    }

    private func discoverSoftwares() {
        discovering = true
        DispatchQueue.global(qos: .userInitiated).async {
            let discovered = AppDiscovery.findInstalledApps()
            var newApps: [AppProfile] = []
            for app in discovered {
                if store.apps.contains(where: { $0.bundleIdentifier == app.bundleIdentifier }) { continue }
                var profile = AppProfile(name: app.name, bundleIdentifier: app.bundleIdentifier, availableCommands: [], pieSlots: [:])
                // Do not auto-populate commands or slots
                newApps.append(profile)
            }
            DispatchQueue.main.async {
                store.apps.append(contentsOf: newApps)
                store.save()
                discovering = false
                if selectedApp == nil { selectedApp = store.apps.first }
            }
        }
    }

    private func autofillPie(for app: AppProfile) {
        var updated = app
        updated.pieSlots = [:]
        for i in 0..<min(8, updated.availableCommands.count) { updated.pieSlots[i] = updated.availableCommands[i].actionId }
        save(updated)
    }

    private func save(_ app: AppProfile) {
        if let idx = store.apps.firstIndex(where: { $0.id == app.id }) {
            store.apps[idx] = app
            store.save()
            selectedApp = app
        }
    }

    private func addCommand(_ cmd: PieCommand, to appId: String) {
        guard let idx = store.apps.firstIndex(where: { $0.id == appId }) else { return }
        var app = store.apps[idx]
        app.availableCommands.append(cmd)
        store.apps[idx] = app
        store.save()
        selectedApp = app
    }
}

struct PieEditor: View {
    @State var app: AppProfile
    @ObservedObject var store: ConfigurationStore

    private let slots = Array(0..<8)

    var body: some View {
        VStack(alignment: .leading) {
            Text(app.name).font(.title2)
            HStack(alignment: .top, spacing: 24) {
                PieCanvas(app: $app, slots: slots, onSave: save, store: store)
                CommandsList(app: $app, store: store, onSave: save, search: "")
                    .frame(width: 300)
            }
        }
        .padding()
    }

    private func save() {
        if let idx = store.apps.firstIndex(where: { $0.id == app.id }) {
            store.apps[idx] = app
            store.save()
        }
    }
}

private struct PieCanvas: View {
    @Binding var app: AppProfile
    let slots: [Int]
    let onSave: () -> Void
    @ObservedObject var store: ConfigurationStore

    var body: some View {
        ZStack {
            ForEach(slots, id: \.self) { slot in
                let actionId = app.pieSlots[slot]
                let command = actionId.flatMap { id in app.availableCommands.first(where: { $0.actionId == id }) }
                let label = command?.label ?? ""
                let icon = command?.icon
                PieSlotView(
                    slot: slot, 
                    slotsCount: slots.count, 
                    label: label,
                    actionId: actionId,
                    commandIcon: icon,
                    store: store,
                    onDropActionId: { droppedId in
                        NSLog("onDropActionId called with: \(droppedId) for slot: \(slot)")
                        app.pieSlots[slot] = droppedId
                        onSave()
                    },
                    onDeleteActionId: {
                        NSLog("onDeleteActionId called for slot: \(slot)")
                        app.pieSlots[slot] = nil
                        onSave()
                    }
                )
            }
        }
    }
}

private struct PieSlotView: View {
    let slot: Int
    let slotsCount: Int
    let label: String
    let actionId: String?
    let commandIcon: CommandIcon?
    let store: ConfigurationStore
    let onDropActionId: (String) -> Void
    let onDeleteActionId: () -> Void
    
    @State private var isHovered = false

    var body: some View {
        let anglePer = 360.0 / Double(slotsCount)
        let start = Angle(degrees: Double(slot) * anglePer - anglePer / 2)
        let end = Angle(degrees: Double(slot + 1) * anglePer - anglePer / 2)

        return ZStack {
            // Background pie slice with hover detection - this needs to be the base layer
            PieShape(startAngle: start, endAngle: end)
                .fill(LinearGradient(
                    colors: isHovered ? 
                        [Color.accentColor.opacity(0.3), Color.accentColor.opacity(0.2)] :
                        [Color.gray.opacity(0.1), Color.gray.opacity(0.05)], 
                    startPoint: .top, 
                    endPoint: .bottom
                ))
                .overlay(PieShape(startAngle: start, endAngle: end).stroke(
                    isHovered ? Color.accentColor.opacity(0.6) : Color.gray.opacity(0.3), 
                    lineWidth: isHovered ? 2 : 1
                ))
                .contentShape(PieShape(startAngle: start, endAngle: end))
                .onHover { hovering in
                    NSLog("Hover state changed for slot \(slot): \(hovering)")
                    DispatchQueue.main.async {
                        isHovered = hovering
                    }
                }
                .zIndex(Double(slot)) // Give each slice a unique z-index to prevent overlap issues
                
                .onTapGesture {
                    // Click to delete if command is assigned
                    if actionId != nil {
                        NSLog("Tap gesture triggered for slot \(slot)")
                        onDeleteActionId()
                    }
                }
                .contextMenu {
                    if actionId != nil {
                        Button(action: {
                            NSLog("Context menu delete triggered for slot \(slot)")
                            onDeleteActionId()
                        }) {
                            Label("Delete Command", systemImage: "trash")
                        }
                    } else {
                        Text("No command assigned")
                            .foregroundStyle(.secondary)
                    }
                }
                .onDrop(of: [UTType.utf8PlainText], isTargeted: Binding(
                    get: { isHovered },
                    set: { _ in }
                )) { providers in
                    NSLog("Drop received in slot \(slot), providers: \(providers.count)")
                    guard let provider = providers.first else { 
                        NSLog("No provider found")
                        return false 
                    }
                    
                    // Try to load as data first (more reliable)
                    provider.loadDataRepresentation(forTypeIdentifier: UTType.utf8PlainText.identifier) { data, error in
                        if let data = data, let actionId = String(data: data, encoding: .utf8) {
                            NSLog("Drop data loaded: \(actionId)")
                            DispatchQueue.main.async { onDropActionId(actionId) }
                        } else {
                            NSLog("Drop data failed, trying NSString fallback")
                            // Fallback to NSString method
                            _ = provider.loadObject(ofClass: NSString.self) { object, _ in
                                if let ns = object as? NSString {
                                    let id = ns as String
                                    NSLog("Drop NSString loaded: \(id)")
                                    DispatchQueue.main.async { onDropActionId(id) }
                                }
                            }
                        }
                    }
                    return true
                }
                .overlay(
                    // Drop target indicator
                    PieShape(startAngle: start, endAngle: end)
                        .stroke(Color.accentColor.opacity(0.8), lineWidth: 3)
                        .opacity(isHovered ? 1.0 : 0.0)
                        .animation(.easeInOut(duration: 0.15), value: isHovered)
                        .allowsHitTesting(false) // Don't interfere with hover detection
                )

                .zIndex(1) // Ensure background is behind other elements
            
            // Icon or placeholder
            if actionId != nil {
                // Show icon for assigned command - centered in slice
                IconPreview(icon: commandIcon, store: store, size: 28)
                    .rotationEffect(.degrees(Double(slot) * anglePer))
                    .offset(x: 60) // Reduced offset to center better
                    .rotationEffect(.degrees(-Double(slot) * anglePer))
                    .zIndex(Double(slot) + 100) // Above background, below delete button
                    .allowsHitTesting(false) // Don't interfere with hover detection
                
                // Delete button - positioned at the outer edge of the slice
                Button(action: onDeleteActionId) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 16, weight: .bold))
                        .background(Color.white, in: Circle())
                        .shadow(radius: 2)
                }
                .buttonStyle(.borderless)
                .rotationEffect(.degrees(Double(slot) * anglePer))
                .offset(x: 85, y: 0)
                .rotationEffect(.degrees(-Double(slot) * anglePer))
                .opacity(isHovered ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.2), value: isHovered)
                .zIndex(10) // Ensure delete button is on top
                .allowsHitTesting(true) // Allow button interaction
            } else {
                // Show placeholder for empty slot
                Image(systemName: "plus.circle")
                    .foregroundColor(.secondary)
                    .font(.system(size: 20))
                    .rotationEffect(.degrees(Double(slot) * anglePer))
                    .offset(x: 60) // Same offset as icons for consistency
                    .rotationEffect(.degrees(-Double(slot) * anglePer))
                    .zIndex(Double(slot) + 100) // Above background
                    .allowsHitTesting(false) // Don't interfere with hover detection
            }
            
                        // Command name tooltip on hover
            if isHovered && !label.isEmpty {
                VStack(spacing: 2) {
                    Text(label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.primary)

                    if actionId != nil {
                        Text("Right-click to delete")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                .rotationEffect(.degrees(Double(slot) * anglePer))
                .offset(x: 90, y: -40)
                .rotationEffect(.degrees(-Double(slot) * anglePer))
                .transition(.opacity.combined(with: .scale))
                .zIndex(15) // Ensure tooltip is on top
                .allowsHitTesting(false) // Don't interfere with hover detection
            }
        }
    }
}

private struct CommandsList: View {
    @Binding var app: AppProfile
    let store: ConfigurationStore
    let onSave: () -> Void
    var search: String = ""

    @State private var editingCommandId: String? = nil
    @State private var tempName: String = ""
    @State private var tempIcon: CommandIcon? = nil
    @State private var sfSearch: String = ""
    @State private var showingImporter = false
    @State private var showAddCommand = false

    // Minimal curated SF Symbols set; can be expanded
    private let sfSets: [String] = [
        "bolt.fill", "flame.fill", "hare.fill", "tortoise.fill", "scissors", "doc.on.doc",
        "clipboard", "arrow.uturn.left", "arrow.triangle.2.circlepath", "square.stack.3d.up",
        "pencil", "trash", "folder", "tray.and.arrow.down", "tray.and.arrow.up", "magnifyingglass"
    ]

    private var filteredSFSymbols: [String] {
        let q = sfSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return sfSets }
        return sfSets.filter { $0.localizedCaseInsensitiveContains(q) }
    }

    var filtered: [PieCommand] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return app.availableCommands }
        return app.availableCommands.filter { $0.label.localizedCaseInsensitiveContains(q) || $0.actionId.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Commands").font(.headline)
                Spacer()
                Button("Add Command") { showAddCommand = true }
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 4)
            
            List(filtered) { cmd in
                HStack(spacing: 8) {
                    IconPreview(icon: cmd.icon, store: store, size: 16)
                    Text(cmd.label)
                    Spacer()
                    if let ks = cmd.keystrokeDisplay { Text(ks).font(.caption2).padding(.horizontal, 6).padding(.vertical, 2).background(.thinMaterial, in: Capsule()) }
                    Button { beginEdit(cmd) } label: { Image(systemName: "pencil").imageScale(.small) }
                    .buttonStyle(.borderless)
                }
                .contentShape(Rectangle())
                .onDrag {
                    NSLog("Starting drag for command: \(cmd.actionId)")
                    let provider = NSItemProvider()
                    provider.registerDataRepresentation(forTypeIdentifier: UTType.utf8PlainText.identifier, visibility: .all) { completion in
                        let data = cmd.actionId.data(using: .utf8) ?? Data()
                        NSLog("Drag data: \(cmd.actionId) -> \(data.count) bytes")
                        completion(data, nil)
                        return nil
                    }
                    // Also register as NSString for compatibility
                    provider.registerObject(NSString(string: cmd.actionId), visibility: .all)
                    return provider
                }
                .onTapGesture(count: 2) { assignToNextEmptySlot(cmd.actionId) }
            }
            .listStyle(.inset)
            HStack {
                Text("Tip: Drag commands onto the pie, or double‑click to assign next empty slot.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Save") { onSave() }
            }
        }
        .padding(12)
        .sheet(isPresented: Binding(get: { editingCommandId != nil }, set: { if !$0 { editingCommandId = nil } })) {
            EditCommandSheet
        }
        .sheet(isPresented: $showAddCommand) {
            AddCommandSheet(onSave: { newCmd in
                addCommand(newCmd, to: app.id)
            }, store: store)
        }
    }

    private func beginEdit(_ cmd: PieCommand) {
        editingCommandId = cmd.actionId
        tempName = cmd.label
        tempIcon = cmd.icon
    }
    
    private func addCommand(_ cmd: PieCommand, to appId: String) {
        NSLog("Adding command: \(cmd.actionId) with label: \(cmd.label)")
        app.availableCommands.append(cmd)
        NSLog("Available commands count: \(app.availableCommands.count)")
        onSave()
        NSLog("Command added and saved")
    }

    private var EditCommandSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Edit Command").font(.title3).fontWeight(.semibold)
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.thinMaterial)
                    .frame(width: 64, height: 64)
                    IconPreview(icon: tempIcon, store: store, size: 44)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Name")
                    TextField("Command name", text: $tempName)
                        .textFieldStyle(.roundedBorder)
                    Text("Shortcut")
                    if let cmd = app.availableCommands.first(where: { $0.actionId == editingCommandId }), let ks = cmd.keystrokeDisplay {
                        Text(ks).font(.headline)
                    } else {
                        Text("—").foregroundStyle(.secondary)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Choose Icon").font(.headline)
                    Spacer()
                    Button("Upload…") { showingImporter = true }
                }
                TextField("Search SF Symbols", text: $sfSearch).textFieldStyle(.roundedBorder)
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(44), spacing: 8), count: 8), spacing: 8) {
                        ForEach(filteredSFSymbols, id: \.self) { name in
                            Button {
                                tempIcon = CommandIcon(kind: .sfSymbol, name: name, filename: nil)
                            } label: {
                                RoundedRectangle(cornerRadius: 8).fill(.thinMaterial).frame(width: 44, height: 44)
                                    .overlay(Image(systemName: name))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            HStack {
                Spacer()
                Button("Cancel") { editingCommandId = nil }
                Button("Save") { saveEdits() }
            }
        }
        .padding(16)
        .frame(width: 520)
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.png, .jpeg, .tiff, .icns]) { result in
            if case let .success(url) = result {
                if let filename = store.saveCustomIcon(from: url) {
                    tempIcon = CommandIcon(kind: .custom, name: nil, filename: filename)
                }
            }
        }
    }

    private func saveEdits() {
        guard let id = editingCommandId, let idx = app.availableCommands.firstIndex(where: { $0.actionId == id }) else { editingCommandId = nil; return }
        app.availableCommands[idx].label = tempName.trimmingCharacters(in: .whitespacesAndNewlines)
        app.availableCommands[idx].icon = tempIcon
        onSave()
        editingCommandId = nil
    }

    private func assignToNextEmptySlot(_ actionId: String) {
        for i in 0..<8 where app.pieSlots[i] == nil { app.pieSlots[i] = actionId; onSave(); return }
        app.pieSlots[7] = actionId; onSave()
    }
}

private struct IconPreview: View {
    var icon: CommandIcon?
    let store: ConfigurationStore
    var size: CGFloat = 16
    var body: some View {
        Group {
            switch icon?.kind {
            case .sfSymbol?:
                if let name = icon?.name, !name.isEmpty {
                    Image(systemName: name)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else { Image(systemName: "square") }
            case .custom?:
                if let img = store.image(for: icon) {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: "photo")
                }
            default:
                Image(systemName: "square")
            }
        }
        .frame(width: size, height: size)
    }
}

private struct IconLibrarySheet: View {
    @ObservedObject var store: ConfigurationStore
    @Binding var selected: CommandIcon?
    @State private var sfSearch = ""
    @State private var showingImporter = false
    @Environment(\.dismiss) private var dismiss

    // Minimal curated SF Symbols set; can be expanded
    private let sfSets: [String] = [
        "bolt.fill", "flame.fill", "hare.fill", "tortoise.fill", "scissors", "doc.on.doc",
        "clipboard", "arrow.uturn.left", "arrow.triangle.2.circlepath", "square.stack.3d.up",
        "pencil", "trash", "folder", "tray.and.arrow.down", "tray.and.arrow.up", "magnifyingglass"
    ]

    var filtered: [String] {
        let q = sfSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return sfSets }
        return sfSets.filter { $0.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Choose Icon").font(.headline)
                Spacer()
                Button("Upload…") { showingImporter = true }
            }
            TextField("Search SF Symbols", text: $sfSearch).textFieldStyle(.roundedBorder)
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(44), spacing: 8), count: 8), spacing: 8) {
                    ForEach(filtered, id: \.self) { name in
                        Button {
                            selected = CommandIcon(kind: .sfSymbol, name: name, filename: nil)
                            dismiss()
                        } label: {
                            RoundedRectangle(cornerRadius: 8).fill(.thinMaterial).frame(width: 44, height: 44)
                                .overlay(Image(systemName: name))
                        }
                    }
                }
            }
            HStack {
                Spacer()
                Button("Close") { dismiss() }
            }
        }
        .padding(16)
        .frame(width: 520, height: 420)
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.png, .jpeg, .svg]) { result in
            if case let .success(url) = result {
                if let filename = store.saveCustomIcon(from: url) {
                    selected = CommandIcon(kind: .custom, name: nil, filename: filename)
                    dismiss()
                }
            }
        }
    }
}

private struct AddCommandSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (PieCommand) -> Void
    let store: ConfigurationStore

    @State private var name: String = ""
    @State private var capturedKeyCode: UInt32? = nil
    @State private var capturedModifiers: UInt32 = 0
    @State private var isCapturing = false
    @State private var selectedIcon: CommandIcon? = nil
    @State private var sfSearch: String = ""
    @State private var showingImporter = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Command").font(.title3).fontWeight(.semibold)
            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                TextField("e.g. Duplicate", text: $name)
                    .textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Keystroke")
                KeystrokeField(display: keystrokeDisplay, isCapturing: $isCapturing) { keyCode, mods in
                    capturedKeyCode = keyCode
                    capturedModifiers = mods
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Choose Icon").font(.headline)
                    Spacer()
                    Button("Upload…") { showingImporter = true }
                }
                TextField("Search SF Symbols", text: $sfSearch).textFieldStyle(.roundedBorder)
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(44), spacing: 8), count: 8), spacing: 8) {
                        ForEach(filteredSFSymbols, id: \.self) { name in
                            Button {
                                selectedIcon = CommandIcon(kind: .sfSymbol, name: name, filename: nil)
                            } label: {
                                RoundedRectangle(cornerRadius: 8).fill(.thinMaterial).frame(width: 44, height: 44)
                                    .overlay(Image(systemName: name))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { save() }
                    .keyboardShortcut(.return)
                    .disabled(!canSave)
            }
        }
        .padding(16)
        .frame(width: 520)
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.png, .jpeg, .tiff, .icns]) { result in
            if case let .success(url) = result {
                if let filename = store.saveCustomIcon(from: url) {
                    selectedIcon = CommandIcon(kind: .custom, name: nil, filename: filename)
                }
            }
        }
    }

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && capturedKeyCode != nil }
    
    private let sfSets: [String] = [
        "bolt.fill", "flame.fill", "hare.fill", "tortoise.fill", "scissors", "doc.on.doc",
        "clipboard", "arrow.uturn.left", "arrow.triangle.2.circlepath", "square.stack.3d.up",
        "pencil", "trash", "folder", "tray.and.arrow.down", "tray.and.arrow.up", "magnifyingglass"
    ]

    private var filteredSFSymbols: [String] {
        let q = sfSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return sfSets }
        return sfSets.filter { $0.localizedCaseInsensitiveContains(q) }
    }

    private var keystrokeDisplay: String {
        guard let key = capturedKeyCode else { return isCapturing ? "Recording…" : "Click to record" }
        let parts = [
            (capturedModifiers & UInt32(cmdKey)) != 0 ? "⌘" : nil,
            (capturedModifiers & UInt32(shiftKey)) != 0 ? "⇧" : nil,
            (capturedModifiers & UInt32(optionKey)) != 0 ? "⌥" : nil,
            (capturedModifiers & UInt32(controlKey)) != 0 ? "⌃" : nil,
            keyToLabel(key)
        ].compactMap { $0 }
        return parts.joined(separator: "")
    }

    private func keyToLabel(_ keyCode: UInt32) -> String {
        switch keyCode {
        case UInt32(kVK_ANSI_A): return "A"; case UInt32(kVK_ANSI_B): return "B"; case UInt32(kVK_ANSI_C): return "C";
        case UInt32(kVK_ANSI_D): return "D"; case UInt32(kVK_ANSI_E): return "E"; case UInt32(kVK_ANSI_F): return "F";
        case UInt32(kVK_ANSI_G): return "G"; case UInt32(kVK_ANSI_H): return "H"; case UInt32(kVK_ANSI_I): return "I";
        case UInt32(kVK_ANSI_J): return "J"; case UInt32(kVK_ANSI_K): return "K"; case UInt32(kVK_ANSI_L): return "L";
        case UInt32(kVK_ANSI_M): return "M"; case UInt32(kVK_ANSI_N): return "N"; case UInt32(kVK_ANSI_O): return "O";
        case UInt32(kVK_ANSI_P): return "P"; case UInt32(kVK_ANSI_Q): return "Q"; case UInt32(kVK_ANSI_R): return "R";
        case UInt32(kVK_ANSI_S): return "S"; case UInt32(kVK_ANSI_T): return "T"; case UInt32(kVK_ANSI_U): return "U";
        case UInt32(kVK_ANSI_V): return "V"; case UInt32(kVK_ANSI_W): return "W"; case UInt32(kVK_ANSI_X): return "X";
        case UInt32(kVK_ANSI_Y): return "Y"; case UInt32(kVK_ANSI_Z): return "Z";
        default: return "#\(keyCode)"
        }
    }

    private func save() {
        guard let keyCode = capturedKeyCode else { 
            NSLog("AddCommandSheet: No keyCode captured")
            return 
        }
        let label = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty else {
            NSLog("AddCommandSheet: Empty label")
            return
        }
        let actionId = makeActionId(from: label)
        let def = ActionDefinition(type: .keystroke, keystroke: KeystrokeAction(keyCode: keyCode, modifiers: capturedModifiers), menuItem: nil)
        // Provide default icon if none selected
        let icon = selectedIcon ?? CommandIcon(kind: .sfSymbol, name: "command", filename: nil)
        let cmd = PieCommand(actionId: actionId, label: label, definition: def, icon: icon)
        NSLog("AddCommandSheet: Saving command - actionId: \(actionId), label: \(label)")
        onSave(cmd)
        dismiss()
    }

    private func makeActionId(from name: String) -> String {
        let base = name.lowercased().replacingOccurrences(of: " ", with: "-").replacingOccurrences(of: "/", with: "-")
        return base.isEmpty ? UUID().uuidString : base
    }
}

private struct KeystrokeField: View {
    let display: String
    @Binding var isCapturing: Bool
    let onCaptured: (UInt32, UInt32) -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(.quaternary)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(.background))
                .frame(height: 28)
            Text(display)
                .foregroundStyle(isCapturing ? .secondary : .primary)
        }
        .contentShape(Rectangle())
        .onTapGesture { isCapturing = true }
        .overlay(
            KeystrokeCaptureRepresentable(isCapturing: $isCapturing, onCaptured: onCaptured)
                .allowsHitTesting(false)
        )
    }
}

private struct KeystrokeCaptureRepresentable: NSViewRepresentable {
    @Binding var isCapturing: Bool
    let onCaptured: (UInt32, UInt32) -> Void

    func makeNSView(context: Context) -> CaptureView {
        let v = CaptureView()
        v.onCaptured = onCaptured
        return v
    }

    func updateNSView(_ nsView: CaptureView, context: Context) {
        nsView.onCaptured = onCaptured
        nsView.isCapturing = isCapturing
        if isCapturing {
            DispatchQueue.main.async { nsView.window?.makeFirstResponder(nsView) }
        }
    }

    final class CaptureView: NSView {
        var onCaptured: ((UInt32, UInt32) -> Void)?
        var isCapturing: Bool = false
        override var acceptsFirstResponder: Bool { true }
        override func keyDown(with event: NSEvent) {
            let carbon = toCarbonMask(event.modifierFlags)
            onCaptured?(UInt32(event.keyCode), carbon)
            isCapturing = false
        }
        override func resignFirstResponder() -> Bool {
            isCapturing = false
            return super.resignFirstResponder()
        }
        private func toCarbonMask(_ flags: NSEvent.ModifierFlags) -> UInt32 {
            var mask: UInt32 = 0
            if flags.contains(.command) { mask |= UInt32(cmdKey) }
            if flags.contains(.shift) { mask |= UInt32(shiftKey) }
            if flags.contains(.option) { mask |= UInt32(optionKey) }
            if flags.contains(.control) { mask |= UInt32(controlKey) }
            return mask
        }
    }
} 