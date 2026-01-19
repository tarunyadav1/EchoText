import Foundation

/// Represents the available transcription engine backends
enum TranscriptionEngine: String, Codable, CaseIterable, Identifiable {
    case whisper = "whisper"
    case parakeet = "parakeet"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .whisper:
            return "Whisper"
        case .parakeet:
            return "Parakeet (Turbo)"
        }
    }

    var description: String {
        switch self {
        case .whisper:
            return "OpenAI's Whisper model via WhisperKit. Supports 99+ languages with excellent accuracy."
        case .parakeet:
            return "NVIDIA's Parakeet model via FluidAudio. Up to 190x realtime speed. English only."
        }
    }

    var icon: String {
        switch self {
        case .whisper:
            return "waveform.circle"
        case .parakeet:
            return "bolt.circle"
        }
    }

    var speedDescription: String {
        switch self {
        case .whisper:
            return "10-50x realtime"
        case .parakeet:
            return "110-190x realtime"
        }
    }

    var languageSupport: String {
        switch self {
        case .whisper:
            return "99+ languages"
        case .parakeet:
            return "English only"
        }
    }

    var isEnglishOnly: Bool {
        switch self {
        case .whisper:
            return false
        case .parakeet:
            return true
        }
    }

    /// Badge color for UI
    var badgeColor: String {
        switch self {
        case .whisper:
            return "blue"
        case .parakeet:
            return "orange"
        }
    }
}
