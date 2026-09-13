import Foundation
import VideoToolbox
import CoreMedia
import os.log

/// Hardware-accelerated H264 encoder using VideoToolbox.
class H264Encoder {

    // MARK: - Types

    typealias EncodedFrameCallback = (Data, Bool, UInt64) -> Void  // (nalUnit, isKeyframe, timestamp)
    typealias ErrorCallback = (Error) -> Void

    enum EncoderError: Error, LocalizedError {
        case sessionCreationFailed
        case encodingFailed(OSStatus)
        case invalidPixelBuffer

        var errorDescription: String? {
            switch self {
            case .sessionCreationFailed:
                return "Failed to create compression session"
            case .encodingFailed(let status):
                return "Encoding failed with status: \(status)"
            case .invalidPixelBuffer:
                return "Invalid pixel buffer"
            }
        }
    }

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.nativebridge.broadcast", category: "H264Encoder")

    private var session: VTCompressionSession?
    private let width: Int
    private let height: Int
    private let fps: Int
    private let bitrate: Int

    private var sps: Data?
    private var pps: Data?

    var onEncodedFrame: EncodedFrameCallback?
    var onError: ErrorCallback?

    private let encoderQueue = DispatchQueue(label: "com.nativebridge.encoder", qos: .userInteractive)
    private var frameCount: Int64 = 0

    // MARK: - Initialization

    init(width: Int, height: Int, fps: Int, bitrate: Int) {
        self.width = width
        self.height = height
        self.fps = fps
        self.bitrate = bitrate

        setupSession()
    }

    deinit {
        stop()
    }

    // MARK: - Setup

    private func setupSession() {
        // Encoder output callback
        let callback: VTCompressionOutputCallback = { outputCallbackRefCon, sourceFrameRefCon, status, infoFlags, sampleBuffer in
            guard let refCon = outputCallbackRefCon else { return }
            let encoder = Unmanaged<H264Encoder>.fromOpaque(refCon).takeUnretainedValue()
            encoder.handleEncodedSample(status: status, sampleBuffer: sampleBuffer)
        }

        // Create compression session
        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: Int32(width),
            height: Int32(height),
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: callback,
            refcon: Unmanaged.passUnretained(self).toOpaque(),
            compressionSessionOut: &session
        )

        guard status == noErr, let session = session else {
            logger.error("Failed to create compression session: \(status)")
            onError?(EncoderError.sessionCreationFailed)
            return
        }

        // Configure session for low latency streaming
        configureSession(session)

        // Prepare to encode
        VTCompressionSessionPrepareToEncodeFrames(session)

        logger.info("H264 encoder initialized: \(self.width)x\(self.height) @ \(self.fps)fps, \(self.bitrate/1000)kbps")
    }

    private func configureSession(_ session: VTCompressionSession) {
        // Real-time encoding for low latency
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)

        // Let VideoToolbox choose a level compatible with the actual iPhone
        // resolution and 60 fps. Forcing High 4.1 can stall at 1320x2868.
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ProfileLevel,
                            value: kVTProfileLevel_H264_High_AutoLevel)

        // Bitrate
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate,
                            value: bitrate as CFNumber)

        // Bitrate limit (allow 1.5x burst)
        let bitrateLimit = [bitrate * 3 / 2, 1] as CFArray
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_DataRateLimits,
                            value: bitrateLimit)

        // Frame rate
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ExpectedFrameRate,
                            value: fps as CFNumber)

        // Keyframe interval (every second) for fast recovery without frequent
        // decoder resets or a large bandwidth penalty.
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameInterval,
                            value: fps as CFNumber)

        // Disable B-frames for lower latency
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AllowFrameReordering,
                            value: kCFBooleanFalse)

        // Entropy coding - CABAC for better compression
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_H264EntropyMode,
                            value: kVTH264EntropyMode_CABAC)

        // Allow temporal compression (P-frames)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AllowTemporalCompression,
                            value: kCFBooleanTrue)
    }

    // MARK: - Encoding

    func encode(pixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        guard let session = session else {
            onError?(EncoderError.sessionCreationFailed)
            return
        }

        // Create frame properties
        var flags: VTEncodeInfoFlags = []

        // Duration
        let duration = CMTime(value: 1, timescale: CMTimeScale(fps))

        // Encode frame
        let status = VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: presentationTime,
            duration: duration,
            frameProperties: nil,
            sourceFrameRefcon: nil,
            infoFlagsOut: &flags
        )

        if status != noErr {
            logger.error("Encode frame failed: \(status)")
            onError?(EncoderError.encodingFailed(status))
        }
    }

    func forceKeyframe() {
        guard let session = session else { return }

        let properties: [CFString: Any] = [
            kVTEncodeFrameOptionKey_ForceKeyFrame: true
        ]

        // This will affect the next frame
        VTSessionSetProperties(session, propertyDictionary: properties as CFDictionary)
    }

    func stop() {
        if let session = session {
            VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid)
            VTCompressionSessionInvalidate(session)
            self.session = nil
        }
        logger.info("H264 encoder stopped")
    }

    // MARK: - Output Handling

    private func handleEncodedSample(status: OSStatus, sampleBuffer: CMSampleBuffer?) {
        guard status == noErr else {
            logger.error("Encoding callback error: \(status)")
            return
        }

        guard let sampleBuffer = sampleBuffer,
              CMSampleBufferDataIsReady(sampleBuffer) else {
            return
        }

        // Check if keyframe
        let isKeyframe = isKeyFrame(sampleBuffer)

        // Extract SPS/PPS from keyframes
        if isKeyframe {
            extractParameterSets(from: sampleBuffer)
        }

        // Get presentation timestamp
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let timestamp = UInt64(CMTimeGetSeconds(pts) * 1_000_000)

        // Extract NAL units
        guard let nalUnit = extractNALUnit(from: sampleBuffer) else {
            return
        }

        frameCount += 1

        // Callback with encoded data
        onEncodedFrame?(nalUnit, isKeyframe, timestamp)
    }

    private func isKeyFrame(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[CFString: Any]],
              let attachment = attachments.first else {
            return false
        }

        // Check for dependency flag (keyframes don't depend on others)
        let dependsOnOthers = attachment[kCMSampleAttachmentKey_DependsOnOthers] as? Bool ?? true
        return !dependsOnOthers
    }

    private func extractParameterSets(from sampleBuffer: CMSampleBuffer) {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            return
        }

        // Get SPS
        var spsSize: Int = 0
        var spsCount: Int = 0
        var spsPointer: UnsafePointer<UInt8>?

        var status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
            formatDescription,
            parameterSetIndex: 0,
            parameterSetPointerOut: &spsPointer,
            parameterSetSizeOut: &spsSize,
            parameterSetCountOut: &spsCount,
            nalUnitHeaderLengthOut: nil
        )

        if status == noErr, let spsPointer = spsPointer {
            sps = Data(bytes: spsPointer, count: spsSize)
        }

        // Get PPS
        var ppsSize: Int = 0
        var ppsPointer: UnsafePointer<UInt8>?

        status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
            formatDescription,
            parameterSetIndex: 1,
            parameterSetPointerOut: &ppsPointer,
            parameterSetSizeOut: &ppsSize,
            parameterSetCountOut: nil,
            nalUnitHeaderLengthOut: nil
        )

        if status == noErr, let ppsPointer = ppsPointer {
            pps = Data(bytes: ppsPointer, count: ppsSize)
        }
    }

    private func extractNALUnit(from sampleBuffer: CMSampleBuffer) -> Data? {
        guard let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return nil
        }

        var length: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?

        let status = CMBlockBufferGetDataPointer(
            dataBuffer,
            atOffset: 0,
            lengthAtOffsetOut: nil,
            totalLengthOut: &length,
            dataPointerOut: &dataPointer
        )

        guard status == noErr, let dataPointer = dataPointer else {
            return nil
        }

        // Convert AVCC format to Annex-B format
        return convertToAnnexB(data: Data(bytes: dataPointer, count: length))
    }

    private func convertToAnnexB(data: Data) -> Data {
        var result = Data()
        var offset = 0

        while offset < data.count - 4 {
            // Read NAL unit length (4 bytes, big-endian)
            let lengthData = data.subdata(in: offset..<(offset + 4))
            let length = lengthData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }

            offset += 4

            guard offset + Int(length) <= data.count else {
                break
            }

            // Add start code
            result.append(NALStartCode.fourByte)

            // Add NAL unit data
            result.append(data.subdata(in: offset..<(offset + Int(length))))

            offset += Int(length)
        }

        return result
    }

    // MARK: - Public Helpers

    func getParameterSets() -> Data? {
        guard let sps = sps, let pps = pps else {
            return nil
        }

        var result = Data()

        // SPS with start code
        result.append(NALStartCode.fourByte)
        result.append(sps)

        // PPS with start code
        result.append(NALStartCode.fourByte)
        result.append(pps)

        return result
    }
}
