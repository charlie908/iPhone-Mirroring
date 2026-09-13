import AVFoundation
import CoreMedia
import OSLog
import SwiftUI
import UIKit

/// Displays the iPhone's original H.264 stream. The Mac only relays bytes: it
/// no longer decodes and re-encodes every frame for the native visionOS app.
struct NativeH264StreamView: UIViewRepresentable {
    let host: String
    @ObservedObject var status: StreamStatus

    func makeUIView(context: Context) -> H264DisplayView {
        let view = H264DisplayView()
        context.coordinator.attach(view)
        context.coordinator.connect(host: host)
        return view
    }

    func updateUIView(_ view: H264DisplayView, context: Context) {
        context.coordinator.attach(view)
        context.coordinator.connect(host: host)
    }

    static func dismantleUIView(_ view: H264DisplayView, coordinator: Coordinator) {
        coordinator.disconnect()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(status: status)
    }

    @MainActor
    final class Coordinator {
        private let status: StreamStatus
        private weak var displayView: H264DisplayView?
        private var socket: URLSessionWebSocketTask?
        private var receiveTask: Task<Void, Never>?
        private var connectedHost = ""
        private var formatDescription: CMVideoFormatDescription?
        private var lastSPS: Data?
        private var lastPPS: Data?
        private var waitingForKeyframe = true
        private var displayedFrameCount = 0
        private let logger = Logger(subsystem: "com.example.phoneview.vision", category: "NativeVideo")

        init(status: StreamStatus) {
            self.status = status
        }

        func attach(_ view: H264DisplayView) {
            displayView = view
        }

        func connect(host: String) {
            guard host != connectedHost || socket == nil else { return }
            disconnect()
            connectedHost = host

            guard let url = URL(string: "ws://\(host):8999/video/raw") else {
                status.state = .failed
                return
            }

            status.state = .loading
            let socket = URLSession.shared.webSocketTask(with: url)
            self.socket = socket
            socket.resume()
            logger.info("Raw H264 connection opened")
            print("PhoneView NativeVideo: connection opened to \(url.absoluteString)")

            receiveTask = Task { [weak self, weak socket] in
                guard let self, let socket else { return }
                do {
                    while !Task.isCancelled {
                        let message = try await socket.receive()
                        switch message {
                        case .data(let data):
                            await MainActor.run { self.consume(data) }
                        case .string:
                            break
                        @unknown default:
                            break
                        }
                    }
                } catch {
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        self.logger.error("Raw H264 connection ended: \(error.localizedDescription, privacy: .public)")
                        self.status.state = .disconnected
                        self.socket = nil
                    }
                    try? await Task.sleep(for: .seconds(1))
                    guard !Task.isCancelled else { return }
                    await MainActor.run { self.connect(host: host) }
                }
            }
        }

        func disconnect() {
            receiveTask?.cancel()
            receiveTask = nil
            socket?.cancel(with: .goingAway, reason: nil)
            socket = nil
            connectedHost = ""
            formatDescription = nil
            lastSPS = nil
            lastPPS = nil
            waitingForKeyframe = true
            displayedFrameCount = 0
        }

        @MainActor
        private func consume(_ message: Data) {
            guard message.count >= 9 else { return }
            let type = message[message.startIndex]
            let payload = Data(message.dropFirst(9))

            switch type {
            case 0x02:
                installFormat(from: payload)
            case 0x01:
                enqueueFrame(payload)
            case 0xFF:
                displayView?.displayLayer.flushAndRemoveImage()
                waitingForKeyframe = true
                status.state = .disconnected
            default:
                break
            }
        }

        @MainActor
        private func installFormat(from annexB: Data) {
            let units = AnnexB.units(in: annexB)
            guard let sps = units.first(where: { ($0.first ?? 0) & 0x1F == 7 }),
                  let pps = units.first(where: { ($0.first ?? 0) & 0x1F == 8 }) else {
                return
            }

            // ReplayKit repeats identical parameter sets before every IDR.
            // Reinstalling them would flush the display about once per second.
            guard formatDescription == nil || sps != lastSPS || pps != lastPPS else {
                return
            }

            var description: CMFormatDescription?
            let result: OSStatus = sps.withUnsafeBytes { spsBytes in
                pps.withUnsafeBytes { ppsBytes in
                    guard let spsBase = spsBytes.bindMemory(to: UInt8.self).baseAddress,
                          let ppsBase = ppsBytes.bindMemory(to: UInt8.self).baseAddress else {
                        return -1
                    }
                    var pointers = [spsBase, ppsBase]
                    var sizes = [sps.count, pps.count]
                    return CMVideoFormatDescriptionCreateFromH264ParameterSets(
                        allocator: kCFAllocatorDefault,
                        parameterSetCount: 2,
                        parameterSetPointers: &pointers,
                        parameterSetSizes: &sizes,
                        nalUnitHeaderLength: 4,
                        formatDescriptionOut: &description
                    )
                }
            }

            guard result == noErr, let description else {
                logger.error("Could not create H264 format: \(result)")
                return
            }
            formatDescription = description
            lastSPS = sps
            lastPPS = pps
            waitingForKeyframe = true
            displayView?.displayLayer.flushAndRemoveImage()
            logger.info("H264 format installed: SPS=\(sps.count) PPS=\(pps.count)")
            print("PhoneView NativeVideo: format installed SPS=\(sps.count) PPS=\(pps.count)")
        }

        @MainActor
        private func enqueueFrame(_ annexB: Data) {
            guard let formatDescription, let displayView else { return }
            let units = AnnexB.units(in: annexB)
            guard !units.isEmpty else { return }

            let isKeyframe = units.contains { (($0.first ?? 0) & 0x1F) == 5 }
            if waitingForKeyframe {
                guard isKeyframe else { return }
                waitingForKeyframe = false
            }

            var avcc = Data()
            avcc.reserveCapacity(annexB.count)
            for unit in units {
                var length = UInt32(unit.count).bigEndian
                withUnsafeBytes(of: &length) { avcc.append(contentsOf: $0) }
                avcc.append(unit)
            }

            var blockBuffer: CMBlockBuffer?
            guard CMBlockBufferCreateWithMemoryBlock(
                allocator: kCFAllocatorDefault,
                memoryBlock: nil,
                blockLength: avcc.count,
                blockAllocator: kCFAllocatorDefault,
                customBlockSource: nil,
                offsetToData: 0,
                dataLength: avcc.count,
                flags: 0,
                blockBufferOut: &blockBuffer
            ) == kCMBlockBufferNoErr, let blockBuffer else { return }

            let copyStatus = avcc.withUnsafeBytes { bytes in
                guard let base = bytes.baseAddress else { return OSStatus(-1) }
                return CMBlockBufferReplaceDataBytes(
                    with: base,
                    blockBuffer: blockBuffer,
                    offsetIntoDestination: 0,
                    dataLength: avcc.count
                )
            }
            guard copyStatus == kCMBlockBufferNoErr else { return }

            var sampleBuffer: CMSampleBuffer?
            var sampleSize = avcc.count
            let sampleStatus = CMSampleBufferCreateReady(
                allocator: kCFAllocatorDefault,
                dataBuffer: blockBuffer,
                formatDescription: formatDescription,
                sampleCount: 1,
                sampleTimingEntryCount: 0,
                sampleTimingArray: nil,
                sampleSizeEntryCount: 1,
                sampleSizeArray: &sampleSize,
                sampleBufferOut: &sampleBuffer
            )
            guard sampleStatus == noErr, let sampleBuffer else {
                logger.error("Could not create sample buffer: \(sampleStatus)")
                return
            }

            // AVSampleBufferDisplayLayer reads DisplayImmediately from the
            // per-sample attachment dictionary. A CM-level attachment is
            // accepted but ignored, leaving untimed samples permanently black.
            if let attachments = CMSampleBufferGetSampleAttachmentsArray(
                sampleBuffer,
                createIfNecessary: true
            ) as? [NSMutableDictionary], let first = attachments.first {
                first[kCMSampleAttachmentKey_DisplayImmediately] = true
            }

            if displayView.displayLayer.status == .failed {
                displayView.displayLayer.flush()
            }
            displayView.displayLayer.enqueue(sampleBuffer)
            displayedFrameCount += 1
            if displayedFrameCount == 1 {
                logger.info("First H264 keyframe enqueued")
                print("PhoneView NativeVideo: first keyframe enqueued (\(avcc.count) bytes)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self, weak displayView] in
                    guard let self, let displayView else { return }
                    if displayView.displayLayer.status == .failed {
                        let message = displayView.displayLayer.error?.localizedDescription ?? "unknown"
                        self.logger.error(
                            "Display layer failed: \(message, privacy: .public)"
                        )
                        print("PhoneView NativeVideo: display layer FAILED: \(message)")
                        self.status.state = .failed
                    } else {
                        self.logger.info("Display layer accepted native H264")
                        print("PhoneView NativeVideo: display layer status=\(displayView.displayLayer.status.rawValue)")
                    }
                }
            }
            if status.state != .connected {
                status.state = .connected
            }
        }
    }
}

final class H264DisplayView: UIView {
    let displayLayer = AVSampleBufferDisplayLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        displayLayer.videoGravity = .resizeAspect
        displayLayer.backgroundColor = UIColor.black.cgColor
        layer.addSublayer(displayLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        displayLayer.frame = bounds
    }
}

private enum AnnexB {
    static func units(in data: Data) -> [Data] {
        let bytes = [UInt8](data)
        var starts: [(offset: Int, payload: Int)] = []
        var index = 0

        while index + 3 < bytes.count {
            if bytes[index] == 0, bytes[index + 1] == 0 {
                if bytes[index + 2] == 1 {
                    starts.append((index, index + 3))
                    index += 3
                    continue
                }
                if bytes[index + 2] == 0, bytes[index + 3] == 1 {
                    starts.append((index, index + 4))
                    index += 4
                    continue
                }
            }
            index += 1
        }

        guard !starts.isEmpty else { return [] }
        return starts.enumerated().compactMap { position, start in
            let end = position + 1 < starts.count ? starts[position + 1].offset : bytes.count
            guard start.payload < end else { return nil }
            return Data(bytes[start.payload..<end])
        }
    }
}
