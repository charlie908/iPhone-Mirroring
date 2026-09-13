import ReplayKit
import os.log

/// Main handler for the broadcast upload extension.
/// Receives screen frames from ReplayKit and streams them via WebSocket.
class SampleHandler: RPBroadcastSampleHandler {

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.nativebridge.broadcast", category: "SampleHandler")

    private var encoder: H264Encoder?
    private var webSocket: WebSocketClient?
    private let deviceKitForwarder = DirectDeviceKitForwarder()
    private let displaySleepAssertion = DisplaySleepAssertion()

    private var frameCount = 0
    private var startTime: CFAbsoluteTime = 0
    private var lastStatsTime: CFAbsoluteTime = 0

    private var isRunning = false
    private var encoderInitialized = false
    private var encoderResetRequested = false
    private var lastEncodedFrameTime: CFAbsoluteTime = 0
    private var lastEncoderRecoveryTime: CFAbsoluteTime = 0
    private var actualWidth: Int = 0
    private var actualHeight: Int = 0

    // MARK: - Lifecycle

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        logger.info("Broadcast started")

        if let result = displaySleepAssertion.acquire() {
            logger.info("Display sleep assertion result: \(result)")
        } else {
            logger.error("Display sleep assertion API is unavailable")
        }

        isRunning = true
        frameCount = 0
        encoderInitialized = false
        actualWidth = 0
        actualHeight = 0
        startTime = CFAbsoluteTimeGetCurrent()
        lastStatsTime = startTime
        lastEncodedFrameTime = startTime
        lastEncoderRecoveryTime = startTime

        // Update shared state
        updateBroadcastState(true)

        // Get server configuration
        let serverURL = getServerURL()
        logger.info("Connecting to server: \(serverURL)")

        // Encoder will be initialized lazily when first frame arrives
        // to use actual screen dimensions

        // Initialize WebSocket
        webSocket = WebSocketClient(url: serverURL)

        webSocket?.onConnect = { [weak self] in
            self?.logger.info("WebSocket connected")
            self?.updateServerConnectionState(true)
            // A new transport must begin with a fresh IDR + parameter sets.
            // Reusing an encoder after screen sleep/server restart can leave
            // it producing no usable output while ReplayKit still sends input.
            self?.encoderResetRequested = true

            // Send device info to server
            self?.sendDeviceInfo()
        }

        webSocket?.onDisconnect = { [weak self] error in
            if let error = error {
                self?.logger.error("WebSocket disconnected with error: \(error.localizedDescription)")
            } else {
                self?.logger.info("WebSocket disconnected")
            }
            self?.updateServerConnectionState(false)
        }

        webSocket?.onError = { [weak self] error in
            if let error = error {
                self?.logger.error("WebSocket error: \(error.localizedDescription)")
            }
        }

        webSocket?.onMessage = { [weak self] message in
            self?.deviceKitForwarder.handle(message)
        }

        // Connect to server
        webSocket?.connect()
    }

    override func broadcastPaused() {
        logger.info("Broadcast paused")
    }

    override func broadcastResumed() {
        logger.info("Broadcast resumed")
        encoderResetRequested = true
    }

    override func broadcastFinished() {
        logger.info("Broadcast finished")

        isRunning = false

        // Send end stream message
        webSocket?.send(ProtocolMessage.endStream())

        // Cleanup
        webSocket?.disconnect()
        webSocket = nil

        encoder?.stop()
        encoder = nil
        displaySleepAssertion.release()

        // Update shared state
        updateBroadcastState(false)
        updateServerConnectionState(false)

        // Log final stats
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        let avgFPS = elapsed > 0 ? Double(frameCount) / elapsed : 0
        logger.info("Broadcast ended. Total frames: \(self.frameCount), Average FPS: \(String(format: "%.1f", avgFPS))")
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard isRunning else { return }

        switch sampleBufferType {
        case .video:
            processVideoSample(sampleBuffer)

        case .audioApp:
            // App audio - not used in POC
            break

        case .audioMic:
            // Microphone audio - not used in POC
            break

        @unknown default:
            break
        }
    }

    // MARK: - Video Processing

    private func processVideoSample(_ sampleBuffer: CMSampleBuffer) {
        // Validate sample buffer
        guard CMSampleBufferIsValid(sampleBuffer),
              CMSampleBufferDataIsReady(sampleBuffer) else {
            return
        }

        // Get pixel buffer
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            logger.warning("Failed to get pixel buffer from sample")
            return
        }

        let encoderNow = CFAbsoluteTimeGetCurrent()
        if encoderResetRequested ||
            (encoderInitialized && encoderNow - lastEncodedFrameTime > 2.0 && encoderNow - lastEncoderRecoveryTime > 2.0) {
            logger.info("Recovering H264 encoder after resume/reconnect/stall")
            encoder?.stop()
            encoder = nil
            encoderInitialized = false
            encoderResetRequested = false
            lastEncoderRecoveryTime = encoderNow
            lastEncodedFrameTime = encoderNow
        }

        // Initialize encoder lazily with actual screen dimensions
        if !encoderInitialized {
            actualWidth = CVPixelBufferGetWidth(pixelBuffer)
            actualHeight = CVPixelBufferGetHeight(pixelBuffer)

            logger.info("Detected screen dimensions: \(self.actualWidth)x\(self.actualHeight)")

            // Initialize encoder with actual dimensions
            encoder = H264Encoder(
                width: actualWidth,
                height: actualHeight,
                fps: Constants.Video.defaultFPS,
                bitrate: Constants.Video.defaultBitrate
            )

            encoder?.onEncodedFrame = { [weak self] nalUnit, isKeyframe, timestamp in
                self?.handleEncodedFrame(nalUnit: nalUnit, isKeyframe: isKeyframe, timestamp: timestamp)
            }

            encoder?.onError = { [weak self] error in
                self?.logger.error("Encoder error: \(error.localizedDescription)")
            }

            encoderInitialized = true
            logger.info("Encoder initialized with dimensions: \(self.actualWidth)x\(self.actualHeight)")
        }

        // Get presentation timestamp
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        // Encode frame
        encoder?.encode(pixelBuffer: pixelBuffer, presentationTime: pts)

        frameCount += 1

        // Send periodic stats
        let now = CFAbsoluteTimeGetCurrent()
        if now - lastStatsTime >= 5.0 {
            sendStats()
            lastStatsTime = now
        }
    }

    // MARK: - Frame Handling

    private func handleEncodedFrame(nalUnit: Data, isKeyframe: Bool, timestamp: UInt64) {
        guard isRunning, let webSocket = webSocket, webSocket.isConnected else {
            return
        }

        lastEncodedFrameTime = CFAbsoluteTimeGetCurrent()

        // If keyframe, send SPS/PPS first
        if isKeyframe, let config = encoder?.getParameterSets() {
            let configMessage = ProtocolMessage.config(spsPps: config, timestamp: timestamp)
            webSocket.send(configMessage)
        }

        // Send video frame
        let frameMessage = ProtocolMessage.videoFrame(nalUnit: nalUnit, timestamp: timestamp)
        webSocket.send(frameMessage)
    }

    // MARK: - Helpers

    private func getServerURL() -> String {
        var host = Constants.Server.host
        var port = Constants.Server.port

        // Try to read from app group defaults
        if let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier) {
            if let savedHost = defaults.string(forKey: Constants.UserDefaultsKeys.serverHost), !savedHost.isEmpty {
                host = savedHost
            }
            if let savedPort = defaults.string(forKey: Constants.UserDefaultsKeys.serverPort),
               let portNumber = Int(savedPort) {
                port = portNumber
            }
        }

        return "ws://\(host):\(port)"
    }

    private func updateBroadcastState(_ isBroadcasting: Bool) {
        if let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier) {
            defaults.set(isBroadcasting, forKey: Constants.UserDefaultsKeys.isBroadcasting)
        }
    }

    private func updateServerConnectionState(_ isConnected: Bool) {
        if let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier) {
            defaults.set(isConnected, forKey: Constants.UserDefaultsKeys.isServerConnected)
        }
    }

    private func sendStats() {
        guard let webSocket = webSocket, webSocket.isConnected else { return }

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        let fps = elapsed > 0 ? Double(frameCount) / elapsed : 0

        let statsMessage = ProtocolMessage.stats(fps: fps, bitrate: Constants.Video.defaultBitrate)
        webSocket.send(statsMessage)
    }

    private func sendDeviceInfo() {
        guard let webSocket = webSocket, webSocket.isConnected else { return }

        let deviceInfo = DeviceInfo.current()
        let jsonString = deviceInfo.toJSON()

        logger.info("Sending device info: \(jsonString)")

        let deviceInfoMessage = ProtocolMessage.deviceInfo(json: jsonString)
        webSocket.send(deviceInfoMessage)
    }
}
