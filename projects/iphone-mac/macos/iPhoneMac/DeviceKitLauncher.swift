import Foundation
import OSLog

@MainActor
final class DeviceKitLauncher: ObservableObject {
    static let shared = DeviceKitLauncher()

    enum State: String {
        case starting = "Starting controls…"
        case running = "Controls started"
        case unavailable = "Unlock the iPhone to enable controls"
    }

    @Published private(set) var state: State = .starting

    private let logger = Logger(subsystem: "com.example.iphonemac.mac", category: "ControlRunner")
    private let deviceID = "YOUR_IPHONE_DESTINATION_ID"
    private let coreDeviceID = "YOUR_IPHONE_CORE_DEVICE_ID"
    private var controlProcess: Process?
    private var retryScheduled = false

    private init() {}

    func start() {
        guard controlProcess?.isRunning != true else {
            state = .running
            return
        }
        guard let projectPath = bundledProjectPath else {
            state = .unavailable
            logger.error("The bundled control project is missing")
            return
        }

        launchCompanionApp(after: 1.2)
        guard !runnerAlreadyActive() else {
            state = .running
            return
        }

        let logURL = URL(fileURLWithPath: "/tmp/iphonemac-control.log")
        _ = FileManager.default.createFile(atPath: logURL.path, contents: nil)

        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild")
            process.arguments = [
                "test",
                "-project", projectPath,
                "-scheme", "devicekit-ios",
                "-configuration", "Debug",
                "-destination", "id=\(deviceID)",
                "-only-testing:devicekit-iosUITests/DeviceKitUITests/testRunAutomation"
            ]
            let logHandle = try FileHandle(forWritingTo: logURL)
            process.standardOutput = logHandle
            process.standardError = logHandle
            process.terminationHandler = { [weak self] process in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.controlProcess = nil
                    if process.terminationStatus == 0 {
                        self.state = .running
                    } else {
                        self.state = .unavailable
                        self.scheduleRetry()
                    }
                }
            }
            try process.run()
            controlProcess = process
            state = .running
            logger.info("Started the dedicated iPhone Mac control runner")
        } catch {
            state = .unavailable
            logger.error("Could not start control runner: \(error.localizedDescription)")
            scheduleRetry()
        }
    }

    private func scheduleRetry() {
        guard !retryScheduled else { return }
        retryScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            guard let self = self else { return }
            self.retryScheduled = false
            self.state = .starting
            self.start()
        }
    }

    private func runnerAlreadyActive() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-f", "iPhoneMacControl.*testRunAutomation"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func launchCompanionApp(after delay: TimeInterval) {
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + delay) { [coreDeviceID] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            process.arguments = [
                "devicectl", "device", "process", "launch",
                "--device", coreDeviceID,
                "com.example.iphonemac"
            ]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try? process.run()
            process.waitUntilExit()
        }
    }

    private var bundledProjectPath: String? {
        Bundle.main.resourceURL?
            .appendingPathComponent("iPhoneMacControl", isDirectory: true)
            .appendingPathComponent("devicekit-ios.xcodeproj", isDirectory: true)
            .path
    }
}
