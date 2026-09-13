import UIKit
import Foundation

struct DeviceInfo: Codable {
    let deviceName: String          // e.g., "Himanshu's iPhone"
    let deviceModel: String          // e.g., "iPhone 14 Pro"
    let systemName: String           // e.g., "iOS"
    let systemVersion: String        // e.g., "18.0"
    let modelIdentifier: String      // e.g., "iPhone15,3"
    let screenResolution: String     // e.g., "1179x2556"
    let screenScale: String          // e.g., "3.0x"
    let batteryLevel: Int            // 0-100, -1 if unavailable
    let batteryState: String         // "charging", "unplugged", "full", "unknown"

    static func current() -> DeviceInfo {
        let device = UIDevice.current
        let screen = UIScreen.main

        // Enable battery monitoring
        device.isBatteryMonitoringEnabled = true

        // Get battery info
        let batteryLevel: Int
        if device.batteryLevel >= 0 {
            batteryLevel = Int(device.batteryLevel * 100)
        } else {
            batteryLevel = -1
        }

        let batteryState: String
        switch device.batteryState {
        case .charging:
            batteryState = "charging"
        case .full:
            batteryState = "full"
        case .unplugged:
            batteryState = "unplugged"
        default:
            batteryState = "unknown"
        }

        // Get model identifier (e.g., iPhone15,3)
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelIdentifier = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "Unknown"
            }
        }

        // Get human-readable model name
        let deviceModel = DeviceInfo.getDeviceModel(identifier: modelIdentifier)

        // Screen resolution
        let bounds = screen.nativeBounds
        let resolution = "\(Int(bounds.width))x\(Int(bounds.height))"
        let scale = "\(screen.scale)x"

        return DeviceInfo(
            deviceName: device.name,
            deviceModel: deviceModel,
            systemName: device.systemName,
            systemVersion: device.systemVersion,
            modelIdentifier: modelIdentifier,
            screenResolution: resolution,
            screenScale: scale,
            batteryLevel: batteryLevel,
            batteryState: batteryState
        )
    }

    // Map model identifier to human-readable name
    private static func getDeviceModel(identifier: String) -> String {
        switch identifier {
        // iPhone
        case "iPhone14,7": return "iPhone 14"
        case "iPhone14,8": return "iPhone 14 Plus"
        case "iPhone15,2": return "iPhone 14 Pro"
        case "iPhone15,3": return "iPhone 14 Pro Max"
        case "iPhone15,4": return "iPhone 15"
        case "iPhone15,5": return "iPhone 15 Plus"
        case "iPhone16,1": return "iPhone 15 Pro"
        case "iPhone16,2": return "iPhone 15 Pro Max"
        case "iPhone17,1": return "iPhone 16 Pro"
        case "iPhone17,2": return "iPhone 16 Pro Max"
        case "iPhone17,3": return "iPhone 16"
        case "iPhone17,4": return "iPhone 16 Plus"

        // iPhone 13 series
        case "iPhone14,2": return "iPhone 13 Pro"
        case "iPhone14,3": return "iPhone 13 Pro Max"
        case "iPhone14,4": return "iPhone 13 mini"
        case "iPhone14,5": return "iPhone 13"

        // iPhone 12 series
        case "iPhone13,1": return "iPhone 12 mini"
        case "iPhone13,2": return "iPhone 12"
        case "iPhone13,3": return "iPhone 12 Pro"
        case "iPhone13,4": return "iPhone 12 Pro Max"

        // iPhone SE
        case "iPhone14,6": return "iPhone SE (3rd generation)"
        case "iPhone12,8": return "iPhone SE (2nd generation)"

        // iPad
        case identifier where identifier.hasPrefix("iPad"):
            return identifier.replacingOccurrences(of: ",", with: " ")

        // Simulator
        case "x86_64", "arm64":
            return "Simulator"

        default:
            return identifier
        }
    }

    func toJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(self),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        return "{}"
    }
}
