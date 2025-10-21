import SwiftUI
import AppKit

struct PieSlice: Identifiable {
	let id = UUID()
	let index: Int
	let label: String
	var iconName: String? = nil // SF Symbol
	var keystrokeDisplay: String? = nil
	var nsImage: NSImage? = nil // custom image, if any
}

struct PieOverlayView: View {
	let slices: [PieSlice]
	let onSelect: (Int) -> Void
	let onHoverChanged: (Int?) -> Void

	@State private var hoveredIndex: Int? = nil
    private let size: CGFloat = 300

	var body: some View {
		ZStack {
			ForEach(slices) { slice in
				segment(for: slice)
			}
			// Removed center circle to show icons properly
            
            // Show command name in center when hovering
            if let hoveredIndex = hoveredIndex, 
               hoveredIndex < slices.count,
               !slices[hoveredIndex].label.isEmpty {
                VStack(spacing: 4) {
                    Text(slices[hoveredIndex].label)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    if let keystroke = slices[hoveredIndex].keystrokeDisplay {
                        Text(keystroke)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .allowsHitTesting(false)
            }
            
            MouseTracker { point in
                updateHover(point: point)
            }
		}
        .frame(width: size, height: size)
		.background(Color.clear)
		.onTapGesture { if let hoveredIndex { onSelect(hoveredIndex) } }
		.onKeyPress { key in if let i = Int(key), (1...slices.count).contains(i) { onSelect(i - 1) } }
		.onChange(of: hoveredIndex) { _, newVal in onHoverChanged(newVal) }
	}

	private func segment(for slice: PieSlice) -> some View {
		let anglePer = 360.0 / Double(slices.count)
		let start = Angle(degrees: Double(slice.index) * anglePer - anglePer / 2)
		let end = Angle(degrees: Double(slice.index + 1) * anglePer - anglePer / 2)
		let shape = PieShape(startAngle: start, endAngle: end)
		let isHovered = hoveredIndex == slice.index
		
		// Slice creation for index \(slice.index)
		
		return ZStack {
			shape
				.fill(isHovered ? Color.accentColor.opacity(0.3) : Color.black.opacity(0.25))
				.overlay(shape.stroke(isHovered ? Color.accentColor.opacity(0.6) : Color.white.opacity(0.2), lineWidth: isHovered ? 2 : 1))
                .contentShape(shape)

			// Icon positioned in the center of the slice
			Group {
				if let img = slice.nsImage {
					Image(nsImage: img)
						.resizable()
						.aspectRatio(contentMode: .fit)
						.frame(width: 28, height: 28)
						.foregroundStyle(.white)
				} else if let icon = slice.iconName, !icon.isEmpty {
					Image(systemName: icon)
						.font(.system(size: 24, weight: .semibold))
						.foregroundStyle(.white)
				}
			}
			.offset(x: 75) // Position icon further out for better visibility
			.rotationEffect(.degrees(Double(slice.index) * anglePer + anglePer / 2)) // Rotate to center of slice

			// No labels or keystroke badges — icon only
		}
	}

	private func updateHover(point: CGPoint) {
		let center = CGPoint(x: size / 2, y: size / 2)
		let dx = Double(point.x - center.x)
		let dy = Double(point.y - center.y)
		let r = sqrt(dx*dx + dy*dy)
		let outer = Double(size / 2)
		let inner = outer * 0.4
		
		// Check if point is within the pie ring
		guard r >= inner && r <= outer else { 
			hoveredIndex = nil
			return 
		}
		
		// Calculate angle from center (0° = right, 90° = up, 180° = left, 270° = down)
		var angle = atan2(-dy, dx) * 180.0 / .pi // Negative dy because Y increases downward in SwiftUI
		
		// Convert to 0-360 range
		if angle < 0 { 
			angle += 360 
		}
		
		// Calculate which slice this angle corresponds to
		let anglePer = 360.0 / Double(slices.count)
		let sliceIndex = Int(floor(angle / anglePer)) % slices.count
		
		// Ensure index is within bounds
		hoveredIndex = sliceIndex >= 0 && sliceIndex < slices.count ? sliceIndex : nil
		
		// Debug logging
		NSLog("Mouse at (%.1f, %.1f), angle: %.1f°, slice: %d, hoveredIndex: %@", 
			  point.x, point.y, angle, sliceIndex, hoveredIndex?.description ?? "nil")
	}
}

struct PieShape: Shape {
	var startAngle: Angle
	var endAngle: Angle

	func path(in rect: CGRect) -> Path {
		var path = Path()
		let center = CGPoint(x: rect.midX, y: rect.midY)
		let radiusOuter = min(rect.width, rect.height) / 2
		let radiusInner = radiusOuter * 0.2
		path.addArc(center: center, radius: radiusOuter, startAngle: startAngle, endAngle: endAngle, clockwise: false)
		path.addArc(center: center, radius: radiusInner, startAngle: endAngle, endAngle: startAngle, clockwise: true)
		path.closeSubpath()
		return path
	}
}

private struct MouseTracker: NSViewRepresentable {
    let onMove: (CGPoint) -> Void
    func makeNSView(context: Context) -> NSView {
        let v = TrackingView()
        v.onMove = onMove
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
    final class TrackingView: NSView {
        var onMove: ((CGPoint) -> Void)?
        override init(frame frameRect: NSRect) { super.init(frame: frameRect); addTracking() }
        required init?(coder: NSCoder) { super.init(coder: coder); addTracking() }
        private func addTracking() {
            window?.acceptsMouseMovedEvents = true
            updateTrackingAreas()
        }
        override func mouseMoved(with event: NSEvent) {
            let windowLocation = event.locationInWindow
            let viewLocation = convert(windowLocation, from: nil)
            onMove?(viewLocation)
            
            // Debug logging for mouse movement
            NSLog("Mouse moved: window(%.1f, %.1f) -> view(%.1f, %.1f)", 
                  windowLocation.x, windowLocation.y, viewLocation.x, viewLocation.y)
        }
        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            
            // Remove existing tracking areas
            for area in trackingAreas {
                removeTrackingArea(area)
            }
            
            // Add new tracking area for the entire view
            let trackingArea = NSTrackingArea(
                rect: bounds,
                options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited],
                owner: self,
                userInfo: nil
            )
            addTrackingArea(trackingArea)
            
            window?.acceptsMouseMovedEvents = true
            
            NSLog("Tracking areas updated: bounds=%@, trackingAreas.count=%d", 
                  NSStringFromRect(bounds), trackingAreas.count)
        }
    }
}

private struct KeyPressModifier: ViewModifier {
	let onKey: (String) -> Void
	func body(content: Content) -> some View { content.background(KeyPressRepresentable(onKey: onKey)) }
}

private struct KeyPressRepresentable: NSViewRepresentable {
	let onKey: (String) -> Void
	func makeNSView(context: Context) -> NSView { KeyView(onKey: onKey) }
	func updateNSView(_ nsView: NSView, context: Context) {}

	final class KeyView: NSView {
		let onKey: (String) -> Void
		init(onKey: @escaping (String) -> Void) { self.onKey = onKey; super.init(frame: .zero) }
		required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
		override var acceptsFirstResponder: Bool { true }
		override func keyDown(with event: NSEvent) { if let chars = event.characters { onKey(chars) } }
	}
}

extension View { func onKeyPress(_ onKey: @escaping (String) -> Void) -> some View { modifier(KeyPressModifier(onKey: onKey)) } }

final class PieOverlayController: NSWindowController {
	private var hosting: NSHostingView<PieOverlayView>?

	init(slices: [PieSlice], onSelect: @escaping (Int) -> Void, onHoverChanged: @escaping (Int?) -> Void) {
		let view = PieOverlayView(slices: slices, onSelect: onSelect, onHoverChanged: onHoverChanged)
		let hosting = NSHostingView(rootView: view)
		self.hosting = hosting

		let window = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 300),
							 styleMask: [.nonactivatingPanel, .borderless],
							 backing: .buffered, defer: false)
		window.level = .statusBar
		window.isOpaque = false
		window.backgroundColor = .clear
		window.hasShadow = false
		window.hidesOnDeactivate = false
		window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
		window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true
		window.isMovableByWindowBackground = false
		window.contentView = hosting

		super.init(window: window)
	}

	required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

	func showCenteredAtMouse() {
		guard let window = window else { return }
		let mouse = NSEvent.mouseLocation
		let frame = window.frame
		let origin = CGPoint(x: mouse.x - frame.width / 2, y: mouse.y - frame.height / 2)
		window.setFrameOrigin(origin)
		window.orderFront(nil)
	}

	func hide() { window?.orderOut(nil) }
} 