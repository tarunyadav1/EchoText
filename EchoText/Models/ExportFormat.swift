import Foundation

/// Supported export formats for transcriptions
enum ExportFormat: String, CaseIterable, Identifiable, Codable {
    case txt
    case srt
    case vtt
    case md
    case pdf
    case docx
    case csv
    case html
    case json
    case echotext

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .txt: return "Plain Text"
        case .srt: return "SubRip Subtitle"
        case .vtt: return "WebVTT"
        case .md: return "Markdown"
        case .pdf: return "PDF Document"
        case .docx: return "Word Document"
        case .csv: return "CSV Spreadsheet"
        case .html: return "Web Page"
        case .json: return "JSON Data"
        case .echotext: return "EchoText Bundle"
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
        case .pdf:
            return "Print-ready PDF document"
        case .docx:
            return "Microsoft Word document"
        case .csv:
            return "Spreadsheet format with speaker and timestamps"
        case .html:
            return "Formatted web page with styles"
        case .json:
            return "Machine-readable JSON data"
        case .echotext:
            return "Bundle with media and editable transcription"
        }
    }

    var mimeType: String {
        switch self {
        case .txt: return "text/plain"
        case .srt: return "application/x-subrip"
        case .vtt: return "text/vtt"
        case .md: return "text/markdown"
        case .pdf: return "application/pdf"
        case .docx: return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case .csv: return "text/csv"
        case .html: return "text/html"
        case .json: return "application/json"
        case .echotext: return "application/x-echotext"
        }
    }

    /// Whether this format includes the original media file
    var includesMedia: Bool {
        switch self {
        case .echotext: return true
        default: return false
        }
    }

    /// Whether this format preserves edit history
    var preservesEditHistory: Bool {
        switch self {
        case .echotext: return true
        default: return false
        }
    }

    /// Whether this format can be re-imported into the app
    var isReimportable: Bool {
        switch self {
        case .echotext, .json: return true
        default: return false
        }
    }

    /// Formats that only export transcription text (no media)
    static var textOnlyFormats: [ExportFormat] {
        allCases.filter { !$0.includesMedia }
    }

    /// Formats that include media and full document state
    static var bundleFormats: [ExportFormat] {
        allCases.filter { $0.includesMedia }
    }
}
