import Foundation

/// Recording mode determines how the user starts and stops recording
enum RecordingMode: String, Codable, CaseIterable, Identifiable {
    case pressToToggle = "toggle"
    case holdToRecord = "hold"
    case voiceActivity = "vad"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pressToToggle:
            return "Press to Toggle"
        case .holdToRecord:
            return "Hold to Record"
        case .voiceActivity:
            return "Voice Activity"
        }
    }

    var description: String {
        switch self {
        case .pressToToggle:
            return "Press the shortcut to start, press again to stop"
        case .holdToRecord:
            return "Hold the shortcut to record, release to stop"
        case .voiceActivity:
            return "Automatically stop when you stop speaking"
        }
    }

    var iconName: String {
        switch self {
        case .pressToToggle:
            return "rectangle.and.hand.point.up.left.filled"
        case .holdToRecord:
            return "hand.tap.fill"
        case .voiceActivity:
            return "waveform.badge.mic"
        }
    }
}
