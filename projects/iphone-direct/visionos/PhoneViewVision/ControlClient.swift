import Foundation

@MainActor
final class ControlClient: ObservableObject {
    @Published private(set) var isConnected = false
    @Published private(set) var lastError: String?

    func connect(host: String) {
        disconnect()
        DirectPeerTransport.shared.stateHandler = { [weak self] connected in
            self?.isConnected = connected
            self?.lastError = connected ? nil : "En attente de l’iPhone"
        }
        lastError = "En attente de l’iPhone"
        DirectPeerTransport.shared.start()
    }

    func disconnect() {
        DirectPeerTransport.shared.stateHandler = nil
        isConnected = false
    }

    func send(_ type: String, text: String? = nil) {
        var payload: [String: Any] = ["type": type]
        if let text { payload["text"] = text }
        send(payload)
    }

    func tap(at point: CGPoint, in size: CGSize) {
        let point = clamped(point, to: size)
        send([
            "type": "tap",
            "x": point.x,
            "y": point.y,
            "videoWidth": size.width,
            "videoHeight": size.height,
        ])
    }

    func swipe(from start: CGPoint, to end: CGPoint, in size: CGSize) {
        let start = clamped(start, to: size)
        let end = clamped(end, to: size)
        send([
            "type": "swipe",
            "x": start.x,
            "y": start.y,
            "endX": end.x,
            "endY": end.y,
            "duration": 280,
            "videoWidth": size.width,
            "videoHeight": size.height,
        ])
    }

    private func clamped(_ point: CGPoint, to size: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(point.x, 0), size.width),
            y: min(max(point.y, 0), size.height)
        )
    }

    private func send(_ payload: [String: Any]) {
        guard isConnected else {
            lastError = "Commandes déconnectées"
            return
        }
        DirectPeerTransport.shared.sendControl(payload)
    }
}
