import AppKit
import AVFoundation
import CoreMedia
import OSLog
import SwiftUI

struct NativeH264StreamView: NSViewRepresentable {
    @ObservedObject var status: StreamStatus

    func makeNSView(context: Context) -> H264DisplayView {
        let view = H264DisplayView()
        context.coordinator.attach(view)
        context.coordinator.connect()
        return view
    }

    func updateNSView(_ view: H264DisplayView, context: Context) {
        context.coordinator.attach(view)
        context.coordinator.connect()
    }

    static func dismantleNSView(_ view: H264DisplayView, coordinator: Coordinator) {
        coordinator.disconnect()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(status: status)
    }

    @MainActor
    final class Coordinator {
        private let status: StreamStatus
        private weak var displayView: H264DisplayView?
        private var connected = false
        private var formatDescription: CMVideoFormatDescription?
        private var lastSPS: Data?
        private var lastPPS: Data?
        private var waitingForKeyframe = true
        private var displayedFrameCount = 0
        private let logger = Logger(subsystem: "com.example.iphonemac.mac", category: "NativeVideo")

        init(status: StreamStatus) {
            self.status = status
        }

        func attach(_ view: H264DisplayView) {
            displayView = view
        }

        func connect() {
            guard !connected else { return }
            connected = true
            status.state = .loading
            DirectPeerTransport.shared.videoHandler = { [weak self] message in
                self?.consume(message)
            }
            DirectPeerTransport.shared.start()
            logger.info("Waiting for iPhone H264 stream")
        }

        func disconnect() {
            DirectPeerTransport.shared.videoHandler = nil
            connected = false
            formatDescription = nil
            lastSPS = nil
            lastPPS = nil
            waitingForKeyframe = true
            displayedFrameCount = 0
        }

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

        private func installFormat(from annexB: Data) {
            let units = AnnexB.units(in: annexB)
            guard let sps = units.first(where: { ($0.first ?? 0) & 0x1F == 7 }),
                  let pps = units.first(where: { ($0.first ?? 0) & 0x1F == 8 }) else { return }
            guard formatDescription == nil || sps != lastSPS || pps != lastPPS else { return }

            var description: CMFormatDescription?
            let result: OSStatus = sps.withUnsafeBytes { spsBytes in
                pps.withUnsafeBytes { ppsBytes in
                    guard let spsBase = spsBytes.bindMemory(to: UInt8.self).baseAddress,
                          let ppsBase = ppsBytes.bindMemory(to: UInt8.self).baseAddress else { return -1 }
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

            guard result == noErr, let description = description else {
                logger.error("Could not create H264 format: \(result)")
                return
            }
            formatDescription = description
            lastSPS = sps
            lastPPS = pps
            waitingForKeyframe = true
            displayView?.displayLayer.flushAndRemoveImage()
        }

        private func enqueueFrame(_ annexB: Data) {
            guard let formatDescription = formatDescription, let displayView = displayView else { return }
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
            ) == kCMBlockBufferNoErr, let blockBuffer = blockBuffer else { return }

            let copyStatus = avcc.withUnsafeBytes { bytes -> OSStatus in
                guard let base = bytes.baseAddress else { return -1 }
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
            guard sampleStatus == noErr, let sampleBuffer = sampleBuffer else { return }

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
                logger.info("First H264 keyframe displayed")
            }
            if status.state != .connected {
                status.state = .connected
            }
        }
    }
}

final class H264DisplayView: NSView {
    let displayLayer = AVSampleBufferDisplayLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        layer?.backgroundColor = NSColor.black.cgColor
        displayLayer.videoGravity = .resizeAspect
        displayLayer.backgroundColor = NSColor.black.cgColor
        layer?.addSublayer(displayLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
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
