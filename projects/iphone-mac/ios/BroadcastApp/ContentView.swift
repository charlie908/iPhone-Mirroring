import AVFoundation
import ReplayKit
import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var keepAwake = KeepAwakeController()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.02, green: 0.10, blue: 0.22)],
                startPoint: .top,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 26) {
                Spacer()

                Image(systemName: "macbook.and.iphone")
                    .font(.system(size: 74, weight: .light))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.blue)

                VStack(spacing: 8) {
                    Text("iPhone Mac")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                    Text("Mirror and control this iPhone from your Mac")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.66))
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    BroadcastPickerRepresentable()
                        .frame(width: 86, height: 86)
                    Text("Confirm Start Broadcast in the Apple window")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.72))
                }

                Text("The broadcast confirmation opens automatically.\nControls are started by iPhone Mac on your Mac.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.46))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Spacer()
            }
            .padding(28)
        }
        .onAppear { keepAwake.start() }
    }
}

@MainActor
final class KeepAwakeController: ObservableObject {
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reassert),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.start() }
        }
        start()
    }

    @objc private func reassert() {
        start()
    }

    func start() {
        UIApplication.shared.isIdleTimerDisabled = true
        guard audioPlayer?.isPlaying != true else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            let player = try AVAudioPlayer(contentsOf: silentAudioURL())
            player.numberOfLoops = -1
            player.volume = 1
            player.prepareToPlay()
            player.play()
            audioPlayer = player
        } catch {
            print("Unable to keep iPhone awake: \(error)")
        }
    }

    private func silentAudioURL() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("iphonemac-silence.wav")
        guard !FileManager.default.fileExists(atPath: url.path) else { return url }

        let sampleRate: UInt32 = 8_000
        let dataSize = sampleRate * 2
        var wav = Data()
        wav.append(contentsOf: "RIFF".utf8)
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(36 + dataSize).littleEndian) { Data($0) })
        wav.append(contentsOf: "WAVEfmt ".utf8)
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) })
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) })
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) })
        wav.append(contentsOf: withUnsafeBytes(of: sampleRate.littleEndian) { Data($0) })
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate * 2).littleEndian) { Data($0) })
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(2).littleEndian) { Data($0) })
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian) { Data($0) })
        wav.append(contentsOf: "data".utf8)
        wav.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })
        wav.append(Data(repeating: 0, count: Int(dataSize)))
        try? wav.write(to: url, options: .atomic)
        return url
    }
}

struct BroadcastPickerRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 86, height: 86))
        picker.preferredExtension = "com.example.iphonemac.broadcast"
        picker.showsMicrophoneButton = false

        if let button = picker.subviews.compactMap({ $0 as? UIButton }).first {
            let configuration = UIImage.SymbolConfiguration(pointSize: 58, weight: .regular)
            button.setImage(UIImage(systemName: "record.circle.fill", withConfiguration: configuration), for: .normal)
            button.tintColor = .systemBlue
        }

        // ReplayKit still requires the user to approve Apple's system sheet,
        // but opening iPhone Mac can present that sheet without another tap.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak picker] in
            picker?.subviews.compactMap { $0 as? UIButton }.first?.sendActions(for: .touchUpInside)
        }
        return picker
    }

    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}
