import AppKit
import SwiftUI

struct PhoneInteractionView: NSViewRepresentable {
    let controls: ControlClient

    func makeNSView(context: Context) -> InteractionCaptureView {
        let view = InteractionCaptureView()
        configure(view)
        return view
    }

    func updateNSView(_ view: InteractionCaptureView, context: Context) {
        configure(view)
    }

    private func configure(_ view: InteractionCaptureView) {
        view.onTap = { point, size in controls.tap(at: point, in: size) }
        view.onLongPress = { point, size, duration in
            controls.longPress(at: point, in: size, duration: duration)
        }
        view.onSwipe = { start, end, size in controls.swipe(from: start, to: end, in: size) }
        view.onKeys = { keys in controls.sendKeys(keys) }
        view.onText = { text in controls.send("type", text: text) }
    }
}

final class InteractionCaptureView: NSView {
    var onTap: ((CGPoint, CGSize) -> Void)?
    var onLongPress: ((CGPoint, CGSize, Double) -> Void)?
    var onSwipe: ((CGPoint, CGPoint, CGSize) -> Void)?
    var onKeys: (([[String: Any]]) -> Void)?
    var onText: ((String) -> Void)?

    private var dragStart: CGPoint?
    private var mouseDownTime: TimeInterval = 0
    private var tracking: NSTrackingArea?
    private var lastScrollTime: TimeInterval = 0
    private var lastHorizontalSwipeTime: TimeInterval = 0
    private var horizontalScrollTotal: CGFloat = 0
    private var horizontalSwipeSent = false
    private var pendingText = ""
    private var pendingTextWorkItem: DispatchWorkItem?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking = tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.pointingHand.push()
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.pop()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        dragStart = convert(event.locationInWindow, from: nil)
        mouseDownTime = ProcessInfo.processInfo.systemUptime
    }

    override func mouseUp(with event: NSEvent) {
        guard let start = dragStart else { return }
        dragStart = nil
        let end = convert(event.locationInWindow, from: nil)
        if hypot(end.x - start.x, end.y - start.y) < 7 {
            let heldFor = ProcessInfo.processInfo.systemUptime - mouseDownTime
            if heldFor >= 0.42 {
                onLongPress?(end, bounds.size, heldFor)
            } else {
                onTap?(end, bounds.size)
            }
        } else {
            onSwipe?(start, end, bounds.size)
        }
    }

    override func scrollWheel(with event: NSEvent) {
        let now = ProcessInfo.processInfo.systemUptime
        // Match Apple's shortcut: Shift + a normal vertical scroll becomes a
        // horizontal page swipe on iPhone.
        let shiftHorizontal = event.modifierFlags.contains(.shift) && abs(event.scrollingDeltaY) > 0.1
        let horizontal = shiftHorizontal || abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) * 1.15

        if horizontal {
            let isUnphased = event.phase.isEmpty && event.momentumPhase.isEmpty
            if isUnphased {
                guard now - lastHorizontalSwipeTime > 0.32 else { return }
                lastHorizontalSwipeTime = now
                sendHorizontalSwipe(delta: shiftHorizontal ? event.scrollingDeltaY : event.scrollingDeltaX, at: event)
                return
            }

            if event.phase == .began || event.phase == .mayBegin {
                horizontalScrollTotal = 0
                horizontalSwipeSent = false
            }
            horizontalScrollTotal += shiftHorizontal ? event.scrollingDeltaY : event.scrollingDeltaX

            let threshold: CGFloat = event.hasPreciseScrollingDeltas ? 7 : 0.5
            if !horizontalSwipeSent, abs(horizontalScrollTotal) >= threshold {
                sendHorizontalSwipe(delta: horizontalScrollTotal, at: event)
                horizontalSwipeSent = true
            }

            if event.phase == .ended || event.phase == .cancelled || event.momentumPhase == .ended {
                horizontalScrollTotal = 0
                horizontalSwipeSent = false
            }
            return
        }

        guard now - lastScrollTime > 0.075 else { return }
        lastScrollTime = now

        let location = convert(event.locationInWindow, from: nil)
        let delta = abs(event.scrollingDeltaY) >= abs(event.scrollingDeltaX)
            ? event.scrollingDeltaY
            : event.scrollingDeltaX
        guard abs(delta) > 0.1 else { return }

        let distance = min(max(abs(delta) * 12, 90), bounds.height * 0.42)
        let direction: CGFloat = delta > 0 ? -1 : 1
        let startY = min(max(location.y, distance + 8), bounds.height - distance - 8)
        let start = CGPoint(x: location.x, y: startY)
        let end = CGPoint(x: location.x, y: startY + direction * distance)
        onSwipe?(start, end, bounds.size)
    }

    private func sendHorizontalSwipe(delta: CGFloat, at event: NSEvent) {
        let y = min(max(convert(event.locationInWindow, from: nil).y, 80), bounds.height - 80)
        let left = CGPoint(x: bounds.width * 0.76, y: y)
        let right = CGPoint(x: bounds.width * 0.24, y: y)
        if delta > 0 {
            onSwipe?(left, right, bounds.size)
        } else {
            onSwipe?(right, left, bounds.size)
        }
    }

    override func keyDown(with event: NSEvent) {
        let modifiers = modifierNames(event.modifierFlags)
        if let named = namedKey(for: event.keyCode) {
            flushPendingText()
            onKeys?([["key": named, "modifiers": modifiers]])
            return
        }

        guard let characters = event.characters, !characters.isEmpty else {
            super.keyDown(with: event)
            return
        }
        let commandModifiers = commandModifiersOnly(modifiers)
        if commandModifiers.isEmpty {
            pendingText.append(characters)
            scheduleTextFlush()
        } else {
            flushPendingText()
            let keys = characters.map { character in
                ["key": String(character), "modifiers": commandModifiers] as [String: Any]
            }
            onKeys?(keys)
        }
    }

    private func scheduleTextFlush() {
        pendingTextWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.flushPendingText()
        }
        pendingTextWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.045, execute: workItem)
    }

    private func flushPendingText() {
        pendingTextWorkItem?.cancel()
        pendingTextWorkItem = nil
        guard !pendingText.isEmpty else { return }
        let text = pendingText
        pendingText.removeAll(keepingCapacity: true)
        onText?(text)
    }

    private func namedKey(for keyCode: UInt16) -> String? {
        switch keyCode {
        case 36, 76: return "return"
        case 48: return "tab"
        case 51: return "backspace"
        case 53: return "escape"
        case 117: return "forwarddelete"
        case 123: return "left"
        case 124: return "right"
        case 125: return "down"
        case 126: return "up"
        default: return nil
        }
    }

    private func modifierNames(_ flags: NSEvent.ModifierFlags) -> [String] {
        var result: [String] = []
        if flags.contains(.command) { result.append("command") }
        if flags.contains(.control) { result.append("control") }
        if flags.contains(.option) { result.append("option") }
        if flags.contains(.shift) { result.append("shift") }
        if flags.contains(.function) { result.append("fn") }
        return result
    }

    private func commandModifiersOnly(_ modifiers: [String]) -> [String] {
        modifiers.filter { $0 == "command" || $0 == "control" || $0 == "option" }
    }
}
