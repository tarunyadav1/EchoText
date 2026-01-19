import Foundation
import AppKit
import UniformTypeIdentifiers

/// Service for handling Voice Memos app integration
/// Voice Memos stores recordings in ~/Library/Group Containers/group.com.apple.VoiceMemos.shared/Recordings/
/// and uses file promises when dragging to other apps
final class VoiceMemosIntegration {

    // MARK: - Singleton

    static let shared = VoiceMemosIntegration()

    private init() {}

    // MARK: - Constants

    /// Voice Memos recordings directory path
    private static let voiceMemosPath = "Library/Group Containers/group.com.apple.VoiceMemos.shared/Recordings"

    /// Supported audio format from Voice Memos
    static let voiceMemosFormat = "m4a"

    /// UTTypes that Voice Memos can provide
    static let supportedTypes: [UTType] = [
        .mpeg4Audio,
        .audio,
        UTType("com.apple.m4a-audio") ?? .mpeg4Audio
    ]

    // MARK: - Public Methods

    /// Check if a URL is from Voice Memos
    func isVoiceMemoURL(_ url: URL) -> Bool {
        let path = url.path
        return path.contains("group.com.apple.VoiceMemos") ||
               path.contains("VoiceMemos.shared") ||
               (path.hasSuffix(".m4a") && path.contains("Recordings"))
    }

    /// Get the Voice Memos recordings directory
    func getVoiceMemosDirectory() -> URL? {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let voiceMemosURL = homeDirectory.appendingPathComponent(Self.voiceMemosPath)

        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: voiceMemosURL.path, isDirectory: &isDirectory),
           isDirectory.boolValue {
            return voiceMemosURL
        }

        return nil
    }

    /// Copy a Voice Memo file to a temporary location for transcription
    /// - Parameter sourceURL: The original Voice Memo file URL
    /// - Returns: URL to the temporary copy, or nil if failed
    func copyToTemporaryLocation(_ sourceURL: URL) async throws -> URL {
        let fileManager = FileManager.default

        // Create temporary directory for Voice Memos
        let tempDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("EchoText")
            .appendingPathComponent("VoiceMemos")

        try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        // Generate unique filename
        let timestamp = Int(Date().timeIntervalSince1970)
        let originalName = sourceURL.deletingPathExtension().lastPathComponent
        let sanitizedName = originalName.replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "_", options: .regularExpression)
        let fileName = "\(sanitizedName)_\(timestamp).\(Self.voiceMemosFormat)"
        let destinationURL = tempDirectory.appendingPathComponent(fileName)

        // Remove existing file if present
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        // Copy the file
        try fileManager.copyItem(at: sourceURL, to: destinationURL)

        NSLog("[VoiceMemosIntegration] Copied Voice Memo to: %@", destinationURL.path)

        return destinationURL
    }

    /// Clean up temporary Voice Memo files
    func cleanupTemporaryFiles() {
        let fileManager = FileManager.default
        let tempDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("EchoText")
            .appendingPathComponent("VoiceMemos")

        do {
            if fileManager.fileExists(atPath: tempDirectory.path) {
                try fileManager.removeItem(at: tempDirectory)
                NSLog("[VoiceMemosIntegration] Cleaned up temporary Voice Memos directory")
            }
        } catch {
            NSLog("[VoiceMemosIntegration] Failed to cleanup: %@", error.localizedDescription)
        }
    }

    /// Clean up a specific temporary file
    func cleanupFile(at url: URL) {
        let fileManager = FileManager.default

        // Only clean up files in our temporary directory
        guard url.path.contains("EchoText/VoiceMemos") else { return }

        do {
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
                NSLog("[VoiceMemosIntegration] Cleaned up file: %@", url.lastPathComponent)
            }
        } catch {
            NSLog("[VoiceMemosIntegration] Failed to cleanup file: %@", error.localizedDescription)
        }
    }
}

// MARK: - Thread-Safe URL Collector

/// Actor for thread-safe URL collection during async operations
private actor URLCollector {
    private var urls: [URL] = []

    func append(_ url: URL) {
        urls.append(url)
    }

    func getURLs() -> [URL] {
        return urls
    }
}

// MARK: - File Promise Handler

/// Handles NSFilePromiseReceiver for Voice Memos drag and drop
@MainActor
final class VoiceMemosDropHandler: NSObject {

    /// Receive files from file promise providers (Voice Memos uses this)
    /// - Parameters:
    ///   - providers: The NSItemProviders from the drop
    ///   - completion: Callback with the received file URLs
    func handleFilePromises(
        from providers: [NSItemProvider],
        completion: @escaping ([URL]) -> Void
    ) {
        // Use an actor for thread-safe URL collection
        let urlCollector = URLCollector()

        let group = DispatchGroup()

        for provider in providers {
            // Check for file promise first (Voice Memos uses this)
            if provider.hasRepresentationConforming(toTypeIdentifier: UTType.fileURL.identifier, fileOptions: .openInPlace) {
                group.enter()

                provider.loadFileRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { url, error in
                    if let error = error {
                        NSLog("[VoiceMemosDropHandler] Error loading file: %@", error.localizedDescription)
                        group.leave()
                        return
                    }

                    guard let url = url else {
                        group.leave()
                        return
                    }

                    // Copy file to temporary location since the provided URL may be temporary
                    Task {
                        defer { group.leave() }
                        do {
                            let copiedURL = try await VoiceMemosIntegration.shared.copyToTemporaryLocation(url)
                            await urlCollector.append(copiedURL)
                        } catch {
                            NSLog("[VoiceMemosDropHandler] Failed to copy file: %@", error.localizedDescription)
                            // Still try to use the original URL
                            await urlCollector.append(url)
                        }
                    }
                }
            }
            // Fall back to regular URL loading
            else if provider.canLoadObject(ofClass: URL.self) {
                group.enter()

                _ = provider.loadObject(ofClass: URL.self) { url, error in
                    defer { group.leave() }

                    if let error = error {
                        NSLog("[VoiceMemosDropHandler] Error loading URL: %@", error.localizedDescription)
                        return
                    }

                    guard let url = url else { return }

                    Task {
                        await urlCollector.append(url)
                    }
                }
            }
            // Check for audio types specifically
            else {
                for audioType in VoiceMemosIntegration.supportedTypes {
                    if provider.hasItemConformingToTypeIdentifier(audioType.identifier) {
                        group.enter()

                        provider.loadInPlaceFileRepresentation(forTypeIdentifier: audioType.identifier) { url, inPlace, error in
                            if let error = error {
                                NSLog("[VoiceMemosDropHandler] Error loading audio: %@", error.localizedDescription)
                                group.leave()
                                return
                            }

                            guard let url = url else {
                                group.leave()
                                return
                            }

                            Task {
                                defer { group.leave() }
                                do {
                                    let copiedURL = try await VoiceMemosIntegration.shared.copyToTemporaryLocation(url)
                                    await urlCollector.append(copiedURL)
                                } catch {
                                    await urlCollector.append(url)
                                }
                            }
                        }
                        break
                    }
                }
            }
        }

        group.notify(queue: .main) {
            // Small delay to allow async copy operations to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                Task {
                    let urls = await urlCollector.getURLs()
                    await MainActor.run {
                        completion(urls)
                    }
                }
            }
        }
    }

    /// Check if the providers contain Voice Memos content
    func containsVoiceMemos(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            // Check for m4a audio type
            if provider.hasItemConformingToTypeIdentifier(UTType.mpeg4Audio.identifier) {
                return true
            }

            // Check for generic audio
            if provider.hasItemConformingToTypeIdentifier(UTType.audio.identifier) {
                return true
            }

            // Check for file URL that might be Voice Memo
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                return true
            }
        }

        return false
    }
}

// MARK: - NSFilePromiseReceiver Delegate

/// Coordinator for handling file promise operations
final class FilePromiseCoordinator: NSObject, NSFilePromiseProviderDelegate {

    let destinationURL: URL

    init(destinationURL: URL) {
        self.destinationURL = destinationURL
        super.init()
    }

    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        return "VoiceMemo_\(timestamp).m4a"
    }

    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, writePromiseTo url: URL, completionHandler: @escaping (Error?) -> Void) {
        // This is called when writing promises, not receiving them
        completionHandler(nil)
    }

    func operationQueue(for filePromiseProvider: NSFilePromiseProvider) -> OperationQueue {
        return OperationQueue.main
    }
}
