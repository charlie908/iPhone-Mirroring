import SwiftUI

@MainActor
final class StreamStatus: ObservableObject {
    enum State: String {
        case loading = "Waiting for iPhone…"
        case connected = "iPhone connected"
        case disconnected = "Disconnected"
        case failed = "Video unavailable"

        var color: Color {
            switch self {
            case .connected: return .green
            case .loading: return .orange
            case .disconnected, .failed: return .red
            }
        }
    }

    @Published var state: State = .loading
}
