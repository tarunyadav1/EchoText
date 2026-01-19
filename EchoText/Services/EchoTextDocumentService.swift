import Foundation
import Compression
import UniformTypeIdentifiers
import AppKit

/// Errors that can occur when working with EchoText documents
enum EchoTextDocumentError: LocalizedError {
    case invalidArchive
    case missingMetadata
    case missingTranscription
    case missingMedia
    case unsupportedVersion(String)
    case compressionFailed
    case decompressionFailed
    case fileWriteFailed(Error)
    case fileReadFailed(Error)
    case invalidData
    case temporaryDirectoryFailed

    var errorDescription: String? {
        switch self {
        case .invalidArchive:
            return "The file is not a valid EchoText document."
        case .missingMetadata:
            return "The document is missing required metadata."
        case .missingTranscription:
            return "The document is missing the transcription data."
        case .missingMedia:
            return "The document is missing the original media file."
        case .unsupportedVersion(let version):
            return "This document was created with a newer version (\(version)) of EchoText."
        case .compressionFailed:
            return "Failed to compress the document."
        case .decompressionFailed:
            return "Failed to decompress the document."
        case .fileWriteFailed(let error):
            return "Failed to write the document: \(error.localizedDescription)"
        case .fileReadFailed(let error):
            return "Failed to read the document: \(error.localizedDescription)"
        case .invalidData:
            return "The document contains invalid data."
        case .temporaryDirectoryFailed:
            return "Failed to create temporary directory for media extraction."
        }
    }
}

/// Service for saving and loading EchoText documents
final class EchoTextDocumentService {
    // MARK: - Singleton

    static let shared = EchoTextDocumentService()

    private init() {}

    // MARK: - Private Properties

    private let fileManager = FileManager.default
    private let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    /// Directory for extracted media files (cached for playback)
    private var extractedMediaDirectory: URL {
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return cacheDir.appendingPathComponent("EchoText/ExtractedMedia", isDirectory: true)
    }

    // MARK: - Public Methods

    /// Save an EchoText document to a file
    /// - Parameters:
    ///   - document: The document to save
    ///   - url: The destination URL (if nil, shows save panel)
    /// - Returns: The URL where the document was saved
    @MainActor
    func save(_ document: EchoTextDocument, to url: URL? = nil) async throws -> URL {
        let destinationURL: URL

        if let url = url {
            destinationURL = url
        } else {
            // Show save panel
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [UTType(filenameExtension: EchoTextDocument.fileExtension) ?? .data]
            savePanel.nameFieldStringValue = document.metadata.title ?? "transcription"
            savePanel.title = "Save EchoText Document"
            savePanel.message = "Choose where to save the transcription with media"

            guard savePanel.runModal() == .OK, let selectedURL = savePanel.url else {
                throw CocoaError(.userCancelled)
            }
            destinationURL = selectedURL
        }

        // Ensure the file has the correct extension
        var finalURL = destinationURL
        if finalURL.pathExtension.lowercased() != EchoTextDocument.fileExtension {
            finalURL = finalURL.appendingPathExtension(EchoTextDocument.fileExtension)
        }

        try await saveToFile(document, at: finalURL)
        return finalURL
    }

    /// Load an EchoText document from a file
    /// - Parameter url: The URL of the .echotext file
    /// - Returns: The loaded document
    func load(from url: URL) async throws -> EchoTextDocument {
        return try await loadFromFile(url)
    }

    /// Load an EchoText document with a file picker
    /// - Returns: The loaded document, or nil if cancelled
    @MainActor
    func loadWithPicker() async throws -> EchoTextDocument? {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [UTType(filenameExtension: EchoTextDocument.fileExtension) ?? .data]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.title = "Open EchoText Document"
        openPanel.message = "Select an EchoText document to open"

        guard openPanel.runModal() == .OK, let url = openPanel.url else {
            return nil
        }

        return try await load(from: url)
    }

    /// Extract the media file from a document for playback
    /// - Parameter document: The document containing the media
    /// - Returns: URL to the extracted media file (in a temporary location)
    func extractMedia(from document: EchoTextDocument) throws -> URL {
        // Create extraction directory if needed
        try fileManager.createDirectory(at: extractedMediaDirectory, withIntermediateDirectories: true)

        // Create a unique filename using the document ID
        let mediaFilename = "\(document.id.uuidString).\(document.metadata.mediaExtension)"
        let mediaURL = extractedMediaDirectory.appendingPathComponent(mediaFilename)

        // Check if already extracted
        if fileManager.fileExists(atPath: mediaURL.path) {
            return mediaURL
        }

        // Write media data to file
        try document.mediaData.write(to: mediaURL)

        return mediaURL
    }

    /// Extract media to a specific location (for export)
    /// - Parameters:
    ///   - document: The document containing the media
    ///   - destinationURL: Where to save the extracted media
    func extractMedia(from document: EchoTextDocument, to destinationURL: URL) throws {
        try document.mediaData.write(to: destinationURL)
    }

    /// Clean up extracted media files
    func cleanupExtractedMedia() {
        try? fileManager.removeItem(at: extractedMediaDirectory)
    }

    /// Clean up extracted media for a specific document
    func cleanupExtractedMedia(for documentId: UUID, mediaExtension: String) {
        let mediaFilename = "\(documentId.uuidString).\(mediaExtension)"
        let mediaURL = extractedMediaDirectory.appendingPathComponent(mediaFilename)
        try? fileManager.removeItem(at: mediaURL)
    }

    // MARK: - Private Methods

    /// Save document to a zip archive
    private func saveToFile(_ document: EchoTextDocument, at url: URL) async throws {
        // Create a temporary directory for building the archive
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        // Write metadata.json
        let metadataData = try jsonEncoder.encode(document.metadata)
        let metadataURL = tempDir.appendingPathComponent(EchoTextDocument.ArchiveFilenames.metadata)
        try metadataData.write(to: metadataURL)

        // Write transcription.json
        let transcriptionData = try jsonEncoder.encode(document.transcription)
        let transcriptionURL = tempDir.appendingPathComponent(EchoTextDocument.ArchiveFilenames.transcription)
        try transcriptionData.write(to: transcriptionURL)

        // Write history.json (only if there's history)
        if !document.editHistory.operations.isEmpty {
            let historyData = try jsonEncoder.encode(document.editHistory)
            let historyURL = tempDir.appendingPathComponent(EchoTextDocument.ArchiveFilenames.history)
            try historyData.write(to: historyURL)
        }

        // Write media file
        let mediaFilename = EchoTextDocument.ArchiveFilenames.media(extension: document.metadata.mediaExtension)
        let mediaURL = tempDir.appendingPathComponent(mediaFilename)
        try document.mediaData.write(to: mediaURL)

        // Create zip archive
        try createZipArchive(from: tempDir, to: url)
    }

    /// Load document from a zip archive
    private func loadFromFile(_ url: URL) async throws -> EchoTextDocument {
        // Create a temporary directory for extraction
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        // Extract zip archive
        try extractZipArchive(from: url, to: tempDir)

        // Read metadata.json
        let metadataURL = tempDir.appendingPathComponent(EchoTextDocument.ArchiveFilenames.metadata)
        guard fileManager.fileExists(atPath: metadataURL.path) else {
            throw EchoTextDocumentError.missingMetadata
        }
        let metadataData = try Data(contentsOf: metadataURL)
        let metadata = try jsonDecoder.decode(EchoTextDocumentMetadata.self, from: metadataData)

        // Check version compatibility
        if let currentMajor = majorVersion(from: echoTextDocumentVersion),
           let documentMajor = majorVersion(from: metadata.formatVersion),
           documentMajor > currentMajor {
            throw EchoTextDocumentError.unsupportedVersion(metadata.formatVersion)
        }

        // Read transcription.json
        let transcriptionURL = tempDir.appendingPathComponent(EchoTextDocument.ArchiveFilenames.transcription)
        guard fileManager.fileExists(atPath: transcriptionURL.path) else {
            throw EchoTextDocumentError.missingTranscription
        }
        let transcriptionData = try Data(contentsOf: transcriptionURL)
        let transcription = try jsonDecoder.decode(TranscriptionResult.self, from: transcriptionData)

        // Read history.json (optional)
        var editHistory = EditHistory()
        let historyURL = tempDir.appendingPathComponent(EchoTextDocument.ArchiveFilenames.history)
        if fileManager.fileExists(atPath: historyURL.path) {
            let historyData = try Data(contentsOf: historyURL)
            editHistory = try jsonDecoder.decode(EditHistory.self, from: historyData)
        }

        // Read media file
        let mediaFilename = EchoTextDocument.ArchiveFilenames.media(extension: metadata.mediaExtension)
        let mediaURL = tempDir.appendingPathComponent(mediaFilename)
        guard fileManager.fileExists(atPath: mediaURL.path) else {
            throw EchoTextDocumentError.missingMedia
        }
        let mediaData = try Data(contentsOf: mediaURL)

        return EchoTextDocument(
            metadata: metadata,
            transcription: transcription,
            mediaData: mediaData,
            editHistory: editHistory,
            fileURL: url
        )
    }

    /// Create a zip archive from a directory
    private func createZipArchive(from sourceDir: URL, to destinationURL: URL) throws {
        // Remove existing file if present
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        // Use the built-in Archive utility via Process for zip creation
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent", sourceDir.path, destinationURL.path]

        let pipe = Pipe()
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            print("Zip creation failed: \(errorMessage)")
            throw EchoTextDocumentError.compressionFailed
        }
    }

    /// Extract a zip archive to a directory
    private func extractZipArchive(from archiveURL: URL, to destinationDir: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", archiveURL.path, destinationDir.path]

        let pipe = Pipe()
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            print("Zip extraction failed: \(errorMessage)")
            throw EchoTextDocumentError.decompressionFailed
        }

        // ditto creates a subfolder with the archive name, we need to handle that
        // Check if there's a single directory in destinationDir and move its contents up
        let contents = try fileManager.contentsOfDirectory(at: destinationDir, includingPropertiesForKeys: nil)
        if contents.count == 1, contents[0].hasDirectoryPath {
            let subDir = contents[0]
            let subContents = try fileManager.contentsOfDirectory(at: subDir, includingPropertiesForKeys: nil)
            for item in subContents {
                let destItem = destinationDir.appendingPathComponent(item.lastPathComponent)
                try fileManager.moveItem(at: item, to: destItem)
            }
            try fileManager.removeItem(at: subDir)
        }
    }

    /// Extract major version number from version string
    private func majorVersion(from versionString: String) -> Int? {
        let components = versionString.split(separator: ".")
        guard let first = components.first else { return nil }
        return Int(first)
    }
}

// MARK: - Batch Operations

extension EchoTextDocumentService {
    /// Save multiple documents to a directory
    @MainActor
    func saveBatch(_ documents: [EchoTextDocument]) async throws -> URL? {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true
        openPanel.title = "Choose Export Directory"
        openPanel.message = "Select a folder to save all EchoText documents"

        guard openPanel.runModal() == .OK, let directory = openPanel.url else {
            return nil
        }

        for (index, document) in documents.enumerated() {
            let filename = document.metadata.title ?? "transcription_\(index + 1)"
            let sanitizedFilename = sanitizeFilename(filename)
            let fileURL = directory
                .appendingPathComponent(sanitizedFilename)
                .appendingPathExtension(EchoTextDocument.fileExtension)

            try await saveToFile(document, at: fileURL)
        }

        return directory
    }

    /// Sanitize a filename by removing invalid characters
    private func sanitizeFilename(_ filename: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        return filename
            .components(separatedBy: invalidCharacters)
            .joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Document Info

extension EchoTextDocumentService {
    /// Get document info without fully loading it (for quick previews)
    func getDocumentInfo(from url: URL) async throws -> EchoTextDocumentMetadata {
        // Create a temporary directory for extraction
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        // Extract only metadata.json using ditto with specific file
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-j", "-o", url.path, "*/\(EchoTextDocument.ArchiveFilenames.metadata)", "-d", tempDir.path]

        try process.run()
        process.waitUntilExit()

        // Find the metadata file (might be in a subdirectory)
        let metadataURL = tempDir.appendingPathComponent(EchoTextDocument.ArchiveFilenames.metadata)

        guard fileManager.fileExists(atPath: metadataURL.path) else {
            throw EchoTextDocumentError.missingMetadata
        }

        let metadataData = try Data(contentsOf: metadataURL)
        return try jsonDecoder.decode(EchoTextDocumentMetadata.self, from: metadataData)
    }
}
