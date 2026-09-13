import Foundation

/// Shared constants between main app and broadcast extension
enum Constants {
    /// WebSocket server configuration
    enum Server {
        // Use your Mac's local IP for physical device, localhost for simulator
        #if targetEnvironment(simulator)
        static let host = "localhost"
        #else
        // Kept only for compatibility with the existing settings screen.
        // iPhone Mac discovers the Mac over the local peer-to-peer connection.
        static let host = "direct"
        #endif
        static let port = 8765
        static let url = "ws://\(host):\(port)"
    }

    /// App Group identifier for shared data
    static let appGroupIdentifier = "group.com.example.iphonemac"

    /// Video encoding settings
    enum Video {
        static let defaultWidth = 1080
        static let defaultHeight = 1920
        static let defaultFPS = 60
        // 4 Mbps visibly macroblocks at the iPhone's captured 884x1918
        // resolution during 60 fps motion. The direct LAN path can carry
        // substantially more without adding an encode/decode stage.
        static let defaultBitrate = 10_000_000
        static let keyframeInterval = 60 // one second at 60fps
    }

    /// Message types for WebSocket protocol
    enum MessageType: UInt8 {
        case videoFrame = 0x01
        case config = 0x02
        case heartbeat = 0x03
        case stats = 0x04
        case deviceInfo = 0x05
        case endStream = 0xFF
    }

    /// UserDefaults keys
    enum UserDefaultsKeys {
        static let serverHost = "serverHost"
        static let serverPort = "serverPort"
        static let videoBitrate = "videoBitrate"
        static let isBroadcasting = "isBroadcasting"
        static let isServerConnected = "isServerConnected"
    }
}
