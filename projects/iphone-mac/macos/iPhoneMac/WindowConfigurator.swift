import AppKit
import SwiftUI

struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { configure(view.window) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { configure(view.window) }
    }

    private func configure(_ window: NSWindow?) {
        iPhoneMacAppDelegate.configure(window)
    }
}

/// Adds explicit drag and resize affordances to the otherwise borderless
/// iPhone-shaped window. Only the outer 12 points and the top grab strip
/// receive events; the mirrored screen and the Home button remain interactive.
struct WindowChromeOverlay: NSViewRepresentable {
    func makeNSView(context: Context) -> BorderlessWindowChromeView {
        BorderlessWindowChromeView()
    }

    func updateNSView(_ view: BorderlessWindowChromeView, context: Context) {}
}

final class BorderlessWindowChromeView: NSView {
    private struct Edges: OptionSet {
        let rawValue: Int
        static let left = Edges(rawValue: 1 << 0)
        static let right = Edges(rawValue: 1 << 1)
        static let bottom = Edges(rawValue: 1 << 2)
        static let top = Edges(rawValue: 1 << 3)
    }

    private let resizeMargin: CGFloat = 20
    private let dragStripHeight: CGFloat = 38
    private let aspect: CGFloat = 410 / 850
    private var activeEdges: Edges = []
    private var isMoving = false
    private var initialFrame = NSRect.zero
    private var initialMouse = NSPoint.zero

    override var isOpaque: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Tiny, low-contrast affordances: visible enough to make a borderless
        // window discoverable without reintroducing a surrounding panel.
        NSColor.white.withAlphaComponent(0.24).setFill()
        NSBezierPath(
            roundedRect: NSRect(x: bounds.midX - 23, y: bounds.maxY - 11, width: 46, height: 4),
            xRadius: 2,
            yRadius: 2
        ).fill()

        let corner = NSBezierPath()
        corner.move(to: NSPoint(x: bounds.maxX - 17, y: 5))
        corner.line(to: NSPoint(x: bounds.maxX - 5, y: 5))
        corner.line(to: NSPoint(x: bounds.maxX - 5, y: 17))
        corner.lineWidth = 2
        corner.lineCapStyle = .round
        corner.lineJoinStyle = .round
        NSColor.white.withAlphaComponent(0.28).setStroke()
        corner.stroke()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let edges = resizeEdges(at: point)
        if !edges.isEmpty || point.y >= bounds.maxY - dragStripHeight {
            return self
        }
        return nil
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        activeEdges = resizeEdges(at: point)
        guard let window else { return }
        initialFrame = window.frame
        initialMouse = NSEvent.mouseLocation
        isMoving = activeEdges.isEmpty
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let mouse = NSEvent.mouseLocation
        let dx = mouse.x - initialMouse.x
        let dy = mouse.y - initialMouse.y

        if isMoving {
            window.setFrameOrigin(NSPoint(x: initialFrame.minX + dx, y: initialFrame.minY + dy))
            return
        }

        guard !activeEdges.isEmpty else { return }

        var candidates: [CGFloat] = []
        if activeEdges.contains(.right) { candidates.append(initialFrame.width + dx) }
        if activeEdges.contains(.left) { candidates.append(initialFrame.width - dx) }
        if activeEdges.contains(.top) { candidates.append((initialFrame.height + dy) * aspect) }
        if activeEdges.contains(.bottom) { candidates.append((initialFrame.height - dy) * aspect) }

        guard var width = candidates.max(by: {
            abs($0 - initialFrame.width) < abs($1 - initialFrame.width)
        }) else { return }
        width = min(max(width, 250), 700)
        let height = width / aspect

        var origin = initialFrame.origin
        if activeEdges.contains(.left) {
            origin.x = initialFrame.maxX - width
        } else if !activeEdges.contains(.right) {
            origin.x = initialFrame.midX - width / 2
        }
        if activeEdges.contains(.bottom) {
            origin.y = initialFrame.maxY - height
        } else if !activeEdges.contains(.top) {
            origin.y = initialFrame.midY - height / 2
        }

        window.setFrame(NSRect(origin: origin, size: NSSize(width: width, height: height)), display: true)
    }

    override func mouseUp(with event: NSEvent) {
        activeEdges = []
        isMoving = false
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(NSRect(x: 0, y: resizeMargin, width: resizeMargin, height: bounds.height - 2 * resizeMargin), cursor: .resizeLeftRight)
        addCursorRect(NSRect(x: bounds.width - resizeMargin, y: resizeMargin, width: resizeMargin, height: bounds.height - 2 * resizeMargin), cursor: .resizeLeftRight)
        addCursorRect(NSRect(x: resizeMargin, y: 0, width: bounds.width - 2 * resizeMargin, height: resizeMargin), cursor: .resizeUpDown)
        addCursorRect(NSRect(x: resizeMargin, y: bounds.height - resizeMargin, width: bounds.width - 2 * resizeMargin, height: resizeMargin), cursor: .resizeUpDown)
        addCursorRect(NSRect(x: resizeMargin, y: bounds.height - dragStripHeight, width: bounds.width - 2 * resizeMargin, height: dragStripHeight - resizeMargin), cursor: .openHand)
    }

    private func resizeEdges(at point: NSPoint) -> Edges {
        var edges: Edges = []
        if point.x <= resizeMargin { edges.insert(.left) }
        if point.x >= bounds.maxX - resizeMargin { edges.insert(.right) }
        if point.y <= resizeMargin { edges.insert(.bottom) }
        if point.y >= bounds.maxY - resizeMargin { edges.insert(.top) }
        return edges
    }
}

struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> BorderlessWindowDragHandleView {
        BorderlessWindowDragHandleView()
    }
    func updateNSView(_ view: BorderlessWindowDragHandleView, context: Context) {}
}

final class BorderlessWindowDragHandleView: NSView {
    private var initialFrame = NSRect.zero
    private var initialMouse = NSPoint.zero

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.secondaryLabelColor.withAlphaComponent(0.42).setFill()
        NSBezierPath(
            roundedRect: NSRect(x: bounds.midX - 25, y: bounds.midY - 2, width: 50, height: 4),
            xRadius: 2,
            yRadius: 2
        ).fill()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        initialFrame = window.frame
        initialMouse = NSEvent.mouseLocation
        NSCursor.closedHand.set()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let mouse = NSEvent.mouseLocation
        window.setFrameOrigin(NSPoint(
            x: initialFrame.minX + mouse.x - initialMouse.x,
            y: initialFrame.minY + mouse.y - initialMouse.y
        ))
    }

    override func mouseUp(with event: NSEvent) {
        NSCursor.openHand.set()
    }
}

struct WindowResizeHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> BorderlessWindowResizeHandleView {
        BorderlessWindowResizeHandleView()
    }
    func updateNSView(_ view: BorderlessWindowResizeHandleView, context: Context) {}
}

final class BorderlessWindowResizeHandleView: NSView {
    private let aspect: CGFloat = 410 / 850
    private var initialFrame = NSRect.zero
    private var initialMouse = NSPoint.zero

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: bounds.maxX - 20, y: 7))
        path.line(to: NSPoint(x: bounds.maxX - 7, y: 7))
        path.line(to: NSPoint(x: bounds.maxX - 7, y: 20))
        path.lineWidth = 2.5
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        NSColor.secondaryLabelColor.withAlphaComponent(0.52).setStroke()
        path.stroke()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        initialFrame = window.frame
        initialMouse = NSEvent.mouseLocation
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let mouse = NSEvent.mouseLocation
        let dx = mouse.x - initialMouse.x
        let dy = mouse.y - initialMouse.y
        let horizontalWidth = initialFrame.width + dx
        let verticalWidth = (initialFrame.height - dy) * aspect
        var width = abs(horizontalWidth - initialFrame.width) >= abs(verticalWidth - initialFrame.width)
            ? horizontalWidth : verticalWidth
        width = min(max(width, 250), 700)
        let height = width / aspect
        let origin = NSPoint(x: initialFrame.minX, y: initialFrame.maxY - height)
        window.setFrame(NSRect(origin: origin, size: NSSize(width: width, height: height)), display: true)
    }
}
