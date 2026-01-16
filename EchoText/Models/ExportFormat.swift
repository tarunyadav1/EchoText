import Foundation

/// Supported export formats for transcriptions
enum ExportFormat: String, CaseIterable, Identifiable {
    case txt
    case srt
    case vtt
    case md

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .txt: return "Plain Text"
        case .srt: return "SubRip Subtitle"
        case .vtt: return "WebVTT"
        case .md: return "Markdown"
        }
    }

    var fileExtension: String { rawValue }

    var description: String {
        switch self {
        case .txt:
            return "Simple text file with transcription"
        case .srt:
            return "SubRip subtitle format with timestamps"
        case .vtt:
            return "WebVTT subtitle format for web videos"
        case .md:
            return "Markdown format with formatting"
        }
    }

    var mimeType: String {
        switch self {
        case .txt: return "text/plain"
        case .srt: return "application/x-subrip"
        case .vtt: return "text/vtt"
        case .md: return "text/markdown"
        }
    }
}
