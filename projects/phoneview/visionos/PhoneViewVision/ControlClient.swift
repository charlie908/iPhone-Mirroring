import Foundation

@MainActor
final class ControlClient: ObservableObject {
    @Published private(set) var isConnected = false
    @Published private(set) var lastError: String?

    private var host = ""

    func connect(host: String) {
        disconnect()
        self.host = host
        guard let url = URL(string: "http://\(host):8999/control/status") else {
            lastError = "Adresse du Mac incorrecte"
            return
        }

        Task { [weak self] in
            do {
                let (_, response) = try await URLSession.shared.data(from: url)
                guard let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                self?.isConnected = true
                self?.lastError = nil
            } catch {
                self?.isConnected = false
                self?.lastError = "Commandes hors ligne"
            }
        }
    }

    func disconnect() {
        host = ""
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
        guard !host.isEmpty,
              let url = URL(string: "http://\(host):8999/control/command") else {
            lastError = "Commandes déconnectées"
            return
        }

        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        Task { [weak self] in
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                self?.isConnected = true
                self?.lastError = nil
            } catch {
                self?.isConnected = false
                self?.lastError = "Commande non envoyée"
            }
        }
    }
}
