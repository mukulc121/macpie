import Foundation
import Combine
import Carbon
import AppKit

struct CommandIcon: Identifiable, Codable {
	var id: String { (kind == .sfSymbol ? (name ?? "symbol") : (filename ?? "custom")) }
	enum Kind: String, Codable { case sfSymbol, custom }
	var kind: Kind
	var name: String? // SF Symbol name
	var filename: String? // stored in icons directory
}

struct PieCommand: Identifiable, Codable {
	var id: String { actionId }
	let actionId: String
	var label: String
	var definition: ActionDefinition // execution details
	var icon: CommandIcon? = nil

	var keystrokeDisplay: String? {
		guard definition.type == .keystroke, let ks = definition.keystroke else { return nil }
		return formatKeystroke(keyCode: ks.keyCode, modifiers: ks.modifiers)
	}
}

struct AppProfile: Identifiable, Codable {
	var id: String { bundleIdentifier }
	let name: String
	let bundleIdentifier: String
	var availableCommands: [PieCommand]
	var pieSlots: [Int: String] // slot index -> actionId
}

final class ConfigurationStore: ObservableObject {
	@Published var general = GeneralSettings()
	@Published var apps: [AppProfile] = []

	private let baseURL: URL
	private var appsDir: URL { baseURL.appendingPathComponent("config/apps", isDirectory: true) }
	private var generalURL: URL { baseURL.appendingPathComponent("config/general.json") }
	private var iconsDir: URL { baseURL.appendingPathComponent("icons", isDirectory: true) }

	init(baseFolder: URL? = nil) {
		if let baseFolder { self.baseURL = baseFolder } else {
			self.baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
				.appendingPathComponent("MacPie", isDirectory: true)
		}
		try? FileManager.default.createDirectory(at: appsDir, withIntermediateDirectories: true)
		try? FileManager.default.createDirectory(at: iconsDir, withIntermediateDirectories: true)
		load()
	}

	func load() {
		// General - ensure defaults are used if loading fails
		if let data = try? Data(contentsOf: generalURL), let decoded = try? JSONDecoder().decode(GeneralSettings.self, from: data) {
			general = decoded
		} else {
			// Reset to defaults if loading fails
			general = GeneralSettings()
			NSLog("MacPie: Failed to load general settings, using defaults")
		}

		// Apps
		if let files = try? FileManager.default.contentsOfDirectory(at: appsDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
			var loaded: [AppProfile] = []
			for url in files where url.pathExtension.lowercased() == "json" {
				if let data = try? Data(contentsOf: url), let app = try? JSONDecoder().decode(AppProfile.self, from: data) {
					loaded.append(app)
				}
			}
			if !loaded.isEmpty { apps = loaded }
		}

		// Ensure Figma is always available with proper icons
		if !apps.contains(where: { $0.bundleIdentifier == "com.figma.Desktop" }) {
			let figma = AppProfile(
				name: "Figma",
				bundleIdentifier: "com.figma.Desktop",
				availableCommands: [
					.init(actionId: "copy", label: "Copy", definition: .init(type: .keystroke, keystroke: .init(keyCode: UInt32(kVK_ANSI_C), modifiers: UInt32(cmdKey)), menuItem: nil), icon: .init(kind: .sfSymbol, name: "doc.on.doc", filename: nil)),
					.init(actionId: "paste", label: "Paste", definition: .init(type: .keystroke, keystroke: .init(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey)), menuItem: nil), icon: .init(kind: .sfSymbol, name: "clipboard", filename: nil)),
					.init(actionId: "pasteReplace", label: "Paste to Replace", definition: .init(type: .menuItem, keystroke: nil, menuItem: .init(menuPath: ["Edit", "Paste to Replace"])), icon: .init(kind: .sfSymbol, name: "arrow.triangle.2.circlepath", filename: nil)),
					.init(actionId: "createComponent", label: "Create Component", definition: .init(type: .keystroke, keystroke: .init(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(optionKey | cmdKey)), menuItem: nil), icon: .init(kind: .sfSymbol, name: "square.stack.3d.up", filename: nil))
				],
				pieSlots: [0: "copy", 1: "paste", 2: "pasteReplace", 3: "createComponent"]
			)
			apps.append(figma)
			save()
		}
	}

	func save() {
		do {
			try FileManager.default.createDirectory(at: appsDir, withIntermediateDirectories: true)
			let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
			// General
			let g = try enc.encode(general)
			try g.write(to: generalURL, options: .atomic)
			// Apps
			for app in apps {
				let url = appsDir.appendingPathComponent("\(app.bundleIdentifier).json")
				let data = try enc.encode(app)
				try data.write(to: url, options: .atomic)
			}
		} catch {
			NSLog("MacPie: save error: %@", error.localizedDescription)
		}
	}

	func image(for icon: CommandIcon?) -> NSImage? {
		guard let icon else { return nil }
		switch icon.kind {
		case .sfSymbol:
			return nil // use SF Symbol in SwiftUI directly
		case .custom:
			guard let filename = icon.filename else { return nil }
			let url = iconsDir.appendingPathComponent(filename)
			return NSImage(contentsOf: url)
		}
	}

	func saveCustomIcon(from sourceURL: URL) -> String? {
		let ext = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension
		let base = sourceURL.deletingPathExtension().lastPathComponent.replacingOccurrences(of: " ", with: "-")
		let unique = "\(base)-\(UUID().uuidString.prefix(8)).\(ext)"
		let dest = iconsDir.appendingPathComponent(unique)
		do {
			if FileManager.default.fileExists(atPath: dest.path) {
				try FileManager.default.removeItem(at: dest)
			}
			try FileManager.default.copyItem(at: sourceURL, to: dest)
			return unique
		} catch {
			NSLog("MacPie: saveCustomIcon error: %@", error.localizedDescription)
			return nil
		}
	}
}

struct GeneralSettings: Codable {
	var hotkeyKeyCode: UInt32 = UInt32(kVK_ANSI_P) // 'P'
	var hotkeyModifiers: UInt32 = UInt32(cmdKey | shiftKey)
	var launchAtLogin: Bool = false
	var appVersion: String = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
}

func formatKeystroke(keyCode: UInt32, modifiers: UInt32) -> String {
	var parts: [String] = []
	if (modifiers & UInt32(cmdKey)) != 0 { parts.append("⌘") }
	if (modifiers & UInt32(shiftKey)) != 0 { parts.append("⇧") }
	if (modifiers & UInt32(optionKey)) != 0 { parts.append("⌥") }
	if (modifiers & UInt32(controlKey)) != 0 { parts.append("⌃") }
	parts.append(keyCodeToLabel(keyCode))
	return parts.joined()
}

private func keyCodeToLabel(_ keyCode: UInt32) -> String {
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