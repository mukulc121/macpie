import SwiftUI
import AppKit

class SplashScreenController: ObservableObject {
    private var splashWindow: NSWindow?
    @Published var isShowing = false
    
    func showSplash() {
        guard splashWindow == nil else { return }
        
        // Create the splash window
        let splashView = SplashScreenView()
        let hostingView = NSHostingView(rootView: splashView)
        
        splashWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        guard let window = splashWindow else { return }
        
        // Configure window
        window.contentView = hostingView
        window.backgroundColor = NSColor(hex: "222425")
        window.isOpaque = false
        window.hasShadow = true
        window.level = .floating
        window.center()
        
        // Show window
        window.makeKeyAndOrderFront(nil)
        isShowing = true
        
        // Hide splash screen after 4 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            self.hideSplash()
        }
    }
    
    func hideSplash() {
        guard let window = splashWindow else { return }
        
        // Animate out
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.5
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = 0.0
        }) {
            window.close()
            self.splashWindow = nil
            self.isShowing = false
        }
    }
}

// Extension to create NSColor from hex
extension NSColor {
    convenience init(hex: String) {
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
            srgbRed: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            alpha: Double(a) / 255
        )
    }
}
