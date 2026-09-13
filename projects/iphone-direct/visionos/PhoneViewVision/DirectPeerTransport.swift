import Foundation
import Network
import OSLog

/// One peer-to-peer link shared by the native video renderer and controls.
/// No Mac address, router, or internet connection is involved.
final class DirectPeerTransport: @unchecked Sendable {
    static let shared = DirectPeerTransport()

    private let logger = Logger(subsystem: "com.example.iphonedirect.vision", category: "DirectPeer")
    private let queue = DispatchQueue(label: "com.example.iphonedirect.vision.peer", qos: .userInteractive)
    private var listener: NWListener?
    private var connection: NWConnection?
    private var receiveBuffer = Data()
    private var started = false

    var videoHandler: ((Data) -> Void)?
    var stateHandler: ((Bool) -> Void)?

    private init() {}

    func start() {
        queue.async { [weak self] in
            guard let self, !self.started else { return }
            self.started = true
            do {
                let listener = try NWListener(using: Self.parameters())
                listener.service = NWListener.Service(
                    name: "iPhone Direct Vision",
                    type: "_iphonedirect._tcp"
                )
                listener.stateUpdateHandler = { [weak self] state in
                    switch state {
                    case .ready:
                        self?.logger.info("Peer-to-peer listener ready")
                    case .failed(let error):
                        self?.logger.error("Listener failed: \(error.localizedDescription)")
                        self?.notifyState(false)
                    default:
                        break
                    }
                }
                listener.newConnectionHandler = { [weak self] connection in
                    self?.accept(connection)
                }
                self.listener = listener
                listener.start(queue: self.queue)
            } catch {
                self.started = false
                self.logger.error("Could not create listener: \(error.localizedDescription)")
                self.notifyState(false)
            }
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.connection?.cancel()
            self.connection = nil
            self.listener?.cancel()
            self.listener = nil
            self.started = false
            self.receiveBuffer.removeAll()
            self.notifyState(false)
        }
    }

    func sendControl(_ payload: [String: Any]) {
        queue.async { [weak self] in
            guard let self, let connection = self.connection,
                  let json = try? JSONSerialization.data(withJSONObject: payload) else { return }
            var timestamp = UInt64(Date().timeIntervalSince1970 * 1_000_000).bigEndian
            var message = Data([0x20])
            message.append(Data(bytes: &timestamp, count: MemoryLayout<UInt64>.size))
            message.append(json)
            self.sendFramed(message, over: connection)
        }
    }

    private func accept(_ newConnection: NWConnection) {
        connection?.cancel()
        connection = newConnection
        receiveBuffer.removeAll(keepingCapacity: true)
        newConnection.stateUpdateHandler = { [weak self, weak newConnection] state in
            guard let self, let newConnection else { return }
            switch state {
            case .ready:
                self.logger.info("iPhone Direct peer connected")
                self.notifyState(true)
                self.receive(on: newConnection)
            case .failed(let error):
                self.logger.error("Peer failed: \(error.localizedDescription)")
                self.connectionEnded(newConnection)
            case .cancelled:
                self.connectionEnded(newConnection)
            default:
                break
            }
        }
        newConnection.start(queue: queue)
    }

    private func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1_048_576) { [weak self, weak connection] data, _, complete, error in
            guard let self, let connection else { return }
            if let data { self.receiveBuffer.append(data) }
            self.drainMessages()
            if error != nil || complete {
                self.connectionEnded(connection)
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
            DispatchQueue.main.async { [weak self] in self?.videoHandler?(message) }
        }
    }

    private func sendFramed(_ message: Data, over connection: NWConnection) {
        var length = UInt32(message.count).bigEndian
        var packet = Data(bytes: &length, count: MemoryLayout<UInt32>.size)
        packet.append(message)
        connection.send(content: packet, completion: .contentProcessed { [weak self] error in
            if let error { self?.logger.error("Control send failed: \(error.localizedDescription)") }
        })
    }

    private func connectionEnded(_ endedConnection: NWConnection) {
        guard connection === endedConnection else { return }
        connection = nil
        receiveBuffer.removeAll(keepingCapacity: true)
        notifyState(false)
    }

    private func notifyState(_ connected: Bool) {
        DispatchQueue.main.async { [weak self] in self?.stateHandler?(connected) }
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
