import SwiftUI
import Carbon
import UniformTypeIdentifiers
import AppKit

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

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
        VStack(spacing: 0) {
            // App Icon and Title Section
            VStack(spacing: 24) {
                // App Icon
                Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                
                // App Name and Version
                VStack(spacing: 8) {
                    Text("MacPie")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Version \(store.general.appVersion)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "8b8b8b"))
                }
            }
            .padding(.top, 40)
            
            // Settings Section
            VStack(spacing: 32) {
                // Hotkey Setting
                VStack(alignment: .leading, spacing: 16) {
                    Text("Global Hotkey")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 12) {
                        Text("Press the keys you want to use as the global hotkey")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color(hex: "8b8b8b"))
                            .lineLimit(2)
                        
                        Spacer()
                        
                        Button("Record") {
                            capturedKeyCode = nil
                            capturedModifiers = 0
                            capturing = true
                            showHotkeyCapture = true
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(hex: "4a9eff"))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(16)
                    .background(Color(hex: "2a2a2a"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Launch at Login Setting
                VStack(alignment: .leading, spacing: 16) {
                    Text("Launch at Login")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    HStack {
                        Toggle("", isOn: $launchAtLogin)
                            .toggleStyle(SwitchToggleStyle(tint: Color(hex: "4a9eff")))
                        
                        Text("Automatically start MacPie when you log in")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color(hex: "8b8b8b"))
                        
                        Spacer()
                    }
                    .padding(16)
                    .background(Color(hex: "2a2a2a"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 40)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "222425"))
        .onChange(of: launchAtLogin) { _ in
            store.general.launchAtLogin = launchAtLogin
            store.save()
        }
        .onAppear { loadDefaultsFromStore() }
        .sheet(isPresented: $showHotkeyCapture) { HotkeyCaptureSheet }
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
    @State private var search = ""
    @State private var softwareSearch = ""
    @State private var showAddCommand = false
    @State private var showAddAppModal = false
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
            // No auto-population needed
        }
        .onAppear { 
            if selectedApp == nil { 
                selectedApp = store.apps.first 
            } 
        }
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
        .sheet(isPresented: $showAddAppModal) {
            AddAppModal(store: store) { addedApp in
                if let addedApp = addedApp {
                    selectedApp = addedApp
                }
                showAddAppModal = false
            }
        }
    }

    private var Sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header section with modern styling
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Added Software")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("Applications configured with MacPie")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(action: { showAddAppModal = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .medium))
                            Text("Add App")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            // Search bar with modern design
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 14))
                TextField("Search software...", text: $softwareSearch)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                if !softwareSearch.isEmpty {
                    Button(action: { softwareSearch = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.quinary, in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            
            // Content area
            if filteredApps.isEmpty {
                // Empty state with improved design
                VStack(spacing: 16) {
                    Image(systemName: "apps.iphone")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary.opacity(0.6))
                    VStack(spacing: 8) {
                        Text("No Apps Added")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("Add your first application to start\nconfiguring pie menus")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    Button("Add Your First App") {
                        showAddAppModal = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 32)
                .padding(.vertical, 40)
            } else {
                // Apps list with modern cards
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredApps) { app in
                            AppRowCard(
                                app: app,
                                isSelected: selectedApp?.id == app.id,
                                onSelect: { selectedApp = app },
                                onDelete: { removeSoftware(app) }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
        }
        .frame(width: 320)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var Content: some View {
        Group {
            if let app = selectedApp {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(app.name).font(.title3).fontWeight(.semibold)
                            Text(app.bundleIdentifier).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
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
                                Button("Add Command") { 
                                    pendingAppIdForNewCommand = app.id; 
                                    showAddCommand = true 
                                }
                                .buttonStyle(.borderedProminent)
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
                VStack(spacing: 16) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No Software Configured")
                        .font(.title2)
                        .fontWeight(.medium)
                    Text("Add software and assign commands to pie slots to see them here")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Add Software") {
                        showAddAppModal = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func removeSoftware(_ app: AppProfile) {
        if let idx = store.apps.firstIndex(where: { $0.id == app.id }) {
            store.apps.remove(at: idx)
            store.save()
            if selectedApp?.id == app.id {
                selectedApp = store.apps.first
            }
        }
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
        store.apps[idx].availableCommands.append(cmd)
        store.save()
        selectedApp = store.apps[idx]
    }
}

// MARK: - App Row Card Component
private struct AppRowCard: View {
    let app: AppProfile
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // App icon
            Image(nsImage: AppIconProvider.icon(for: app.bundleIdentifier, size: 32))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)
                .cornerRadius(8)
                .shadow(radius: 1)
            
            // App info
            VStack(alignment: .leading, spacing: 4) {
                Text(app.name)
                    .font(.system(.body, design: .default, weight: .medium))
                    .foregroundStyle(.primary)
                Text("\(app.availableCommands.count) commands")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 8) {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
                .help("Remove software")
                
                Button(action: onSelect) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Configure software")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? .blue : .clear, lineWidth: 1.5)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            onSelect()
        }
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Add App Modal
private struct AddAppModal: View {
    @ObservedObject var store: ConfigurationStore
    let onAdd: (AppProfile?) -> Void
    
    @State private var search = ""
    @State private var discoveredApps: [DiscoveredApp] = []
    @State private var isLoading = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Add Software").font(.title2).fontWeight(.semibold)
                Spacer()
                Button("Cancel") { onAdd(nil) }
                    .buttonStyle(.borderless)
            }
            
            Text("Select software from your computer to add to MacPie")
                .foregroundStyle(.secondary)
            
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search applications...", text: $search)
                    .textFieldStyle(.roundedBorder)
            }
            
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView("Discovering applications...")
                    Spacer()
                }
                .padding()
            } else {
                List {
                    ForEach(filteredApps, id: \.bundleIdentifier) { app in
                        HStack(spacing: 12) {
                            Image(nsImage: AppIconProvider.icon(for: app.bundleIdentifier, size: 32))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 32, height: 32)
                                .cornerRadius(6)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.name).font(.body).fontWeight(.medium)
                                Text(app.bundleIdentifier).font(.caption).foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            if store.apps.contains(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
                                Text("Added")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.green.opacity(0.2), in: Capsule())
                                    .foregroundStyle(.green)
                            } else {
                                Button("Add") {
                                    addSoftware(app)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.inset)
            }
            
            HStack {
                Spacer()
                Button("Refresh") {
                    discoverApps()
                }
                .buttonStyle(.bordered)
                Button("Done") { onAdd(nil) }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 600, height: 500)
        .onAppear {
            discoverApps()
        }
    }
    
    private var filteredApps: [DiscoveredApp] {
        if search.isEmpty {
            return discoveredApps
        } else {
            return discoveredApps.filter { app in
                app.name.localizedCaseInsensitiveContains(search) ||
                app.bundleIdentifier.localizedCaseInsensitiveContains(search)
            }
        }
    }
    
    private func discoverApps() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let apps = AppDiscovery.findInstalledApps()
            DispatchQueue.main.async {
                self.discoveredApps = apps
                self.isLoading = false
            }
        }
    }
    
    private func addSoftware(_ appInfo: DiscoveredApp) {
        let newProfile = AppProfile(
            name: appInfo.name,
            bundleIdentifier: appInfo.bundleIdentifier,
            availableCommands: [],
            pieSlots: [:]
        )
        store.apps.append(newProfile)
        store.save()
        onAdd(newProfile)
    }
}

// MARK: - Pie Editor Components
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

// MARK: - Command Row Card Component
private struct CommandRowCard: View {
    let command: PieCommand
    let store: ConfigurationStore
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onDrag: () -> NSItemProvider
    
    var body: some View {
        HStack(spacing: 12) {
            // Command icon
            IconPreview(icon: command.icon, store: store, size: 24)
                .frame(width: 32, height: 32)
                .background(Color.gray.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
            
            // Command info
            VStack(alignment: .leading, spacing: 4) {
                Text(command.label)
                    .font(.system(.body, design: .default, weight: .medium))
                    .foregroundStyle(.primary)
                if let keystroke = command.keystrokeDisplay {
                    Text(keystroke)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.tertiary.opacity(0.5), in: Capsule())
                }
            }
            
            Spacer()
            
            // Action buttons with modern design
            HStack(spacing: 8) {
                Button(action: onEdit) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .medium))
                        Text("Edit")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button(action: onDelete) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .medium))
                        Text("Delete")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onDrag(onDrag)
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
        VStack(alignment: .leading, spacing: 16) {
            // Header section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Commands")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("Keyboard shortcuts and actions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(action: { showAddCommand = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .medium))
                            Text("Add Command")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filtered) { cmd in
                        CommandRowCard(
                            command: cmd,
                            store: store,
                            onEdit: { beginEdit(cmd) },
                            onDelete: { deleteCommand(cmd) },
                            onDrag: {
                                NSLog("Starting drag for command: \(cmd.actionId)")
                                let provider = NSItemProvider()
                                provider.registerDataRepresentation(forTypeIdentifier: UTType.utf8PlainText.identifier, visibility: .all) { completion in
                                    let data = cmd.actionId.data(using: .utf8) ?? Data()
                                    NSLog("Drag data: \(cmd.actionId) -> \(data.count) bytes")
                                    completion(data, nil)
                                    return nil
                                }
                                provider.registerObject(NSString(string: cmd.actionId), visibility: .all)
                                return provider
                            }
                        )
                        .onTapGesture(count: 2) { assignToNextEmptySlot(cmd.actionId) }
                    }
                }
                .padding(.horizontal, 8)
            }
            // Footer section
            VStack(spacing: 8) {
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("💡 Pro Tips")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        Text("• Drag commands onto the pie to assign them")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("• Double-click to assign to next empty slot")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Save Changes") { onSave() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
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

    private func deleteCommand(_ cmd: PieCommand) {
        if let idx = app.availableCommands.firstIndex(where: { $0.actionId == cmd.actionId }) {
            app.availableCommands.remove(at: idx)
            onSave()
            NSLog("Command deleted: \(cmd.actionId)")
        }
    }

    private var EditCommandSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            EditCommandHeader
            EditCommandDetails
            Divider()
            EditIconSelection
            Divider()
            EditActionButtons
        }
        .padding(20)
        .frame(width: 600, height: 600)
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.png, .jpeg, .tiff, .icns]) { result in
            if case let .success(url) = result {
                if let filename = store.saveCustomIcon(from: url) {
                    tempIcon = CommandIcon(kind: .custom, name: nil, filename: filename)
                }
            }
        }
    }
    
    private var EditCommandHeader: some View {
        HStack {
            Text("Edit Command").font(.title2).fontWeight(.semibold)
            Spacer()
            Button("Cancel") { editingCommandId = nil }
                .buttonStyle(.borderless)
        }
    }
    
    private var EditCommandDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Command Details").font(.headline)
            
            HStack(alignment: .top, spacing: 16) {
                EditIconDisplay
                EditCommandFields
            }
        }
    }
    
    private var EditIconDisplay: some View {
        VStack(spacing: 8) {
            Text("Current Icon").font(.subheadline).foregroundStyle(.secondary)
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.thinMaterial)
                    .frame(width: 80, height: 80)
                IconPreview(icon: tempIcon, store: store, size: 48)
            }
        }
    }
    
    private var EditCommandFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Command Name").font(.subheadline).foregroundStyle(.secondary)
                TextField("Enter command name", text: $tempName)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Keyboard Shortcut").font(.subheadline).foregroundStyle(.secondary)
                if let cmd = app.availableCommands.first(where: { $0.actionId == editingCommandId }), let ks = cmd.keystrokeDisplay {
                    Text(ks)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
                        .foregroundStyle(.primary)
                } else {
                    Text("—")
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var EditIconSelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Change Icon").font(.headline)
                Spacer()
                Button("Upload Custom Icon") { showingImporter = true }
                    .buttonStyle(.bordered)
            }
            
            TextField("Search SF Symbols", text: $sfSearch)
                .textFieldStyle(.roundedBorder)
                .placeholder(when: sfSearch.isEmpty) {
                    Text("Type to search SF Symbols...").foregroundStyle(.secondary)
                }
            
            EditIconGrid
        }
    }
    
    private var EditIconGrid: some View {
        IconGridContent(
            symbols: filteredSFSymbols,
            selectedIcon: tempIcon,
            onSelect: { name in
                tempIcon = CommandIcon(kind: .sfSymbol, name: name, filename: nil)
            }
        )
    }
    
    private var EditActionButtons: some View {
        HStack {
            Spacer()
            Button("Cancel") { editingCommandId = nil }
                .buttonStyle(.bordered)
            Button("Save Changes") { saveEdits() }
                .buttonStyle(.borderedProminent)
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
        VStack(alignment: .leading, spacing: 16) {
            AddCommandHeader
            AddCommandDetails
            Divider()
            AddIconSelection
            Divider()
            AddActionButtons
        }
        .padding(20)
        .frame(width: 600, height: 600)
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.png, .jpeg, .tiff, .icns]) { result in
            if case let .success(url) = result {
                if let filename = store.saveCustomIcon(from: url) {
                    selectedIcon = CommandIcon(kind: .custom, name: nil, filename: filename)
                }
            }
        }
    }
    
    private var AddCommandHeader: some View {
        HStack {
            Text("Add New Command").font(.title2).fontWeight(.semibold)
            Spacer()
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.borderless)
        }
    }
    
    private var AddCommandDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Command Details").font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Command Name").font(.subheadline).foregroundStyle(.secondary)
                TextField("e.g. Duplicate, Copy, Paste", text: $name)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Keyboard Shortcut").font(.subheadline).foregroundStyle(.secondary)
                KeystrokeField(display: keystrokeDisplay, isCapturing: $isCapturing) { keyCode, mods in
                    capturedKeyCode = keyCode
                    capturedModifiers = mods
                }
            }
        }
    }
    
    private var AddIconSelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Choose Icon").font(.headline)
                Spacer()
                Button("Upload Custom Icon") { showingImporter = true }
                    .buttonStyle(.bordered)
            }
            
            TextField("Search SF Symbols", text: $sfSearch)
                .textFieldStyle(.roundedBorder)
                .placeholder(when: sfSearch.isEmpty) {
                    Text("Type to search SF Symbols...").foregroundStyle(.secondary)
                }
            
            AddIconGrid
        }
    }
    
    private var AddIconGrid: some View {
        IconGridContent(
            symbols: filteredSFSymbols,
            selectedIcon: selectedIcon,
            onSelect: { name in
                selectedIcon = CommandIcon(kind: .sfSymbol, name: name, filename: nil)
            }
        )
    }
    
    private var AddActionButtons: some View {
        HStack {
            Spacer()
            Button("Cancel") { dismiss() }
                .buttonStyle(.bordered)
            Button("Create Command") { save() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
                .disabled(!canSave)
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

// MARK: - Shared Icon Grid Component
private struct IconGridContent: View {
    let symbols: [String]
    let selectedIcon: CommandIcon?
    let onSelect: (String) -> Void
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 8) {
                ForEach(symbols, id: \.self) { name in
                    IconGridButton(
                        name: name,
                        isSelected: selectedIcon?.name == name,
                        onSelect: { onSelect(name) }
                    )
                }
            }
        }
        .frame(maxHeight: 200)
    }
    
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.fixed(44), spacing: 8), count: 8)
    }
}

private struct IconGridButton: View {
    let name: String
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                .frame(width: 44, height: 44)
                .overlay(Image(systemName: name))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - View Extensions
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

// MARK: - Pie Configuration View (Figma Design)

struct PieConfigurationView: View {
    @EnvironmentObject private var store: ConfigurationStore
    @State private var selectedApp: AppProfile?
    @State private var showingAddApp = false
    @State private var showingAddCommand = false
    @State private var searchText = ""
    @State private var commandSearchText = ""
    @State private var hoveredPieCommand: PieCommand?
    
    var body: some View {
        HStack(spacing: 16) {
            // Left Panel - Apps List (269px width)
            AppsPanelView(
                searchText: $searchText,
                selectedApp: $selectedApp,
                showingAddApp: $showingAddApp,
                store: store
            )
            .frame(width: 269)
            
            // Center Panel - Pie Configuration (377px width)
            PiePanelView(
                selectedApp: $selectedApp,
                hoveredPieCommand: $hoveredPieCommand,
                store: store
            )
            .frame(width: 377)
            
            // Right Panel - Commands List (328px width)
            CommandsPanelView(
                selectedApp: $selectedApp,
                commandSearchText: $commandSearchText,
                showingAddCommand: $showingAddCommand,
                hoveredPieCommand: $hoveredPieCommand,
                store: store
            )
            .frame(width: 328)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheet(isPresented: $showingAddApp) {
            AddAppModal(store: store) { app in
                if let app = app {
                    store.apps.append(app)
                    store.save()
                    selectedApp = app
                }
            }
        }
        .sheet(isPresented: $showingAddCommand) {
            AddCommandSheet(onSave: { command in
                if let selectedApp = selectedApp {
                    // Add command to selected app
                    var updatedApp = selectedApp
                    updatedApp.availableCommands.append(command)
                    
                    // Update in store
                    if let index = store.apps.firstIndex(where: { $0.id == selectedApp.id }) {
                        store.apps[index] = updatedApp
                        self.selectedApp = updatedApp
                        store.save()
                    }
                }
            }, store: store)
        }
        .onAppear {
            if selectedApp == nil && !store.apps.isEmpty {
                selectedApp = store.apps.first
            }
        }
    }
}

// MARK: - Actions Configuration (Logi-style UI)
struct ActionsConfigurationView: View {
    @EnvironmentObject private var store: ConfigurationStore
    @State private var selectedPreset: String = "Custom"
    
    var body: some View {
        HStack(spacing: 24) {
            // Left device preview panel (placeholder visual)
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.black.opacity(0.35))
                VStack {
                    Spacer()
                    Image("appstore")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 260)
                        .opacity(0.12)
                    Spacer()
                }
            }
            .frame(width: 560, height: 520)
            
            // Right actions panel
            VStack(spacing: 0) {
                // Header pill
                HStack {
                    Text("Actions")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(hex: "111111").opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "2a2a2a"), lineWidth: 1)
                )
                
                // Scrollable actions
                ScrollView {
                    VStack(spacing: 12) {
                        SectionHeader("Spotlight Effects", isNew: true)
                        ActionRow(title: "Spotlight Effects")
                        
                        SectionHeader("AI ACTIONS")
                        ActionRow(title: "Open AI Prompt Builder")
                        ActionRow(title: "Open ChatGPT")
                        
                        SectionHeader("SMART ACTIONS")
                        ActionRow(title: "Create Smart Actions")
                        
                        SectionHeader("OTHER ACTIONS")
                        VStack(spacing: 0) {
                            HStack {
                                Text("Gestures")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding()
                            .background(Color(hex: "00d0b8").opacity(0.25))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "00d0b8"), lineWidth: 1)
                            )
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Choose a preset or select custom to create your own.")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "bdbdbd"))
                                Picker("Preset", selection: $selectedPreset) {
                                    Text("Custom").tag("Custom")
                                    Text("Media").tag("Media")
                                    Text("Navigation").tag("Navigation")
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                            
                            VStack(spacing: 8) {
                                GestureRow(direction: "HOLD + MOVE LEFT", title: "Brightness down")
                                GestureRow(direction: "HOLD + MOVE RIGHT", title: "Brightness up")
                                GestureRow(direction: "HOLD + MOVE UP", title: "Volume up")
                                GestureRow(direction: "HOLD + MOVE DOWN", title: "Volume down")
                            }
                            .padding(.horizontal)
                            .padding(.bottom)
                        }
                        .background(Color(hex: "0f0f0f").opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "242424"), lineWidth: 1)
                        )
                    }
                    .padding(.top, 12)
                }
            }
            .frame(width: 420, height: 520)
        }
        .padding(24)
        .background(Color(hex: "111213"))
    }
}

private struct SectionHeader: View {
    let title: String
    var isNew: Bool = false
    init(_ title: String, isNew: Bool = false) { self.title = title; self.isNew = isNew }
    var body: some View {
        HStack(spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "9c9c9c"))
            if isNew {
                Text("NEW")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: "00d0b8"))
                    .clipShape(Capsule())
            }
            Spacer()
        }
        .padding(.top, 12)
    }
}

private struct ActionRow: View {
    let title: String
    var body: some View {
        HStack {
            Circle().fill(Color(hex: "2a2a2a")).frame(width: 16, height: 16)
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.white)
            Spacer()
        }
        .padding(12)
        .background(Color(hex: "141414"))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "242424"), lineWidth: 1))
    }
}

private struct GestureRow: View {
    let direction: String
    let title: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.left.and.right.and.arrow.up.and.down")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "00d0b8"))
            VStack(alignment: .leading, spacing: 2) {
                Text(direction)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(hex: "9c9c9c"))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            Spacer()
        }
        .padding(12)
        .background(Color(hex: "151515"))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "242424"), lineWidth: 1))
    }
}
// MARK: - Sub-Views

struct AppsPanelView: View {
    @Binding var searchText: String
    @Binding var selectedApp: AppProfile?
    @Binding var showingAddApp: Bool
    let store: ConfigurationStore
    
    var body: some View {
        VStack(spacing: 12) {
            // Add App Button
            Button(action: { showingAddApp = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 16))
                    Text("Add app")
                        .font(.system(size: 16, weight: .regular))
                }
                .foregroundColor(.white)
                .padding(.leading, 24)
                .padding(.trailing, 32)
                .padding(.vertical, 12)
                .background(
                    Color(hex: "ee5c16")
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        .shadow(color: .black.opacity(0.2), radius: 11, x: 0, y: 4)
                )
            }
            .buttonStyle(.plain)
            .frame(width: 269)
            
            // Apps List Container
            VStack(spacing: 0) {
                // Search Bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "8b8b8b"))
                    
                    TextField("Search app..", text: $searchText)
                        .font(.system(size: 13, weight: .light))
                        .foregroundColor(Color(hex: "8b8b8b"))
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 19)
                .padding(.vertical, 13)
                .background(Color(hex: "383a3b"))
                
                // Apps ScrollView
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredApps) { app in
                            FigmaAppRowView(
                                app: app,
                                isSelected: selectedApp?.id == app.id,
                                onSelect: { selectedApp = app }
                            )
                        }
                    }
                }
                .frame(height: 454)
            }
            .background(Color(hex: "1b1c1e"))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(hex: "383a3b"), lineWidth: 1)
            )
            .frame(width: 269)
        }
    }
    
    private var filteredApps: [AppProfile] {
        let appsWithCommands = store.apps.filter { app in
            // Only show apps that have at least one command assigned to a pie slot
            !app.pieSlots.isEmpty
        }
        
        if searchText.isEmpty {
            return appsWithCommands
        }
        return appsWithCommands.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
}

struct PiePanelView: View {
    @Binding var selectedApp: AppProfile?
    @Binding var hoveredPieCommand: PieCommand?
    let store: ConfigurationStore
    @State private var hoveredSliceIndex: Int? = nil
    @State private var commandPickerIndex: Int? = nil
    @State private var isShowingCommandPicker: Bool = false
    @State private var floatingMenuIndex: Int? = nil
    @State private var pendingDeleteSliceIndex: Int? = nil
    @State private var showingDeleteConfirm: Bool = false
    
    var body: some View {
        VStack(spacing: 13) {
            // Selected App Header
            if let selectedApp = selectedApp {
                HStack(spacing: 8) {
                    // App icon using AppIconProvider
                    Image(nsImage: AppIconProvider.icon(for: selectedApp.bundleIdentifier, size: 40))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 9.836))
                        .shadow(color: .black.opacity(0.1), radius: 2.5, x: 0, y: 1.25)
                        .shadow(color: .black.opacity(0.2), radius: 13.75, x: 0, y: 5)
                    
                    Text(selectedApp.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
            } else {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 9.836)
                        .fill(Color(hex: "383838"))
                        .frame(width: 40, height: 40)
                    
                    Text("Select an app")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "8b8b8b"))
                }
            }
            
            // Pie Settings Container
            VStack(alignment: .leading, spacing: 28) {
                Text("Pie settings")
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(Color(hex: "8b8b8b"))
                
                // Pie Visualization
                PieCanvasView(
                    selectedApp: $selectedApp,
                    hoveredPieCommand: $hoveredPieCommand,
                    hoveredSliceIndex: $hoveredSliceIndex,
                    store: store,
                    commandPickerIndex: $commandPickerIndex,
                    isShowingCommandPicker: $isShowingCommandPicker,
                    floatingMenuIndex: $floatingMenuIndex,
                    removeCommandFromPie: removeCommandFromPie,
                    assignCommandToPie: assignCommandToPie
                )
                .frame(width: 337, height: 337)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: "1b1c1e"))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(hex: "383a3b"), lineWidth: 1)
            )
        }
        .frame(width: 377)
        .sheet(isPresented: $isShowingCommandPicker) {
            if let selectedApp = selectedApp, let pickerIndex = commandPickerIndex {
                CommandPickerSheet(
                    commands: selectedApp.availableCommands,
                    store: store,
                    onSelect: { command in
                        assignCommandToPie(commandId: command.actionId, sliceIndex: pickerIndex)
                        isShowingCommandPicker = false
                        commandPickerIndex = nil
                    }
                )
            }
        }
        .alert("Remove Command?", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let idx = pendingDeleteSliceIndex {
                    removeCommandFromPie(idx)
                    pendingDeleteSliceIndex = nil
                }
            }
        } message: {
            Text("This will remove the command from this slice.")
        }
    }
    
    private func assignCommandToPie(commandId: String, sliceIndex: Int) {
        guard var app = selectedApp else { return }
        
        // Update the pie slots
        if commandId.isEmpty {
            // Remove command
            app.pieSlots.removeValue(forKey: sliceIndex)
        } else {
            // Assign command
            app.pieSlots[sliceIndex] = commandId
        }
        
        // Update in store
        if let index = store.apps.firstIndex(where: { $0.id == app.id }) {
            store.apps[index] = app
            selectedApp = app
            store.save()
        }
    }
    
    private func removeCommandFromPie(_ sliceIndex: Int) {
        guard var app = selectedApp else { return }
        app.pieSlots.removeValue(forKey: sliceIndex)
        
        if let index = store.apps.firstIndex(where: { $0.id == app.id }) {
            store.apps[index] = app
            selectedApp = app
            store.save()
            hoveredPieCommand = nil
            NSLog("✅ Removed command from slice \(sliceIndex)")
        }
    }
}

// Extracted subview to keep expressions simple for compiler
private struct PieCanvasView: View {
    @Binding var selectedApp: AppProfile?
    @Binding var hoveredPieCommand: PieCommand?
    @Binding var hoveredSliceIndex: Int?
    let store: ConfigurationStore
    @Binding var commandPickerIndex: Int?
    @Binding var isShowingCommandPicker: Bool
    @Binding var floatingMenuIndex: Int?
    let removeCommandFromPie: (Int) -> Void
    let assignCommandToPie: (String, Int) -> Void
    @State private var pendingDeleteSliceIndex: Int? = nil
    @State private var showingDeleteConfirm: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "2a2a2a"))
                .frame(width: 337, height: 337)

            ForEach(0..<8, id: \.self) { index in
                let isHoveredSlice = hoveredSliceIndex == index
                FigmaPieSliceView(
                    index: index,
                    isHovered: isHoveredSlice,
                    command: selectedApp?.availableCommands.first(where: { cmd in
                        selectedApp?.pieSlots[index] == cmd.actionId
                    }),
                    onDrop: { _ in },
                    onDelete: {
                        pendingDeleteSliceIndex = index
                        showingDeleteConfirm = true
                    },
                    store: store
                )
                .simultaneousGesture(
                    TapGesture(count: 2).onEnded {
                        // Double-click empty slice
                        if let selectedApp = selectedApp, selectedApp.pieSlots[index] == nil {
                            commandPickerIndex = index
                            isShowingCommandPicker = true
                        }
                    }
                )
                .simultaneousGesture(
                    TapGesture(count: 1).onEnded {
                        // Single-click
                        if let selectedApp = selectedApp, selectedApp.pieSlots[index] != nil {
                            floatingMenuIndex = index
                        } else if selectedApp?.pieSlots[index] == nil {
                            commandPickerIndex = index
                            isShowingCommandPicker = true
                        }
                    }
                )
            }

            HoverTrackingView { point, size in
                let pieSize: CGFloat = 337
                // Convert AppKit coordinates (Y-up) to SwiftUI (Y-down)
                let swiftuiPoint = CGPoint(x: point.x, y: size.height - point.y)
                let center = CGPoint(x: pieSize / 2, y: pieSize / 2)
                let dx = swiftuiPoint.x - center.x
                let dy = swiftuiPoint.y - center.y // SwiftUI: Y increases downward
                let distance = sqrt(dx*dx + dy*dy)
                let inner: CGFloat = 30
                let outer: CGFloat = pieSize / 2
                guard distance >= inner && distance <= outer else {
                    hoveredSliceIndex = nil
                    hoveredPieCommand = nil
                    return
                }
                // SwiftUI coords: 0°=right, 90°=bottom, 180°=left, 270°=top
                var angle = atan2(dy, dx) * 180 / .pi
                if angle < 0 { angle += 360 }
                let idx = Int(floor((angle + 22.5) / 45.0)) % 8
                hoveredSliceIndex = idx
                if let selectedApp = selectedApp, let actionId = selectedApp.pieSlots[idx], let cmd = selectedApp.availableCommands.first(where: { $0.actionId == actionId }) {
                    hoveredPieCommand = cmd
                } else {
                    hoveredPieCommand = nil
                }
            }
            .frame(width: 337, height: 337)
            .allowsHitTesting(true)
            .onDrop(of: [UTType.text], delegate: PieDropDelegate(
                size: CGSize(width: 337, height: 337),
                onUpdateHover: { idx in hoveredSliceIndex = idx },
                onAssign: { commandId, idx in assignCommandToPie(commandId, idx) }
            ))

            if let idx = floatingMenuIndex {
                FloatingSliceMenu(
                    onReplace: {
                        commandPickerIndex = idx
                        isShowingCommandPicker = true
                        floatingMenuIndex = nil
                    },
                    onDelete: {
                        removeCommandFromPie(idx)
                        floatingMenuIndex = nil
                    }
                )
                .frame(width: 120)
                .offset(menuOffsetForSlice(index: idx))
            }

            if let hoveredCommand = hoveredPieCommand {
                VStack(spacing: 8) {
                    Text(hoveredCommand.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    Text(hoveredCommand.keystrokeDisplay ?? "No keystroke")
                        .font(.system(size: 8.667, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6.667)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.35).clipShape(RoundedRectangle(cornerRadius: 5.333)))
                        .overlay(RoundedRectangle(cornerRadius: 5.333).stroke(Color(hex: "505050"), lineWidth: 0.667))
                }
            }
        }
        .alert("Remove Command?", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let idx = pendingDeleteSliceIndex {
                    removeCommandFromPie(idx)
                    pendingDeleteSliceIndex = nil
                }
            }
        } message: {
            Text("This will remove the command from this slice.")
        }
    }
}
// MARK: - Drop Delegate for Pie
private struct PieDropDelegate: DropDelegate {
    let size: CGSize
    let onUpdateHover: (Int?) -> Void
    let onAssign: (String, Int) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.text])
    }

    func dropEntered(info: DropInfo) {
        updateHover(info: info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        updateHover(info: info)
        return DropProposal(operation: .copy)
    }

    func dropExited(info: DropInfo) {
        onUpdateHover(nil)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [UTType.text]).first else { return false }
        let idx = sliceIndex(for: info.location)
        guard idx >= 0 && idx < 8 else { return false } // Validate slice index
        provider.loadObject(ofClass: NSString.self) { object, _ in
            if let commandId = object as? String {
                DispatchQueue.main.async {
                    onAssign(commandId, idx)
                }
            }
        }
        return true
    }

    private func updateHover(info: DropInfo) {
        let idx = sliceIndex(for: info.location)
        onUpdateHover(idx >= 0 ? idx : nil)
    }

    private func sliceIndex(for point: CGPoint) -> Int {
        let pieSize: CGFloat = 337
        let center = CGPoint(x: pieSize / 2, y: pieSize / 2)
        let dx = point.x - center.x
        let dy = point.y - center.y // SwiftUI: Y increases downward
        let distance = sqrt(dx*dx + dy*dy)
        let inner: CGFloat = 30
        let outer: CGFloat = pieSize / 2
        guard distance >= inner && distance <= outer else {
            return -1 // Invalid drop zone
        }
        // SwiftUI coords: 0°=right, 90°=bottom, 180°=left, 270°=top
        var angle = atan2(dy, dx) * 180 / .pi
        if angle < 0 { angle += 360 }
        return Int(floor((angle + 22.5) / 45.0)) % 8
    }
}
struct CommandsPanelView: View {
    @Binding var selectedApp: AppProfile?
    @Binding var commandSearchText: String
    @Binding var showingAddCommand: Bool
    @Binding var hoveredPieCommand: PieCommand?
    let store: ConfigurationStore
    
    @State private var editingCommand: PieCommand?
    @State private var showingEditSheet = false
    
    var body: some View {
        VStack(spacing: 11) {
            // Add Command Button
            Button(action: { showingAddCommand = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 16))
                    Text("Add command")
                        .font(.system(size: 16, weight: .regular))
                }
                .foregroundColor(.white)
                .padding(.leading, 24)
                .padding(.trailing, 32)
                .padding(.vertical, 12)
                .background(
                    Color(hex: "525252")
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        .shadow(color: .black.opacity(0.2), radius: 11, x: 0, y: 4)
                )
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            
            // Commands List Container
            VStack(spacing: 0) {
                // Search Bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "8b8b8b"))
                    
                    TextField("Search command..", text: $commandSearchText)
                        .font(.system(size: 13, weight: .light))
                        .foregroundColor(Color(hex: "8b8b8b"))
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 19)
                .padding(.vertical, 13)
                .background(Color(hex: "383a3b"))
                
                // Commands ScrollView
                ScrollView {
                    LazyVStack(spacing: 8) {
                        // Available Commands
                        if let selectedApp = selectedApp {
                            if filteredCommands(for: selectedApp).isEmpty {
                                // Empty state
                                VStack(spacing: 12) {
                                    Image(systemName: "command.circle")
                                        .font(.system(size: 48))
                                        .foregroundColor(Color(hex: "505050"))
                                    Text("No commands yet")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Color(hex: "8b8b8b"))
                                    Text("Add commands to assign them to your pie menu")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: "8b8b8b"))
                                        .multilineTextAlignment(.center)
                                }
                                .padding(40)
                            } else {
                                ForEach(filteredCommands(for: selectedApp)) { command in
                                    FigmaCommandRowView(
                                        command: command,
                                        store: store,
                                        onEdit: {
                                            editingCommand = command
                                            showingEditSheet = true
                                        },
                                        onDelete: {
                                            deleteCommand(command)
                                        },
                                        onDrag: {
                                            let provider = NSItemProvider()
                                            provider.registerObject(NSString(string: command.actionId), visibility: .all)
                                            return provider
                                        }
                                    )
                                    .padding(.horizontal, 12)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 12)
                }
                .frame(height: 454)
            }
            .background(Color(hex: "1b1c1e"))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(hex: "383a3b"), lineWidth: 1)
            )
        }
        .frame(width: 328)
        .sheet(isPresented: $showingEditSheet) {
            if let command = editingCommand {
                EditCommandSheetView(command: command, store: store) { updatedCommand in
                    updateCommand(updatedCommand)
                }
            }
        }
    }
    
    private func filteredCommands(for app: AppProfile) -> [PieCommand] {
        let allCommands = app.availableCommands
        if commandSearchText.isEmpty {
            return allCommands
        }
        return allCommands.filter { $0.label.localizedCaseInsensitiveContains(commandSearchText) }
    }
    
    private func deleteCommand(_ command: PieCommand) {
        guard var app = selectedApp else { return }
        app.availableCommands.removeAll { $0.actionId == command.actionId }
        
        // Also remove from pie slots if assigned
        for (slot, assignedId) in app.pieSlots {
            if assignedId == command.actionId {
                app.pieSlots.removeValue(forKey: slot)
            }
        }
        
        if let index = store.apps.firstIndex(where: { $0.id == app.id }) {
            store.apps[index] = app
            selectedApp = app
            store.save()
            NSLog("✅ Deleted command: \(command.actionId)")
        }
    }
    
    private func updateCommand(_ updatedCommand: PieCommand) {
        guard var app = selectedApp else { return }
        if let cmdIndex = app.availableCommands.firstIndex(where: { $0.actionId == updatedCommand.actionId }) {
            app.availableCommands[cmdIndex] = updatedCommand
            
            if let appIndex = store.apps.firstIndex(where: { $0.id == app.id }) {
                store.apps[appIndex] = app
                selectedApp = app
                store.save()
                NSLog("✅ Updated command: \(updatedCommand.actionId)")
            }
        }
    }
}

private func menuOffsetForSlice(index: Int) -> CGSize {
    // Position floating menu just outside the icon radius at ~120 px
    let angle = Double(index) * 45.0
    let r: CGFloat = 120
    let x = cos(angle * .pi/180) * r
    let y = sin(angle * .pi/180) * r
    return CGSize(width: x, height: y)
}

// MARK: - Edit Command Sheet
struct EditCommandSheetView: View {
    let command: PieCommand
    let store: ConfigurationStore
    let onSave: (PieCommand) -> Void
    
    @State private var label: String
    @State private var selectedIcon: CommandIcon?
    @State private var showingIconPicker = false
    @Environment(\.dismiss) private var dismiss
    
    init(command: PieCommand, store: ConfigurationStore, onSave: @escaping (PieCommand) -> Void) {
        self.command = command
        self.store = store
        self.onSave = onSave
        _label = State(initialValue: command.label)
        _selectedIcon = State(initialValue: command.icon)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Text("Edit Command")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            // Command Label
            VStack(alignment: .leading, spacing: 8) {
                Text("Command Name")
                    .font(.headline)
                TextField("Command name", text: $label)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Icon Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Icon")
                    .font(.headline)
                
                HStack(spacing: 12) {
                    // Current icon preview
                    Group {
                        if let icon = selectedIcon {
                            IconPreview(icon: icon, store: store, size: 48)
                        } else {
                            Image(systemName: "command.circle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 60, height: 60)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    Button("Change Icon") {
                        showingIconPicker = true
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            // Keystroke Display (read-only)
            VStack(alignment: .leading, spacing: 8) {
                Text("Keyboard Shortcut")
                    .font(.headline)
                Text(command.keystrokeDisplay ?? "No shortcut assigned")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            Spacer()
            
            // Action Buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Save") {
                    saveCommand()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(label.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 480, height: 500)
        .sheet(isPresented: $showingIconPicker) {
            IconPickerView(selectedIcon: $selectedIcon, store: store)
        }
    }
    
    private func saveCommand() {
        var updatedCommand = command
        updatedCommand.label = label
        updatedCommand.icon = selectedIcon
        onSave(updatedCommand)
        dismiss()
    }
}

// MARK: - Icon Picker View
struct IconPickerView: View {
    @Binding var selectedIcon: CommandIcon?
    let store: ConfigurationStore
    @Environment(\.dismiss) private var dismiss
    
    private let sfSymbols = [
        "command", "option", "shift", "control", "command.circle", "option.circle",
        "shift.circle", "control.circle", "delete.left", "delete.right",
        "arrow.up", "arrow.down", "arrow.left", "arrow.right",
        "arrowshape.up", "arrowshape.down", "arrowshape.left", "arrowshape.right",
        "pencil", "trash", "folder", "doc", "doc.text", "doc.plaintext",
        "square.and.pencil", "square.and.arrow.up", "square.and.arrow.down",
        "paintbrush", "scissors", "wrench", "hammer", "eyedropper",
        "plus", "minus", "multiply", "divide", "equal",
        "star", "star.fill", "heart", "heart.fill", "flag", "flag.fill",
        "bookmark", "bookmark.fill", "bell", "bell.fill",
        "play", "pause", "stop", "forward", "backward",
        "speaker", "speaker.wave.2", "mic", "mic.fill",
        "camera", "photo", "video", "film",
        "gear", "slider.horizontal.3", "list.bullet", "square.grid.2x2"
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerView
            Divider()
            iconGridView
            doneButton
        }
        .padding(24)
        .frame(width: 600, height: 500)
    }
    
    private var headerView: some View {
        HStack {
            Text("Choose Icon")
                .font(.title2)
                .fontWeight(.semibold)
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var iconGridView: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(60), spacing: 12), count: 8), spacing: 12) {
                ForEach(sfSymbols, id: \.self) { symbol in
                    IconButtonView(symbol: symbol, isSelected: selectedIcon?.name == symbol) {
                        selectedIcon = CommandIcon(kind: .sfSymbol, name: symbol, filename: nil)
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var doneButton: some View {
        Button("Done") {
            dismiss()
        }
        .buttonStyle(.borderedProminent)
        .frame(maxWidth: .infinity)
    }
}

private struct IconButtonView: View {
    let symbol: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Image(systemName: symbol)
                .font(.system(size: 32))
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                .frame(width: 60, height: 60)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Figma Style Components

struct FigmaAppRowView: View {
    let app: AppProfile
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                // App icon using AppIconProvider
                Image(nsImage: AppIconProvider.icon(for: app.bundleIdentifier, size: 40))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 9.836))
                    .shadow(color: .black.opacity(0.1), radius: 2.5, x: 0, y: 1.25)
                    .shadow(color: .black.opacity(0.2), radius: 13.75, x: 0, y: 5)
                
                Text(app.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 9)
            .background(
                isSelected ? Color(hex: "343434") : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct FigmaCommandRowView: View {
    let command: PieCommand
    let store: ConfigurationStore
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onDrag: () -> NSItemProvider
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                // Command Icon
                if let icon = command.icon {
                    IconPreview(icon: icon, store: store, size: 16)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "command.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }
                
                Text(command.label)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            
            Text(command.keystrokeDisplay ?? "No keystroke")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: "383838"))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Spacer()
            
            // Edit and Delete buttons - only show on hover
            if isHovered {
                HStack(spacing: 12) {
                    Button(action: onEdit) {
                        Text("Edit")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "c1c1c1"))
                    }
                    .buttonStyle(.plain)
                    
                    Rectangle()
                        .fill(Color(hex: "8b8b8b"))
                        .frame(width: 0.78, height: 8)
                    
                    Button(action: onDelete) {
                        Text("Delete")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "ff5757"))
                    }
                    .buttonStyle(.plain)
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isHovered ? Color(hex: "303030") : Color(hex: "2a2a2a"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .shadow(color: .black.opacity(0.2), radius: 11, x: 0, y: 4)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onDrag {
            NSLog("🎯 Dragging command: \(command.actionId)")
            return onDrag()
        }
    }
}

struct FigmaPieSliceView: View {
    let index: Int
    let isHovered: Bool
    let command: PieCommand?
    let onDrop: (String) -> Void
    let onDelete: () -> Void
    let store: ConfigurationStore
    @State private var isDropTargeted = false
    
    var body: some View {
        let angle = Double(index) * 45.0 // 8 slices, 45 degrees each
        let startAngle = Angle.degrees(angle - 22.5)
        let endAngle = Angle.degrees(angle + 22.5)
        let radians = angle * .pi / 180.0
        let iconRadius: CGFloat = 100 // Distance from center for icon placement
        let pieSize: CGFloat = 337
        let center = CGPoint(x: pieSize / 2, y: pieSize / 2)
        
        ZStack {
            // Pie slice shape with interaction
            PieSliceShape(startAngle: startAngle, endAngle: endAngle, innerRadius: 30, outerRadius: pieSize / 2)
                .fill(
                    isDropTargeted ? Color.blue.opacity(0.3) :
                    isHovered ? Color(hex: "3a3a3a") :
                    Color.clear // Use clear so slices don't overlap visually
                )
                .overlay(
                    PieSliceShape(startAngle: startAngle, endAngle: endAngle, innerRadius: 30, outerRadius: pieSize / 2)
                        .stroke(
                            isDropTargeted ? Color.blue :
                            isHovered ? Color(hex: "505050") :
                            Color(hex: "383838"),
                            lineWidth: isDropTargeted ? 2 : 1
                        )
                )
                .contentShape(PieSliceShape(startAngle: startAngle, endAngle: endAngle, innerRadius: 30, outerRadius: pieSize / 2))
                // Per-slice onDrop removed; global delegate handles precise targeting
                .contextMenu {
                    if command != nil {
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("Remove Command", systemImage: "trash")
                        }
                    }
                }
            
            // Icon positioned in the center of the slice
            Group {
                if let command = command {
                    if let icon = command.icon {
                        IconPreview(icon: icon, store: store, size: 28)
                    } else {
                        Image(systemName: "command.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    }
                } else {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 28))
                        .foregroundColor(isHovered ? Color(hex: "8b8b8b") : Color(hex: "505050"))
                }
            }
            .position(
                x: center.x + cos(radians) * iconRadius,
                y: center.y + sin(radians) * iconRadius
            )
            .allowsHitTesting(false)

            // Inline delete button placed slightly outside the icon radius for assigned commands
            if command != nil {
                Button(action: {
                    onDelete()
                }) {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                }
                .buttonStyle(.plain)
                .position(
                    x: center.x + cos(radians) * (iconRadius + 22),
                    y: center.y + sin(radians) * (iconRadius + 22)
                )
            }
        }
    }
    
    // Drop handling is managed by the parent via DropDelegate
}

// MARK: - Floating Menu for slice actions
private struct FloatingSliceMenu: View {
    let onReplace: () -> Void
    let onDelete: () -> Void
    var body: some View {
        VStack(spacing: 8) {
            Button(action: onReplace) {
                Label("Replace", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(Color(hex: "1b1b1c"))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "2a2a2a"), lineWidth: 1))
            
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(Color(hex: "1b1b1c"))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "2a2a2a"), lineWidth: 1))
        }
        .padding(8)
        .background(Color.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Command Picker Sheet
private struct CommandPickerSheet: View {
    let commands: [PieCommand]
    let store: ConfigurationStore
    let onSelect: (PieCommand) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search: String = ""
    var filtered: [PieCommand] { search.isEmpty ? commands : commands.filter { $0.label.localizedCaseInsensitiveContains(search) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Choose Command")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.bottom, 4)
            TextField("Search", text: $search)
                .textFieldStyle(.roundedBorder)
            List(filtered, id: \.actionId) { cmd in
                HStack(spacing: 10) {
                    if let icon = cmd.icon { IconPreview(icon: icon, store: store, size: 18) }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cmd.label)
                        if let ks = cmd.keystrokeDisplay { Text(ks).foregroundColor(.secondary).font(.caption) }
                    }
                    Spacer()
                    Button("Select") {
                        onSelect(cmd)
                        dismiss()
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(minHeight: 300)
        }
        .padding(16)
        .frame(width: 420, height: 420)
    }
}

struct PieSliceShape: Shape {
    let startAngle: Angle
    let endAngle: Angle
    var innerRadius: CGFloat = 0
    var outerRadius: CGFloat? = nil
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = outerRadius ?? min(rect.width, rect.height) / 2
        let inner = innerRadius
        
        // Start at inner radius
        let startPoint = CGPoint(
            x: center.x + inner * cos(CGFloat(startAngle.radians)),
            y: center.y + inner * sin(CGFloat(startAngle.radians))
        )
        path.move(to: startPoint)
        
        // Line to outer radius at start angle
        let outerStartPoint = CGPoint(
            x: center.x + outer * cos(CGFloat(startAngle.radians)),
            y: center.y + outer * sin(CGFloat(startAngle.radians))
        )
        path.addLine(to: outerStartPoint)
        
        // Arc along outer radius
        path.addArc(center: center, radius: outer, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        
        // Line back to inner radius at end angle
        let innerEndPoint = CGPoint(
            x: center.x + inner * cos(CGFloat(endAngle.radians)),
            y: center.y + inner * sin(CGFloat(endAngle.radians))
        )
        path.addLine(to: innerEndPoint)
        
        // Arc along inner radius (backwards)
        if inner > 0 {
            path.addArc(center: center, radius: inner, startAngle: endAngle, endAngle: startAngle, clockwise: true)
        }
        
        path.closeSubpath()
        return path
    }
}

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}