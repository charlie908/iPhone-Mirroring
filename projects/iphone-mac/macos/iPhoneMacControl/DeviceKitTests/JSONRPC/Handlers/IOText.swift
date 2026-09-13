import XCTest
import os

private enum Constants {
    static let typingFrequency = 120
}

struct IOTextRequest: Codable {
    let text: String
}

@MainActor
struct IOTextMethodHandler: RPCMethodHandler {
    static let methodName = "device.io.text"

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Self.self)
    )

    func execute(params: JSONValue?) async throws -> JSONValue {
        let request = try decodeParams(IOTextRequest.self, from: params)

        do {
            let start = Date()

            try await inputText(request.text)

            let duration = Date().timeIntervalSince(start)
            logger.info("Text input duration took \(duration)")
            return .object(["success": .bool(true)])
        } catch {
            logger.error("Error inputting text: \(error)")
            throw RPCMethodError.internalError("Error inputting text: \(error.localizedDescription)")
        }
    }

    private func inputText(_ text: String) async throws {
        guard !text.isEmpty else { return }
        try await RunnerDaemonProxy().send(
            string: text,
            typingFrequency: Constants.typingFrequency
        )
    }
}
