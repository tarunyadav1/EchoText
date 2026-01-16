import Foundation

/// Represents the current state of audio recording
enum RecordingState: Equatable {
    case idle
    case recording
    case processing

    var isActive: Bool {
        switch self {
        case .recording, .processing:
            return true
        case .idle:
            return false
        }
    }

    var displayText: String {
        switch self {
        case .idle:
            return "Ready"
        case .recording:
            return "Recording..."
        case .processing:
            return "Processing..."
        }
    }

    var systemImageName: String {
        switch self {
        case .idle:
            return "mic"
        case .recording:
            return "mic.fill"
        case .processing:
            return "waveform"
        }
    }
}
