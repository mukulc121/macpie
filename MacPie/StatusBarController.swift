import AppKit

final class StatusBarController {
    private var statusItem: NSStatusItem!
    private let onTogglePie: () -> Void
    private var onOpenPreferences: (() -> Void)?

    init(onTogglePie: @escaping () -> Void, onOpenPreferences: (() -> Void)? = nil) {
        self.onTogglePie = onTogglePie
        self.onOpenPreferences = onOpenPreferences
        setup()
    }

    private func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Create a custom pie chart icon
        if let button = statusItem.button {
            button.image = createPieIcon()
            button.image?.isTemplate = true // Make it adapt to dark/light mode
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Toggle Pie", action: #selector(togglePie), keyEquivalent: "p"))
        menu.addItem(NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit MacPie", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }
    
    private func createPieIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // Scale from 24x24 viewBox to 18x18
        let scale: CGFloat = 18.0 / 24.0
        let transform = NSAffineTransform()
        transform.scale(by: scale)
        transform.concat()
        
        NSColor.black.setFill()
        NSColor.black.setStroke()
        
        // Path 1: Filled pie segment with opacity
        // M12 22C17.5228 22 22 17.5228 22 12C22 6.47715 17.5228 2 12 2C6.47715 2 2 6.47715 2 12H7C7 9.23858 9.23858 7 12 7C14.7614 7 17 9.23858 17 12C17 14.7614 14.7614 17 12 17V22Z
        let pieSegment = NSBezierPath()
        pieSegment.move(to: NSPoint(x: 12, y: 24 - 22))
        pieSegment.appendArc(withCenter: NSPoint(x: 12, y: 24 - 12), radius: 10, startAngle: 270, endAngle: 90, clockwise: true)
        pieSegment.appendArc(withCenter: NSPoint(x: 12, y: 24 - 12), radius: 10, startAngle: 90, endAngle: 0, clockwise: true)
        pieSegment.line(to: NSPoint(x: 7, y: 24 - 12))
        pieSegment.appendArc(withCenter: NSPoint(x: 12, y: 24 - 12), radius: 5, startAngle: 180, endAngle: 270, clockwise: true)
        pieSegment.appendArc(withCenter: NSPoint(x: 12, y: 24 - 12), radius: 5, startAngle: 270, endAngle: 0, clockwise: false)
        pieSegment.line(to: NSPoint(x: 12, y: 24 - 22))
        pieSegment.close()
        
        NSColor.black.withAlphaComponent(0.4).setFill()
        pieSegment.fill()
        
        // Path 2: Outer circle (stroke only)
        let outerCircle = NSBezierPath()
        outerCircle.appendArc(withCenter: NSPoint(x: 12, y: 24 - 12), radius: 10, startAngle: 0, endAngle: 360)
        outerCircle.lineWidth = 2.0
        NSColor.black.setStroke()
        outerCircle.stroke()
        
        // Path 3: Inner circle (stroke only)
        let innerCircle = NSBezierPath()
        innerCircle.appendArc(withCenter: NSPoint(x: 12, y: 24 - 12), radius: 5, startAngle: 0, endAngle: 360)
        innerCircle.lineWidth = 2.0
        innerCircle.stroke()
        
        // Path 4: Horizontal line from center to left
        let horizontalLine = NSBezierPath()
        horizontalLine.move(to: NSPoint(x: 7, y: 24 - 12))
        horizontalLine.line(to: NSPoint(x: 2, y: 24 - 12))
        horizontalLine.lineWidth = 2.0
        horizontalLine.lineCapStyle = .round
        horizontalLine.stroke()
        
        // Path 5: Vertical line from center to bottom
        let verticalLine = NSBezierPath()
        verticalLine.move(to: NSPoint(x: 12, y: 24 - 17))
        verticalLine.line(to: NSPoint(x: 12, y: 24 - 22))
        verticalLine.lineWidth = 2.0
        verticalLine.lineCapStyle = .round
        verticalLine.lineJoinStyle = .round
        verticalLine.stroke()
        
        image.unlockFocus()
        
        return image
    }

    @objc private func togglePie() { onTogglePie() }
    @objc private func openPreferences() { onOpenPreferences?() }
    @objc private func quit() { NSApp.terminate(nil) }
} 