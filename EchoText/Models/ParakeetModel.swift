import Foundation

/// Represents a Parakeet model variant with its metadata
struct ParakeetModel: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let version: ModelVersion
    let downloadSize: Int64
    let memoryRequired: Int64
    let isEnglishOnly: Bool
    let relativeSpeechRecognitionSpeed: Double

    enum ModelVersion: String, Codable, CaseIterable {
        case v2 = "v2"
        case v3 = "v3"
        case realtime = "realtime"

        var displayName: String {
            switch self {
            case .v2: return "TDT v2"
            case .v3: return "TDT v3"
            case .realtime: return "Realtime"
            }
        }

        var description: String {
            switch self {
            case .v2: return "English only, highest recall"
            case .v3: return "25 European languages"
            case .realtime: return "Streaming, lowest latency"
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
        switch version {
        case .v2:
            return "Turbo (English)"
        case .v3:
            return "Multilingual"
        case .realtime:
            return "Streaming"
        }
    }

    /// Description of the quality level
    var qualityDescription: String {
        switch version {
        case .v2:
            return "Fastest English transcription with high accuracy"
        case .v3:
            return "Multi-language support with excellent speed"
        case .realtime:
            return "Real-time streaming with minimal latency"
        }
    }

    /// Language support description
    var languageSupport: String {
        switch version {
        case .v2:
            return "English only"
        case .v3:
            return "25 languages"
        case .realtime:
            return "English only"
        }
    }

    static let availableModels: [ParakeetModel] = [
        ParakeetModel(
            id: "parakeet-tdt-0.6b-v2",
            name: "Parakeet TDT v2",
            version: .v2,
            downloadSize: 600_000_000,
            memoryRequired: 800_000_000,
            isEnglishOnly: true,
            relativeSpeechRecognitionSpeed: 190.0
        ),
        // Note: v3 supports multiple languages but we're focusing on English for now
        // Uncomment when ready to support multilingual Parakeet
        // ParakeetModel(
        //     id: "parakeet-tdt-0.6b-v3",
        //     name: "Parakeet TDT v3",
        //     version: .v3,
        //     downloadSize: 600_000_000,
        //     memoryRequired: 800_000_000,
        //     isEnglishOnly: false,
        //     relativeSpeechRecognitionSpeed: 150.0
        // ),
    ]

    static var defaultModel: ParakeetModel {
        availableModels.first { $0.version == .v2 } ?? availableModels[0]
    }

    /// FluidAudio model version enum mapping
    var fluidAudioVersion: String {
        switch version {
        case .v2: return "v2"
        case .v3: return "v3"
        case .realtime: return "realtime"
        }
    }
}
