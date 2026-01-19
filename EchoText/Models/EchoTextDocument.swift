import Foundation

/// Current version of the EchoText document format
let echoTextDocumentVersion = "1.0.0"

/// Represents an edit operation for undo/redo support
enum EditOperation: Codable {
    case updateSegmentText(segmentId: UUID, oldText: String, newText: String)
    case deleteSegment(segmentId: UUID, segment: TranscriptionSegment, index: Int)
    case mergeSegments(firstSegmentId: UUID, secondSegmentId: UUID, mergedSegment: TranscriptionSegment, originalFirst: TranscriptionSegment, originalSecond: TranscriptionSegment)
    case toggleFavorite(segmentId: UUID, wasFavorite: Bool)
    case updateSpeaker(segmentId: UUID, oldSpeakerId: String?, newSpeakerId: String?)

    enum CodingKeys: String, CodingKey {
        case type, segmentId, oldText, newText, segment, index
        case firstSegmentId, secondSegmentId, mergedSegment, originalFirst, originalSecond
        case wasFavorite, oldSpeakerId, newSpeakerId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "updateSegmentText":
            let segmentId = try container.decode(UUID.self, forKey: .segmentId)
            let oldText = try container.decode(String.self, forKey: .oldText)
            let newText = try container.decode(String.self, forKey: .newText)
            self = .updateSegmentText(segmentId: segmentId, oldText: oldText, newText: newText)
        case "deleteSegment":
            let segmentId = try container.decode(UUID.self, forKey: .segmentId)
            let segment = try container.decode(TranscriptionSegment.self, forKey: .segment)
            let index = try container.decode(Int.self, forKey: .index)
            self = .deleteSegment(segmentId: segmentId, segment: segment, index: index)
        case "mergeSegments":
            let firstId = try container.decode(UUID.self, forKey: .firstSegmentId)
            let secondId = try container.decode(UUID.self, forKey: .secondSegmentId)
            let merged = try container.decode(TranscriptionSegment.self, forKey: .mergedSegment)
            let first = try container.decode(TranscriptionSegment.self, forKey: .originalFirst)
            let second = try container.decode(TranscriptionSegment.self, forKey: .originalSecond)
            self = .mergeSegments(firstSegmentId: firstId, secondSegmentId: secondId, mergedSegment: merged, originalFirst: first, originalSecond: second)
        case "toggleFavorite":
            let segmentId = try container.decode(UUID.self, forKey: .segmentId)
            let wasFavorite = try container.decode(Bool.self, forKey: .wasFavorite)
            self = .toggleFavorite(segmentId: segmentId, wasFavorite: wasFavorite)
        case "updateSpeaker":
            let segmentId = try container.decode(UUID.self, forKey: .segmentId)
            let oldSpeakerId = try container.decodeIfPresent(String.self, forKey: .oldSpeakerId)
            let newSpeakerId = try container.decodeIfPresent(String.self, forKey: .newSpeakerId)
            self = .updateSpeaker(segmentId: segmentId, oldSpeakerId: oldSpeakerId, newSpeakerId: newSpeakerId)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown edit operation type: \(type)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .updateSegmentText(let segmentId, let oldText, let newText):
            try container.encode("updateSegmentText", forKey: .type)
            try container.encode(segmentId, forKey: .segmentId)
            try container.encode(oldText, forKey: .oldText)
            try container.encode(newText, forKey: .newText)
        case .deleteSegment(let segmentId, let segment, let index):
            try container.encode("deleteSegment", forKey: .type)
            try container.encode(segmentId, forKey: .segmentId)
            try container.encode(segment, forKey: .segment)
            try container.encode(index, forKey: .index)
        case .mergeSegments(let firstId, let secondId, let merged, let first, let second):
            try container.encode("mergeSegments", forKey: .type)
            try container.encode(firstId, forKey: .firstSegmentId)
            try container.encode(secondId, forKey: .secondSegmentId)
            try container.encode(merged, forKey: .mergedSegment)
            try container.encode(first, forKey: .originalFirst)
            try container.encode(second, forKey: .originalSecond)
        case .toggleFavorite(let segmentId, let wasFavorite):
            try container.encode("toggleFavorite", forKey: .type)
            try container.encode(segmentId, forKey: .segmentId)
            try container.encode(wasFavorite, forKey: .wasFavorite)
        case .updateSpeaker(let segmentId, let oldSpeakerId, let newSpeakerId):
            try container.encode("updateSpeaker", forKey: .type)
            try container.encode(segmentId, forKey: .segmentId)
            try container.encodeIfPresent(oldSpeakerId, forKey: .oldSpeakerId)
            try container.encodeIfPresent(newSpeakerId, forKey: .newSpeakerId)
        }
    }
}

// MARK: - EditOperation Equatable

extension EditOperation: Equatable {
    static func == (lhs: EditOperation, rhs: EditOperation) -> Bool {
        switch (lhs, rhs) {
        case let (.updateSegmentText(lhsId, lhsOld, lhsNew), .updateSegmentText(rhsId, rhsOld, rhsNew)):
            return lhsId == rhsId && lhsOld == rhsOld && lhsNew == rhsNew
        case let (.deleteSegment(lhsId, lhsSeg, lhsIdx), .deleteSegment(rhsId, rhsSeg, rhsIdx)):
            return lhsId == rhsId && lhsSeg.uuid == rhsSeg.uuid && lhsIdx == rhsIdx
        case let (.mergeSegments(lhsFirst, lhsSecond, lhsMerged, _, _), .mergeSegments(rhsFirst, rhsSecond, rhsMerged, _, _)):
            return lhsFirst == rhsFirst && lhsSecond == rhsSecond && lhsMerged.uuid == rhsMerged.uuid
        case let (.toggleFavorite(lhsId, lhsWas), .toggleFavorite(rhsId, rhsWas)):
            return lhsId == rhsId && lhsWas == rhsWas
        case let (.updateSpeaker(lhsId, lhsOld, lhsNew), .updateSpeaker(rhsId, rhsOld, rhsNew)):
            return lhsId == rhsId && lhsOld == rhsOld && lhsNew == rhsNew
        default:
            return false
        }
    }
}

/// Metadata about the EchoText document
struct EchoTextDocumentMetadata: Codable {
    /// Version of the document format
    let formatVersion: String

    /// App version that created this document
    let appVersion: String

    /// Date the document was created
    let createdAt: Date

    /// Date the document was last modified
    var modifiedAt: Date

    /// Original filename of the media
    let originalFilename: String

    /// File extension of the original media (e.g., "mp3", "mp4")
    let mediaExtension: String

    /// MIME type of the original media
    let mediaMimeType: String

    /// Size of the original media file in bytes
    let mediaFileSize: Int64

    /// Whisper model used for transcription
    let modelUsed: String

    /// Language detected/used for transcription
    let language: String?

    /// Duration of the media in seconds
    let mediaDuration: TimeInterval

    /// Optional title for the transcription
    var title: String?

    /// Optional notes/description
    var notes: String?

    /// Tags for organization
    var tags: [String]

    init(
        originalFilename: String,
        mediaExtension: String,
        mediaMimeType: String,
        mediaFileSize: Int64,
        modelUsed: String,
        language: String?,
        mediaDuration: TimeInterval,
        title: String? = nil,
        notes: String? = nil,
        tags: [String] = []
    ) {
        self.formatVersion = echoTextDocumentVersion
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.originalFilename = originalFilename
        self.mediaExtension = mediaExtension
        self.mediaMimeType = mediaMimeType
        self.mediaFileSize = mediaFileSize
        self.modelUsed = modelUsed
        self.language = language
        self.mediaDuration = mediaDuration
        self.title = title
        self.notes = notes
        self.tags = tags
    }
}

/// Edit history for undo/redo support
struct EditHistory: Codable {
    /// Stack of edit operations (newest at end)
    var operations: [EditOperation]

    /// Current position in the history (for undo/redo)
    var currentIndex: Int

    init() {
        self.operations = []
        self.currentIndex = -1
    }

    /// Whether there are operations that can be undone
    var canUndo: Bool {
        currentIndex >= 0
    }

    /// Whether there are operations that can be redone
    var canRedo: Bool {
        currentIndex < operations.count - 1
    }

    /// Add a new operation to the history
    mutating func addOperation(_ operation: EditOperation) {
        // Remove any operations after current index (invalidate redo stack)
        if currentIndex < operations.count - 1 {
            operations.removeLast(operations.count - currentIndex - 1)
        }
        operations.append(operation)
        currentIndex = operations.count - 1
    }

    /// Get the operation to undo (does not modify state)
    func operationToUndo() -> EditOperation? {
        guard canUndo else { return nil }
        return operations[currentIndex]
    }

    /// Get the operation to redo (does not modify state)
    func operationToRedo() -> EditOperation? {
        guard canRedo else { return nil }
        return operations[currentIndex + 1]
    }

    /// Move back in history (call after undoing)
    mutating func didUndo() {
        if canUndo {
            currentIndex -= 1
        }
    }

    /// Move forward in history (call after redoing)
    mutating func didRedo() {
        if canRedo {
            currentIndex += 1
        }
    }

    /// Clear all history
    mutating func clear() {
        operations.removeAll()
        currentIndex = -1
    }
}

/// The main EchoText document structure
/// When saved, this becomes a .echotext file (zip archive) containing:
/// - media.{extension} - The original media file
/// - transcription.json - The TranscriptionResult
/// - metadata.json - Document metadata
/// - history.json - Optional edit history
struct EchoTextDocument: Identifiable {
    /// Unique identifier for this document
    let id: UUID

    /// Document metadata
    var metadata: EchoTextDocumentMetadata

    /// The transcription result with all segments and edits
    var transcription: TranscriptionResult

    /// Original media file data
    let mediaData: Data

    /// Edit history for undo/redo support
    var editHistory: EditHistory

    /// Whether the document has unsaved changes
    var hasUnsavedChanges: Bool = false

    /// The file URL if this document was loaded from disk
    var fileURL: URL?

    init(
        id: UUID = UUID(),
        metadata: EchoTextDocumentMetadata,
        transcription: TranscriptionResult,
        mediaData: Data,
        editHistory: EditHistory = EditHistory(),
        fileURL: URL? = nil
    ) {
        self.id = id
        self.metadata = metadata
        self.transcription = transcription
        self.mediaData = mediaData
        self.editHistory = editHistory
        self.fileURL = fileURL
    }

    /// Create a document from a transcription result and media file
    static func create(
        from transcription: TranscriptionResult,
        mediaURL: URL
    ) throws -> EchoTextDocument {
        let mediaData = try Data(contentsOf: mediaURL)
        let fileExtension = mediaURL.pathExtension.lowercased()
        let filename = mediaURL.lastPathComponent
        let attributes = try FileManager.default.attributesOfItem(atPath: mediaURL.path)
        let fileSize = attributes[.size] as? Int64 ?? Int64(mediaData.count)

        let mimeType = mimeType(for: fileExtension)

        let metadata = EchoTextDocumentMetadata(
            originalFilename: filename,
            mediaExtension: fileExtension,
            mediaMimeType: mimeType,
            mediaFileSize: fileSize,
            modelUsed: transcription.modelUsed,
            language: transcription.language,
            mediaDuration: transcription.duration,
            title: filename
        )

        return EchoTextDocument(
            metadata: metadata,
            transcription: transcription,
            mediaData: mediaData
        )
    }

    /// Mark the document as modified
    mutating func markAsModified() {
        hasUnsavedChanges = true
        metadata.modifiedAt = Date()
    }

    // MARK: - Helper Methods

    /// Get MIME type for a file extension
    private static func mimeType(for extension: String) -> String {
        switch `extension`.lowercased() {
        // Audio
        case "mp3": return "audio/mpeg"
        case "wav": return "audio/wav"
        case "m4a": return "audio/mp4"
        case "aac": return "audio/aac"
        case "ogg": return "audio/ogg"
        case "flac": return "audio/flac"
        case "wma": return "audio/x-ms-wma"
        case "aiff", "aif": return "audio/aiff"
        // Video
        case "mp4": return "video/mp4"
        case "mov": return "video/quicktime"
        case "avi": return "video/x-msvideo"
        case "mkv": return "video/x-matroska"
        case "webm": return "video/webm"
        case "wmv": return "video/x-ms-wmv"
        case "flv": return "video/x-flv"
        case "m4v": return "video/x-m4v"
        default: return "application/octet-stream"
        }
    }
}

// MARK: - File Extension Constants

extension EchoTextDocument {
    /// The file extension for EchoText documents
    static let fileExtension = "echotext"

    /// The UTI for EchoText documents
    static let uniformTypeIdentifier = "com.echotext.document"

    /// The MIME type for EchoText documents
    static let mimeType = "application/x-echotext"

    /// Internal filenames within the archive
    enum ArchiveFilenames {
        static let metadata = "metadata.json"
        static let transcription = "transcription.json"
        static let history = "history.json"
        static func media(extension ext: String) -> String {
            "media.\(ext)"
        }
    }
}
