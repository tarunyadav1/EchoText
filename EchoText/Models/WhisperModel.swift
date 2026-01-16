import Foundation

/// Represents a Whisper model variant with its metadata
struct WhisperModel: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let size: ModelSize
    let downloadSize: Int64
    let memoryRequired: Int64
    let isMultilingual: Bool
    let relativeSpeechRecognitionSpeed: Double

    enum ModelSize: String, Codable, CaseIterable {
        case tiny
        case base
        case small
        case medium
        case large
        case largev2 = "large-v2"
        case largev3 = "large-v3"
        case largev3Turbo = "large-v3-turbo"

        var displayName: String {
            switch self {
            case .tiny: return "Tiny"
            case .base: return "Base"
            case .small: return "Small"
            case .medium: return "Medium"
            case .large: return "Large"
            case .largev2: return "Large v2"
            case .largev3: return "Large v3"
            case .largev3Turbo: return "Large v3 Turbo"
            }
        }
    }

    var formattedDownloadSize: String {
        ByteCountFormatter.string(fromByteCount: downloadSize, countStyle: .file)
    }

    var formattedMemoryRequired: String {
        ByteCountFormatter.string(fromByteCount: memoryRequired, countStyle: .memory)
    }

    /// User-friendly quality name for display
    var qualityName: String {
        switch size {
        case .tiny:
            return "Fastest"
        case .base:
            return "Fast"
        case .small:
            return "Balanced"
        case .medium:
            return "Accurate"
        case .large, .largev2, .largev3:
            return "Most Accurate"
        case .largev3Turbo:
            return "Best Quality"
        }
    }

    /// Description of the quality level
    var qualityDescription: String {
        switch size {
        case .tiny:
            return "Quick transcription, lower accuracy"
        case .base:
            return "Good balance of speed and accuracy"
        case .small:
            return "Better accuracy, moderate speed"
        case .medium:
            return "High accuracy, slower processing"
        case .large, .largev2, .largev3:
            return "Highest accuracy, slowest processing"
        case .largev3Turbo:
            return "Excellent accuracy with optimized speed"
        }
    }

    static let availableModels: [WhisperModel] = [
        WhisperModel(
            id: "openai_whisper-tiny",
            name: "Whisper Tiny",
            size: .tiny,
            downloadSize: 75_000_000,
            memoryRequired: 150_000_000,
            isMultilingual: true,
            relativeSpeechRecognitionSpeed: 32.0
        ),
        WhisperModel(
            id: "openai_whisper-base",
            name: "Whisper Base",
            size: .base,
            downloadSize: 145_000_000,
            memoryRequired: 290_000_000,
            isMultilingual: true,
            relativeSpeechRecognitionSpeed: 16.0
        ),
        WhisperModel(
            id: "openai_whisper-small",
            name: "Whisper Small",
            size: .small,
            downloadSize: 483_000_000,
            memoryRequired: 966_000_000,
            isMultilingual: true,
            relativeSpeechRecognitionSpeed: 6.0
        ),
        WhisperModel(
            id: "openai_whisper-medium",
            name: "Whisper Medium",
            size: .medium,
            downloadSize: 1_530_000_000,
            memoryRequired: 3_000_000_000,
            isMultilingual: true,
            relativeSpeechRecognitionSpeed: 2.0
        ),
        WhisperModel(
            id: "openai_whisper-large-v3",
            name: "Whisper Large v3",
            size: .largev3,
            downloadSize: 3_090_000_000,
            memoryRequired: 6_000_000_000,
            isMultilingual: true,
            relativeSpeechRecognitionSpeed: 1.0
        ),
        WhisperModel(
            id: "openai_whisper-large-v3-turbo",
            name: "Whisper Large v3 Turbo",
            size: .largev3Turbo,
            downloadSize: 1_620_000_000,
            memoryRequired: 3_200_000_000,
            isMultilingual: true,
            relativeSpeechRecognitionSpeed: 8.0
        )
    ]

    static var defaultModel: WhisperModel {
        availableModels.first { $0.size == .base } ?? availableModels[0]
    }
}
