import Foundation

/// Metadata for a video from a URL (YouTube, Vimeo, etc.)
struct URLVideoMetadata: Codable, Equatable {
    /// Unique identifier from the platform (e.g., YouTube video ID)
    let id: String

    /// Video title
    let title: String

    /// Video duration in seconds
    let duration: TimeInterval

    /// URL to video thumbnail
    let thumbnailURL: URL?

    /// Platform name (e.g., "YouTube", "Vimeo", "Twitter")
    let platform: String?

    /// Original URL provided by user
    let originalURL: URL

    /// Uploader/channel name
    let uploader: String?

    /// Upload date if available
    let uploadDate: Date?

    /// Formatted duration string (e.g., "3:45" or "1:23:45")
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    /// Platform icon name for SF Symbols
    var platformIcon: String {
        switch platform?.lowercased() {
        case "youtube":
            return "play.rectangle.fill"
        case "vimeo":
            return "v.circle.fill"
        case "twitter", "x":
            return "bubble.left.fill"
        case "tiktok":
            return "music.note"
        case "instagram":
            return "camera.fill"
        case "facebook":
            return "person.2.fill"
        case "twitch":
            return "tv.fill"
        default:
            return "link"
        }
    }

    /// Platform brand color
    var platformColor: String {
        switch platform?.lowercased() {
        case "youtube":
            return "FF0000"  // YouTube Red
        case "vimeo":
            return "1AB7EA"  // Vimeo Blue
        case "twitter", "x":
            return "1DA1F2"  // Twitter Blue
        case "tiktok":
            return "010101"  // TikTok Black
        case "instagram":
            return "E4405F"  // Instagram Pink
        case "facebook":
            return "1877F2"  // Facebook Blue
        case "twitch":
            return "9146FF"  // Twitch Purple
        default:
            return "808080"  // Default Gray
        }
    }
}

/// Errors that can occur during URL download
enum URLDownloadError: LocalizedError {
    case bundledBinaryMissing
    case invalidURL
    case unsupportedPlatform
    case videoUnavailable(reason: String)
    case downloadFailed(reason: String)
    case audioExtractionFailed(reason: String)
    case metadataParsingFailed
    case cancelled
    case networkError(Error)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .bundledBinaryMissing:
            return "yt-dlp binary not found in app bundle. Please reinstall the app."
        case .invalidURL:
            return "The URL format is invalid. Please check and try again."
        case .unsupportedPlatform:
            return "This website is not supported for video download."
        case .videoUnavailable(let reason):
            return "Video unavailable: \(reason)"
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        case .audioExtractionFailed(let reason):
            return "Could not extract audio: \(reason)"
        case .metadataParsingFailed:
            return "Could not parse video information."
        case .cancelled:
            return "Download was cancelled."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unknown(let error):
            return "An error occurred: \(error.localizedDescription)"
        }
    }
}
