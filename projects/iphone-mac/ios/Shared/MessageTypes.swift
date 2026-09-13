import Foundation

/// Protocol message structures for iOS to Server communication
enum ProtocolMessage {
    /// Create a binary message with header
    /// - Parameters:
    ///   - type: Message type
    ///   - timestamp: Timestamp in microseconds
    ///   - payload: Message payload
    /// - Returns: Binary data with header + payload
    static func createMessage(type: Constants.MessageType, timestamp: UInt64, payload: Data) -> Data {
        var data = Data()

        // Byte 0: Message type
        data.append(type.rawValue)

        // Bytes 1-8: Timestamp (big-endian uint64)
        var timestampBE = timestamp.bigEndian
        data.append(Data(bytes: &timestampBE, count: 8))

        // Bytes 9+: Payload
        data.append(payload)

        return data
    }

    /// Create a video frame message
    static func videoFrame(nalUnit: Data, timestamp: UInt64) -> Data {
        return createMessage(type: .videoFrame, timestamp: timestamp, payload: nalUnit)
    }

    /// Create a config message (SPS/PPS)
    static func config(spsPps: Data, timestamp: UInt64) -> Data {
        return createMessage(type: .config, timestamp: timestamp, payload: spsPps)
    }

    /// Create a heartbeat message
    static func heartbeat() -> Data {
        return createMessage(type: .heartbeat, timestamp: 0, payload: Data())
    }

    /// Create a stats message
    static func stats(fps: Double, bitrate: Int) -> Data {
        let statsDict: [String: Any] = [
            "fps": fps,
            "bitrate": bitrate
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: statsDict) else {
            return createMessage(type: .stats, timestamp: 0, payload: Data())
        }

        return createMessage(type: .stats, timestamp: 0, payload: jsonData)
    }

    /// Create a device info message
    static func deviceInfo(json: String) -> Data {
        guard let jsonData = json.data(using: .utf8) else {
            return createMessage(type: .deviceInfo, timestamp: 0, payload: Data())
        }
        return createMessage(type: .deviceInfo, timestamp: 0, payload: jsonData)
    }

    /// Create an end stream message
    static func endStream() -> Data {
        return createMessage(type: .endStream, timestamp: 0, payload: Data())
    }
}

/// NAL unit start codes
enum NALStartCode {
    static let fourByte = Data([0x00, 0x00, 0x00, 0x01])
    static let threeByte = Data([0x00, 0x00, 0x01])
}

/// NAL unit types
enum NALUnitType: UInt8 {
    case nonIDR = 1      // P-frame
    case idr = 5         // Keyframe
    case sps = 7         // Sequence Parameter Set
    case pps = 8         // Picture Parameter Set

    init?(fromHeader header: UInt8) {
        let type = header & 0x1F
        self.init(rawValue: type)
    }
}
