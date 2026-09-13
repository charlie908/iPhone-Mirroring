import Foundation
import Network
import os.log

/// Peer-to-peer transport for the isolated iPhone Direct prototype.
/// The historical type name keeps SampleHandler independent from transport.
final class WebSocketClient: @unchecked Sendable {
    typealias VoidCallback = () -> Void
    typealias ErrorCallback = (Error?) -> Void

    private let logger = Logger(subsystem: "com.example.iphonedirect", category: "DirectPeer")
    private let queue = DispatchQueue(label: "com.example.iphonedirect.peer", qos: .userInteractive)
    private var browser: NWBrowser?
    private var connection: NWConnection?
    private var receiveBuffer = Data()
    private var pendingMessages: [Data] = []
    private let maxPendingMessages = 30

    private(set) var isConnected = false
    var onConnect: VoidCallback?
    var onDisconnect: ErrorCallback?
    var onError: ErrorCallback?
    var onMessage: ((Data) -> Void)?

    init(url: String) {}

    func connect() {
        queue.async { [weak self] in self?.startBrowsing() }
    }

    func disconnect() {
        queue.async { [weak self] in
            guard let self else { return }
            self.browser?.cancel()
            self.browser = nil
            self.connection?.cancel()
            self.connection = nil
            self.receiveBuffer.removeAll(keepingCapacity: false)
            self.isConnected = false
        }
    }

    func send(_ data: Data) {
        queue.async { [weak self] in
            guard let self else { return }
            guard self.isConnected, let connection = self.connection else {
                if self.pendingMessages.count >= self.maxPendingMessages {
                    self.pendingMessages.removeFirst()
                }
                self.pendingMessages.append(data)
                return
            }
            self.sendFramed(data, over: connection)
        }
    }

    private func startBrowsing() {
        browser?.cancel()
        connection?.cancel()
        connection = nil
        isConnected = false

        let descriptor = NWBrowser.Descriptor.bonjour(type: "_iphonedirect._tcp", domain: nil)
        let browser = NWBrowser(for: descriptor, using: Self.parameters())
        self.browser = browser
        browser.stateUpdateHandler = { [weak self] state in
            if case .failed(let error) = state {
                self?.logger.error("Peer browser failed: \(error.localizedDescription)")
                self?.onError?(error)
            }
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self, self.connection == nil, let endpoint = results.first?.endpoint else { return }
            self.open(endpoint)
        }
        browser.start(queue: queue)
        logger.info("Looking for iPhone Direct on peer-to-peer Wi-Fi")
    }

    private func open(_ endpoint: NWEndpoint) {
        let connection = NWConnection(to: endpoint, using: Self.parameters())
        self.connection = connection
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self, let connection else { return }
            switch state {
            case .ready:
                self.isConnected = true
                self.browser?.cancel()
                self.browser = nil
                self.logger.info("Direct Vision Pro connection ready")
                self.onConnect?()
                let queued = self.pendingMessages
                self.pendingMessages.removeAll(keepingCapacity: true)
                queued.forEach { self.sendFramed($0, over: connection) }
                self.receive(on: connection)
            case .failed(let error):
                self.connectionFailed(error)
            case .cancelled:
                if self.isConnected { self.connectionFailed(nil) }
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    private func sendFramed(_ message: Data, over connection: NWConnection) {
        var length = UInt32(message.count).bigEndian
        var packet = Data(bytes: &length, count: MemoryLayout<UInt32>.size)
        packet.append(message)
        connection.send(content: packet, completion: .contentProcessed { [weak self] error in
            if let error {
                self?.logger.error("Direct send failed: \(error.localizedDescription)")
                self?.onError?(error)
            }
        })
    }

    private func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1_048_576) { [weak self, weak connection] data, _, complete, error in
            guard let self, let connection else { return }
            if let data { self.receiveBuffer.append(data) }
            self.drainMessages()
            if let error {
                self.connectionFailed(error)
            } else if complete {
                self.connectionFailed(nil)
            } else {
                self.receive(on: connection)
            }
        }
    }

    private func drainMessages() {
        while receiveBuffer.count >= 4 {
            let size = receiveBuffer.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
            guard size <= 1_048_576 else {
                receiveBuffer.removeAll()
                return
            }
            let total = 4 + Int(size)
            guard receiveBuffer.count >= total else { return }
            // Data can keep a non-zero startIndex after removeFirst(). Always
            // calculate the payload range relative to the current start.
            let payloadStart = receiveBuffer.index(receiveBuffer.startIndex, offsetBy: 4)
            let payloadEnd = receiveBuffer.index(receiveBuffer.startIndex, offsetBy: total)
            let message = Data(receiveBuffer[payloadStart..<payloadEnd])
            receiveBuffer.removeFirst(total)
            onMessage?(message)
        }
    }

    private func connectionFailed(_ error: Error?) {
        let wasConnected = isConnected
        isConnected = false
        connection?.cancel()
        connection = nil
        receiveBuffer.removeAll(keepingCapacity: true)
        if wasConnected { onDisconnect?(error) }
        queue.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.startBrowsing() }
    }

    private static func parameters() -> NWParameters {
        let tcp = NWProtocolTCP.Options()
        tcp.noDelay = true
        let parameters = NWParameters(tls: nil, tcp: tcp)
        parameters.includePeerToPeer = true
        parameters.serviceClass = .responsiveData
        return parameters
    }
}

/// Sends commands from Vision Pro to the DeviceKit service already running on
/// the iPhone. Video still works when DeviceKit hasn't been started by the Mac.
final class DirectDeviceKitForwarder {
    private let session = URLSession(configuration: .ephemeral)
    private let logicalSize = CGSize(width: 440, height: 956)

    func handle(_ message: Data) {
        guard message.count >= 9, message[message.startIndex] == 0x20,
              let command = try? JSONSerialization.jsonObject(with: message.dropFirst(9)) as? [String: Any],
              let type = command["type"] as? String,
              let rpc = rpcPayload(for: type, command: command),
              let data = try? JSONSerialization.data(withJSONObject: rpc),
              let url = URL(string: "http://127.0.0.1:12004/rpc") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        session.dataTask(with: request).resume()
    }

    private func rpcPayload(for type: String, command: [String: Any]) -> [String: Any]? {
        let method: String
        let parameters: [String: Any]
        switch type {
        case "tap":
            method = "device.io.tap"
            let point = translatedPoint(command["x"], command["y"], command: command)
            parameters = ["x": point.x, "y": point.y]
        case "swipe":
            method = "device.io.swipe"
            let start = translatedPoint(command["x"], command["y"], command: command)
            let end = translatedPoint(command["endX"], command["endY"], command: command)
            let milliseconds = (command["duration"] as? NSNumber)?.doubleValue ?? 280
            parameters = ["x1": Int(start.x), "y1": Int(start.y), "x2": Int(end.x), "y2": Int(end.y), "duration": milliseconds / 1000]
        case "type":
            method = "device.io.text"
            parameters = ["text": command["text"] as? String ?? ""]
        case "home", "lock", "volumeUp", "volumeDown":
            method = "device.io.button"
            parameters = ["button": type]
        default:
            return nil
        }
        return ["jsonrpc": "2.0", "method": method, "params": parameters, "id": UUID().uuidString]
    }

    private func translatedPoint(_ xValue: Any?, _ yValue: Any?, command: [String: Any]) -> CGPoint {
        let x = (xValue as? NSNumber)?.doubleValue ?? 0
        let y = (yValue as? NSNumber)?.doubleValue ?? 0
        let width = max((command["videoWidth"] as? NSNumber)?.doubleValue ?? logicalSize.width, 1)
        let height = max((command["videoHeight"] as? NSNumber)?.doubleValue ?? logicalSize.height, 1)
        return CGPoint(
            x: min(max(x / width * logicalSize.width, 0), logicalSize.width - 1),
            y: min(max(y / height * logicalSize.height, 0), logicalSize.height - 1)
        )
    }
}
