import SwiftUI
import AppKit

struct HoverTrackingView: NSViewRepresentable {
    final class TrackingNSView: NSView {
        var onMove: ((CGPoint) -> Void)?
        var trackingArea: NSTrackingArea?

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let trackingArea { removeTrackingArea(trackingArea) }
            let options: NSTrackingArea.Options = [.mouseMoved, .activeAlways, .inVisibleRect]
            let area = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
            addTrackingArea(area)
            trackingArea = area
        }

        override func mouseMoved(with event: NSEvent) {
            super.mouseMoved(with: event)
            let loc = convert(event.locationInWindow, from: nil)
            onMove?(loc)
        }
    }

    let onMove: (CGPoint, CGSize) -> Void

    func makeNSView(context: Context) -> TrackingNSView {
        let v = TrackingNSView()
        v.onMove = { point in
            onMove(point, v.bounds.size)
        }
        return v
    }

    func updateNSView(_ nsView: TrackingNSView, context: Context) {
        // no-op
    }
} 