import Foundation

@MainActor
final class ControlClient: ObservableObject {
    @Published private(set) var isConnected = false

    func connect() {
        DirectPeerTransport.shared.stateHandler = { [weak self] connected in
            self?.isConnected = connected
        }
        DirectPeerTransport.shared.start()
    }

    func disconnect() {
        DirectPeerTransport.shared.stateHandler = nil
        isConnected = false
    }

    func send(_ type: String, text: String? = nil) {
        var payload: [String: Any] = ["type": type]
        if let text = text { payload["text"] = text }
        DirectPeerTransport.shared.sendControl(payload)
    }

    func sendKeys(_ keys: [[String: Any]]) {
        guard !keys.isEmpty else { return }
        send(["type": "keys", "keys": keys])
    }

    func tap(at point: CGPoint, in size: CGSize) {
        let point = clamped(point, to: size)
        send([
            "type": "tap",
            "x": point.x,
            "y": point.y,
            "videoWidth": size.width,
            "videoHeight": size.height
        ])
    }

    func longPress(at point: CGPoint, in size: CGSize, duration: Double) {
        let point = clamped(point, to: size)
        send([
            "type": "longPress",
            "x": point.x,
            "y": point.y,
            "duration": max(0.45, min(duration, 3.0)),
            "videoWidth": size.width,
            "videoHeight": size.height
        ])
    }

    func swipe(from start: CGPoint, to end: CGPoint, in size: CGSize, duration: Double = 220) {
        let start = clamped(start, to: size)
        let end = clamped(end, to: size)
        send([
            "type": "swipe",
            "x": start.x,
            "y": start.y,
            "endX": end.x,
            "endY": end.y,
            "duration": duration,
            "videoWidth": size.width,
            "videoHeight": size.height
        ])
    }

    private func send(_ payload: [String: Any]) {
        guard isConnected else { return }
        DirectPeerTransport.shared.sendControl(payload)
    }

    private func clamped(_ point: CGPoint, to size: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(point.x, 0), size.width),
            y: min(max(point.y, 0), size.height)
        )
    }
}
