import SwiftUI
import ReplayKit
import UIKit
import AVFoundation

struct ContentView: View {
    @StateObject private var broadcastManager = BroadcastManager()
    @State private var serverHost = Constants.Server.host
    @State private var serverPort = String(Constants.Server.port)

    var body: some View {
        VStack(spacing: 24) {
            // Status Section
            StatusCard(isConnected: broadcastManager.isConnected,
                      isBroadcasting: broadcastManager.isBroadcasting)
                .padding(.horizontal)
                .padding(.top)

            // Broadcast Picker
            VStack(spacing: 12) {
                Text("Start Broadcast")
                    .font(.headline)
                    .foregroundColor(.secondary)

                BroadcastPickerRepresentable()
                    .frame(width: 80, height: 80)

                Text("Tap the circle above")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 10)
            .padding(.horizontal)

            Label("Connexion directe au Vision Pro", systemImage: "vision.pro")
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.10))
                .cornerRadius(16)
                .padding(.horizontal)

            // Auto-lock info (when broadcasting)
            if broadcastManager.isBroadcasting {
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.open.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text("Auto-lock disabled during broadcast")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    Text("Screen will not auto-lock while broadcasting")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            }

            Spacer()

            // Instructions
            InstructionsView()
                .padding(.horizontal)
        }
        .onAppear {
            loadSettings()
        }
        .onChange(of: serverHost) { _ in saveSettings() }
        .onChange(of: serverPort) { _ in saveSettings() }
    }

    private func loadSettings() {
        if let savedHost = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.serverHost) {
            serverHost = savedHost
        }
        if let savedPort = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.serverPort) {
            serverPort = savedPort
        }
    }

    private func saveSettings() {
        UserDefaults.standard.set(serverHost, forKey: Constants.UserDefaultsKeys.serverHost)
        UserDefaults.standard.set(serverPort, forKey: Constants.UserDefaultsKeys.serverPort)

        // Also save to app group for extension access
        if let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier) {
            defaults.set(serverHost, forKey: Constants.UserDefaultsKeys.serverHost)
            defaults.set(serverPort, forKey: Constants.UserDefaultsKeys.serverPort)
        }
    }
}

// MARK: - Status Card

struct StatusCard: View {
    let isConnected: Bool
    let isBroadcasting: Bool

    var body: some View {
        HStack(spacing: 20) {
            StatusIndicator(
                title: "Server",
                isActive: isConnected,
                activeColor: .green,
                inactiveColor: .red
            )

            Divider()
                .frame(height: 40)

            StatusIndicator(
                title: "Broadcast",
                isActive: isBroadcasting,
                activeColor: .blue,
                inactiveColor: .gray
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10)
    }
}

struct StatusIndicator: View {
    let title: String
    let isActive: Bool
    let activeColor: Color
    let inactiveColor: Color

    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(isActive ? activeColor : inactiveColor)
                .frame(width: 16, height: 16)
                .overlay(
                    Circle()
                        .stroke(isActive ? activeColor.opacity(0.3) : Color.clear, lineWidth: 4)
                        .scaleEffect(isActive ? 1.5 : 1)
                        .animation(isActive ? .easeInOut(duration: 1).repeatForever(autoreverses: true) : .default, value: isActive)
                )

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(isActive ? "Active" : "Inactive")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(isActive ? activeColor : inactiveColor)
        }
        .frame(minWidth: 80)
    }
}

// MARK: - Broadcast Picker

struct BroadcastPickerRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 80, height: 80))

        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 80, height: 80))

        // Set the preferred extension
        picker.preferredExtension = "com.example.iphonedirect.broadcast"

        // Show only microphone toggle if needed (we're video-only for now)
        picker.showsMicrophoneButton = false

        // Find and style the button
        for subview in picker.subviews {
            if let button = subview as? UIButton {
                button.imageView?.tintColor = .systemBlue

                // Make the button fill the picker
                button.frame = picker.bounds
                button.autoresizingMask = [.flexibleWidth, .flexibleHeight]

                // Use a large record icon
                let config = UIImage.SymbolConfiguration(pointSize: 50, weight: .regular)
                let image = UIImage(systemName: "record.circle.fill", withConfiguration: config)
                button.setImage(image, for: .normal)
                button.imageView?.contentMode = .scaleAspectFit

                // Make the button more tappable
                button.isUserInteractionEnabled = true
            }
        }

        // Make sure picker is interactive
        picker.isUserInteractionEnabled = true
        containerView.addSubview(picker)
        picker.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        containerView.isUserInteractionEnabled = true

        return containerView
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

// Helper to programmatically trigger the broadcast picker
extension RPSystemBroadcastPickerView {
    func triggerBroadcast() {
        for subview in subviews {
            if let button = subview as? UIButton {
                button.sendActions(for: .touchUpInside)
                break
            }
        }
    }
}

// MARK: - Server Configuration

struct ServerConfigView: View {
    @Binding var host: String
    @Binding var port: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Server Configuration")
                .font(.headline)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Host")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("localhost", text: $host)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Port")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("8765", text: $port)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                        .frame(width: 80)
                }
            }

            Text("ws://\(host):\(port)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10)
    }
}

// MARK: - Stats View

struct StatsView: View {
    let frameCount: Int
    let fps: Double

    var body: some View {
        HStack(spacing: 24) {
            VStack {
                Text("\(frameCount)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .monospacedDigit()
                Text("Frames")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack {
                Text(String(format: "%.1f", fps))
                    .font(.title2)
                    .fontWeight(.bold)
                    .monospacedDigit()
                Text("FPS")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10)
    }
}

// MARK: - Instructions View

struct InstructionsView: View {
    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isSimulator {
                Label("Simulator Limitation", systemImage: "exclamationmark.triangle")
                    .font(.caption.bold())
                    .foregroundColor(.orange)

                Text("ReplayKit broadcast extensions don't work in the iOS Simulator. Please use a real iOS device to test screen broadcasting.\n\nTo test the server, run:\n./scripts/start-server.sh --test")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Label("How to use", systemImage: "info.circle")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                Text("1. Make sure the Python server is running\n2. Tap the broadcast button above\n3. Select \"Screen Streamer\" from the list\n4. Confirm to start broadcasting")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Broadcast Manager

class BroadcastManager: ObservableObject {
    @Published var isConnected = false
    @Published var isBroadcasting = false

    private var previousBroadcastState = false
    private var audioPlayer: AVAudioPlayer?
    private var stateTimer: Timer?

    init() {
        // Observe broadcast state from UserDefaults (set by extension)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(checkBroadcastState),
            name: UserDefaults.didChangeNotification,
            object: nil
        )

        // Start periodic check
        stateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkBroadcastState()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reassertIdleTimer),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func checkBroadcastState() {
        if let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier) {
            DispatchQueue.main.async {
                let newBroadcastState = defaults.bool(forKey: Constants.UserDefaultsKeys.isBroadcasting)
                let newConnectionState = defaults.bool(forKey: Constants.UserDefaultsKeys.isServerConnected)

                // Update connection state
                self.isConnected = newConnectionState

                // Update broadcast state and handle idle timer.
                if newBroadcastState != self.previousBroadcastState {
                    self.previousBroadcastState = newBroadcastState
                    self.isBroadcasting = newBroadcastState
                    if !newBroadcastState {
                        self.updateIdleTimer(enabled: false)
                    }
                }

                // iOS may release the idle-timer assertion during an app/scene
                // transition. Reassert it while ReplayKit is still active.
                if newBroadcastState {
                    self.updateIdleTimer(enabled: true)
                }
            }
        }
    }

    @objc private func reassertIdleTimer() {
        if isBroadcasting {
            updateIdleTimer(enabled: true)
        }
    }

    private func updateIdleTimer(enabled: Bool) {
        if enabled {
            // Disable auto-lock
            UIApplication.shared.isIdleTimerDisabled = true

            // Play silent audio in background to keep app alive
            // This prevents auto-lock even when app is backgrounded
            playSilentAudio()
        } else {
            // Re-enable auto-lock
            UIApplication.shared.isIdleTimerDisabled = false

            // Stop silent audio
            stopSilentAudio()
        }
    }

    private func playSilentAudio() {
        guard audioPlayer?.isPlaying != true else { return }

        // Create a silent audio file in memory
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)

            // Create a silent 1-second audio buffer
            let silenceURL = createSilentAudio()
            audioPlayer = try AVAudioPlayer(contentsOf: silenceURL)
            audioPlayer?.numberOfLoops = -1 // Loop indefinitely
            audioPlayer?.volume = 0.0 // Silent
            audioPlayer?.play()
        } catch {
            print("Failed to start silent audio: \(error)")
        }
    }

    private func stopSilentAudio() {
        audioPlayer?.stop()
        audioPlayer = nil

        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }

    private func createSilentAudio() -> URL {
        // Create a temporary silent audio file
        let tempDir = FileManager.default.temporaryDirectory
        let silentAudioURL = tempDir.appendingPathComponent("silent.wav")

        // Check if file already exists
        if FileManager.default.fileExists(atPath: silentAudioURL.path) {
            return silentAudioURL
        }

        // Create a simple WAV file with 1 second of silence
        // WAV header for 1 second of silence at 44.1kHz, 16-bit, mono
        var wavData = Data()

        // RIFF header
        wavData.append(contentsOf: "RIFF".utf8)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(36 + 44100 * 2).littleEndian) { Data($0) })
        wavData.append(contentsOf: "WAVE".utf8)

        // fmt subchunk
        wavData.append(contentsOf: "fmt ".utf8)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) }) // PCM
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) }) // Mono
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(44100).littleEndian) { Data($0) }) // Sample rate
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(88200).littleEndian) { Data($0) }) // Byte rate
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(2).littleEndian) { Data($0) }) // Block align
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian) { Data($0) }) // Bits per sample

        // data subchunk
        wavData.append(contentsOf: "data".utf8)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(44100 * 2).littleEndian) { Data($0) })
        wavData.append(Data(repeating: 0, count: 44100 * 2)) // 1 second of silence

        try? wavData.write(to: silentAudioURL)
        return silentAudioURL
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
