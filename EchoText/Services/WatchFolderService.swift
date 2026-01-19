import Foundation
import Combine
import UserNotifications
import AppKit

/// Errors that can occur during watch folder operations
enum WatchFolderError: LocalizedError {
    case invalidInputFolder
    case invalidOutputFolder
    case monitoringFailed(Error)
    case transcriptionFailed(Error)
    case exportFailed(Error)
    case fileAccessDenied(URL)

    var errorDescription: String? {
        switch self {
        case .invalidInputFolder:
            return "The input folder path is invalid or inaccessible."
        case .invalidOutputFolder:
            return "The output folder path is invalid or inaccessible."
        case .monitoringFailed(let error):
            return "Failed to monitor folder: \(error.localizedDescription)"
        case .transcriptionFailed(let error):
            return "Transcription failed: \(error.localizedDescription)"
        case .exportFailed(let error):
            return "Export failed: \(error.localizedDescription)"
        case .fileAccessDenied(let url):
            return "Cannot access file: \(url.lastPathComponent)"
        }
    }
}

/// Status of a queued file for transcription
struct WatchFolderQueueItem: Identifiable {
    let id = UUID()
    let fileURL: URL
    let addedAt: Date
    var status: Status
    var error: Error?

    enum Status {
        case pending
        case processing
        case completed
        case failed
    }

    var fileName: String {
        fileURL.lastPathComponent
    }
}

/// Service responsible for monitoring a folder and auto-transcribing new audio/video files
@MainActor
final class WatchFolderService: ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var isMonitoring = false
    @Published private(set) var queue: [WatchFolderQueueItem] = []
    @Published private(set) var processedCount = 0
    @Published private(set) var lastError: WatchFolderError?

    // MARK: - Supported File Extensions

    /// Audio file extensions supported for transcription
    static let supportedAudioExtensions: Set<String> = [
        "mp3", "wav", "m4a", "aac", "flac", "ogg", "wma", "aiff", "aif", "caf"
    ]

    /// Video file extensions supported for transcription
    static let supportedVideoExtensions: Set<String> = [
        "mp4", "mov", "m4v", "avi", "mkv", "webm", "wmv", "flv", "3gp"
    ]

    /// All supported media extensions
    static var supportedExtensions: Set<String> {
        supportedAudioExtensions.union(supportedVideoExtensions)
    }

    // MARK: - Private Properties

    private var dispatchSource: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var monitoredFiles: Set<String> = []
    private var processingTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    // Dependencies (injected)
    private weak var whisperService: WhisperService?
    private weak var parakeetService: ParakeetService?
    private var settings: AppSettings?

    // MARK: - Singleton

    static let shared = WatchFolderService()

    private init() {
        setupNotificationPermissions()
    }

    // MARK: - Configuration

    /// Configure the service with required dependencies
    func configure(whisperService: WhisperService, parakeetService: ParakeetService, settings: AppSettings) {
        self.whisperService = whisperService
        self.parakeetService = parakeetService
        self.settings = settings

        // Start monitoring if enabled in settings
        if settings.watchFolderEnabled, let inputPath = settings.watchFolderInputPath {
            Task {
                try? await startMonitoring(inputPath: inputPath)
            }
        }
    }

    // MARK: - Monitoring Control

    /// Start monitoring the specified folder for new media files
    func startMonitoring(inputPath: String) async throws {
        // Validate input folder
        let inputURL = URL(fileURLWithPath: inputPath)
        var isDirectory: ObjCBool = false

        guard FileManager.default.fileExists(atPath: inputPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            lastError = .invalidInputFolder
            throw WatchFolderError.invalidInputFolder
        }

        // Validate output folder if specified
        if let outputPath = settings?.watchFolderOutputPath {
            var isOutDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: outputPath, isDirectory: &isOutDir),
                  isOutDir.boolValue else {
                lastError = .invalidOutputFolder
                throw WatchFolderError.invalidOutputFolder
            }
        }

        // Stop any existing monitoring
        stopMonitoring()

        // Open file descriptor for the directory
        fileDescriptor = open(inputPath, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            lastError = .invalidInputFolder
            throw WatchFolderError.invalidInputFolder
        }

        // Get initial list of files to avoid processing existing files
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: inputPath) {
            monitoredFiles = Set(contents)
        }

        // Create dispatch source for file system monitoring
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: .write,
            queue: DispatchQueue.global(qos: .utility)
        )

        source.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleDirectoryChange(at: inputURL)
            }
        }

        source.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 {
                close(fd)
            }
            self?.fileDescriptor = -1
        }

        source.resume()
        dispatchSource = source
        isMonitoring = true

        NSLog("[WatchFolderService] Started monitoring: %@", inputPath)

        // Start processing queue
        startProcessingQueue()
    }

    /// Stop monitoring the folder
    func stopMonitoring() {
        dispatchSource?.cancel()
        dispatchSource = nil

        processingTask?.cancel()
        processingTask = nil

        isMonitoring = false
        monitoredFiles.removeAll()

        NSLog("[WatchFolderService] Stopped monitoring")
    }

    // MARK: - Queue Management

    /// Manually add a file to the transcription queue
    func addToQueue(_ fileURL: URL) {
        guard isSupportedFile(fileURL) else { return }

        // Check if already in queue
        guard !queue.contains(where: { $0.fileURL == fileURL }) else { return }

        let item = WatchFolderQueueItem(
            fileURL: fileURL,
            addedAt: Date(),
            status: .pending
        )
        queue.append(item)

        NSLog("[WatchFolderService] Added to queue: %@", fileURL.lastPathComponent)
    }

    /// Remove a file from the queue
    func removeFromQueue(_ item: WatchFolderQueueItem) {
        queue.removeAll { $0.id == item.id }
    }

    /// Clear all completed/failed items from queue
    func clearCompletedItems() {
        queue.removeAll { $0.status == .completed || $0.status == .failed }
    }

    /// Retry a failed item
    func retryItem(_ item: WatchFolderQueueItem) {
        guard let index = queue.firstIndex(where: { $0.id == item.id }) else { return }
        queue[index].status = .pending
        queue[index].error = nil
    }

    // MARK: - Private Methods

    private func handleDirectoryChange(at directoryURL: URL) {
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: directoryURL.path) else {
            return
        }

        let currentFiles = Set(contents)
        let newFiles = currentFiles.subtracting(monitoredFiles)

        for fileName in newFiles {
            let fileURL = directoryURL.appendingPathComponent(fileName)

            // Skip hidden files and directories
            guard !fileName.hasPrefix(".") else { continue }

            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory),
                  !isDirectory.boolValue else { continue }

            // Check if it's a supported media file
            if isSupportedFile(fileURL) {
                // Wait a moment for file to be fully written
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    await MainActor.run {
                        self.addToQueue(fileURL)
                    }
                }
            }
        }

        // Update monitored files
        monitoredFiles = currentFiles
    }

    private func isSupportedFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return Self.supportedExtensions.contains(ext)
    }

    private func startProcessingQueue() {
        processingTask = Task {
            while !Task.isCancelled {
                await processNextItem()
                try? await Task.sleep(nanoseconds: 1_000_000_000) // Check every 1 second
            }
        }
    }

    private func processNextItem() async {
        // Find next pending item
        guard let index = queue.firstIndex(where: { $0.status == .pending }) else {
            return
        }

        // Check if the selected engine's model is ready
        guard let settings = settings else { return }

        switch settings.transcriptionEngine {
        case .parakeet:
            guard let parakeetService = parakeetService, parakeetService.isModelLoaded else { return }
        case .whisper:
            guard let whisperService = whisperService, whisperService.isModelLoaded else { return }
        }

        // Mark as processing
        queue[index].status = .processing
        let item = queue[index]

        do {
            // Transcribe the file
            let result = try await transcribeFile(item.fileURL)

            // Export the result
            try await exportResult(result, for: item.fileURL)

            // Mark as completed
            if let idx = queue.firstIndex(where: { $0.id == item.id }) {
                queue[idx].status = .completed
            }
            processedCount += 1

            // Send notification
            await sendCompletionNotification(for: item.fileURL, wordCount: result.wordCount)

            NSLog("[WatchFolderService] Completed: %@", item.fileName)

        } catch {
            NSLog("[WatchFolderService] Failed: %@ - %@", item.fileName, error.localizedDescription)

            if let idx = queue.firstIndex(where: { $0.id == item.id }) {
                queue[idx].status = .failed
                queue[idx].error = error
            }

            lastError = .transcriptionFailed(error)

            // Send failure notification
            await sendFailureNotification(for: item.fileURL, error: error)
        }
    }

    private func transcribeFile(_ fileURL: URL) async throws -> TranscriptionResult {
        guard let settings = settings else {
            throw WatchFolderError.transcriptionFailed(WhisperServiceError.modelNotLoaded)
        }

        let language = settings.selectedLanguage == "auto" ? nil : settings.selectedLanguage
        let removeFillers = settings.removeFillerWords

        switch settings.transcriptionEngine {
        case .parakeet:
            guard let parakeetService = parakeetService else {
                throw WatchFolderError.transcriptionFailed(ParakeetServiceError.modelNotLoaded)
            }
            return try await parakeetService.transcribe(audioURL: fileURL, removeFillers: removeFillers)

        case .whisper:
            guard let whisperService = whisperService else {
                throw WatchFolderError.transcriptionFailed(WhisperServiceError.modelNotLoaded)
            }
            return try await whisperService.transcribe(
                audioURL: fileURL,
                language: language,
                removeFillers: removeFillers
            )
        }
    }

    private func exportResult(_ result: TranscriptionResult, for sourceFile: URL) async throws {
        guard let settings = settings else { return }

        // Determine output directory
        let outputDirectory: URL
        if let outputPath = settings.watchFolderOutputPath {
            outputDirectory = URL(fileURLWithPath: outputPath)
        } else {
            // Use same directory as source file
            outputDirectory = sourceFile.deletingLastPathComponent()
        }

        // Generate output filename: originalName_timestamp.extension
        let originalName = sourceFile.deletingPathExtension().lastPathComponent
        let timestamp = formatTimestamp(Date())
        let format = settings.watchFolderExportFormat
        let outputFileName = "\(originalName)_\(timestamp).\(format.fileExtension)"
        let outputURL = outputDirectory.appendingPathComponent(outputFileName)

        // Export the transcription
        guard let data = ExportService.export(result, format: format) else {
            throw WatchFolderError.exportFailed(NSError(
                domain: "WatchFolderService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to export to \(format.displayName)"]
            ))
        }

        do {
            try data.write(to: outputURL)
            NSLog("[WatchFolderService] Exported to: %@", outputURL.path)
        } catch {
            throw WatchFolderError.exportFailed(error)
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: date)
    }

    // MARK: - Notifications

    private func setupNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                NSLog("[WatchFolderService] Notification permission error: %@", error.localizedDescription)
            }
        }
    }

    private func sendCompletionNotification(for fileURL: URL, wordCount: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "Transcription Complete"
        content.body = "\(fileURL.lastPathComponent) - \(wordCount) words transcribed"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    private func sendFailureNotification(for fileURL: URL, error: Error) async {
        let content = UNMutableNotificationContent()
        content.title = "Transcription Failed"
        content.body = "\(fileURL.lastPathComponent): \(error.localizedDescription)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        try? await UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - AppSettings Extension for Watch Folder

extension AppSettings {
    /// Convenience method to check if watch folder is properly configured
    var isWatchFolderConfigured: Bool {
        watchFolderEnabled && watchFolderInputPath != nil
    }
}
