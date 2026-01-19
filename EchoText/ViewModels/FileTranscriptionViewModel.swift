import Foundation
import SwiftUI
import Combine
import UniformTypeIdentifiers

/// Source of a queued file - local or remote (URL)
enum FileSource: Equatable {
    /// Local file from disk
    case local(URL)

    /// Remote file from URL (video platforms)
    case remote(originalURL: URL, downloadedURL: URL?, metadata: URLVideoMetadata)

    /// The URL to use for transcription (downloaded file for remote, original for local)
    var transcriptionURL: URL? {
        switch self {
        case .local(let url):
            return url
        case .remote(_, let downloadedURL, _):
            return downloadedURL
        }
    }

    /// Display name for the file
    var displayName: String {
        switch self {
        case .local(let url):
            return url.lastPathComponent
        case .remote(_, _, let metadata):
            return metadata.title
        }
    }

    /// Platform name for remote sources
    var platform: String? {
        switch self {
        case .local:
            return nil
        case .remote(_, _, let metadata):
            return metadata.platform
        }
    }

    /// Original URL for remote sources
    var originalURL: URL? {
        switch self {
        case .local:
            return nil
        case .remote(let originalURL, _, _):
            return originalURL
        }
    }

    /// Video metadata for remote sources
    var metadata: URLVideoMetadata? {
        switch self {
        case .local:
            return nil
        case .remote(_, _, let metadata):
            return metadata
        }
    }

    static func == (lhs: FileSource, rhs: FileSource) -> Bool {
        switch (lhs, rhs) {
        case (.local(let url1), .local(let url2)):
            return url1 == url2
        case (.remote(let url1, _, _), .remote(let url2, _, _)):
            return url1 == url2
        default:
            return false
        }
    }
}

/// Represents a file in the transcription queue
struct QueuedFile: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    var source: FileSource
    var status: TranscriptionStatus
    var progress: Double
    var downloadProgress: Double?
    var result: TranscriptionResult?
    var error: String?
    var processingStartTime: Date?
    var processingEndTime: Date?

    enum TranscriptionStatus: Equatable {
        case pending
        case downloading
        case processing
        case paused
        case completed
        case failed
    }

    /// Initialize with a local file URL
    init(url: URL, status: TranscriptionStatus = .pending, progress: Double = 0.0) {
        self.url = url
        self.source = .local(url)
        self.status = status
        self.progress = progress
    }

    /// Initialize with a remote URL and metadata
    init(metadata: URLVideoMetadata, status: TranscriptionStatus = .pending) {
        self.url = metadata.originalURL
        self.source = .remote(originalURL: metadata.originalURL, downloadedURL: nil, metadata: metadata)
        self.status = status
        self.progress = 0.0
    }

    var fileName: String {
        source.displayName
    }

    /// Whether this is a remote URL source
    var isRemote: Bool {
        if case .remote = source { return true }
        return false
    }

    /// Platform for remote sources
    var platform: String? {
        source.platform
    }

    /// Video metadata for remote sources
    var videoMetadata: URLVideoMetadata? {
        source.metadata
    }

    var fileSize: String {
        guard case .local(let fileURL) = source,
              let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attributes[.size] as? Int64 else {
            // For remote files, show duration instead
            if let metadata = source.metadata {
                return metadata.formattedDuration
            }
            return "Unknown"
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var fileSizeBytes: Int64 {
        // For remote files, use downloaded file size if available
        let fileURL: URL?
        switch source {
        case .local(let url):
            fileURL = url
        case .remote(_, let downloadedURL, _):
            fileURL = downloadedURL
        }

        guard let url = fileURL,
              let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int64 else {
            return 0
        }
        return size
    }

    var processingDuration: TimeInterval? {
        guard let start = processingStartTime, let end = processingEndTime else { return nil }
        return end.timeIntervalSince(start)
    }

    static func == (lhs: QueuedFile, rhs: QueuedFile) -> Bool {
        lhs.id == rhs.id
    }
}

/// Processing mode for batch transcription
enum BatchProcessingMode: String, CaseIterable, Identifiable {
    case sequential = "Sequential"
    case parallel = "Parallel"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .sequential: return "Process one file at a time"
        case .parallel: return "Process multiple files simultaneously"
        }
    }

    var icon: String {
        switch self {
        case .sequential: return "arrow.right"
        case .parallel: return "arrow.triangle.branch"
        }
    }
}

/// ViewModel for file-based transcription
@MainActor
final class FileTranscriptionViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var queuedFiles: [QueuedFile] = []
    @Published var isProcessing: Bool = false
    @Published var isPaused: Bool = false
    @Published var currentFileIndex: Int = 0
    @Published var overallProgress: Double = 0.0
    @Published var selectedExportFormat: ExportFormat = .txt
    @Published var showExportPanel: Bool = false
    @Published var isDragging: Bool = false

    // MARK: - Batch Processing Settings
    @Published var processingMode: BatchProcessingMode = .sequential
    @Published var maxConcurrentJobs: Int = 2
    @Published var autoRetryFailed: Bool = false
    @Published var showBatchSettings: Bool = false

    // MARK: - URL Input Properties
    @Published var urlInput: String = ""
    @Published var isValidatingURL: Bool = false
    @Published var urlPreviewMetadata: URLVideoMetadata?
    @Published var urlValidationError: String?

    // MARK: - Processing Statistics
    @Published private(set) var processingStartTime: Date?
    @Published private(set) var estimatedTimeRemaining: TimeInterval?
    @Published private(set) var averageProcessingSpeed: Double = 0 // bytes per second
    private var completedFileSizes: [Int64] = []
    private var completedProcessingTimes: [TimeInterval] = []

    // MARK: - Playback Properties
    @Published var selectedFileId: UUID?
    @Published private(set) var currentSegmentIndex: Int?
    let playbackService = AudioPlaybackService()
    private var playbackObservation: Task<Void, Never>?

    // MARK: - Dependencies
    weak var appState: AppState?
    private var processingTask: Task<Void, Never>?
    private var parallelTasks: [UUID: Task<Void, Never>] = [:]
    private let historyService = TranscriptionHistoryService.shared
    private let urlDownloadService = URLDownloadService.shared
    private var pauseContinuation: CheckedContinuation<Void, Never>?
    private var downloadedFilesToCleanup: [URL] = []

    // Supported file types
    static let supportedTypes: [UTType] = [
        .mp3,
        .wav,
        .aiff,
        .mpeg4Audio,
        .mpeg4Movie,
        .quickTimeMovie,
        .audio,
        .movie
    ]

    static let supportedExtensions = ["mp3", "wav", "m4a", "aac", "flac", "ogg", "mp4", "mov", "m4v"]

    // MARK: - Initialization
    init(appState: AppState) {
        self.appState = appState
        setupPlaybackObservation()
    }

    private func setupPlaybackObservation() {
        // Observe playback time changes to update current segment
        playbackObservation = Task { [weak self] in
            guard let self = self else { return }

            // Observe currentTime changes
            for await _ in self.playbackService.$currentTime.values {
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    self.updateCurrentSegment()
                }
            }
        }
    }

    private func updateCurrentSegment() {
        guard let selectedFile = selectedFile,
              let result = selectedFile.result else {
            currentSegmentIndex = nil
            return
        }

        let currentTime = playbackService.currentTime

        // Find segment containing current playback time
        for (index, segment) in result.segments.enumerated() {
            if currentTime >= segment.startTime && currentTime < segment.endTime {
                if currentSegmentIndex != index {
                    currentSegmentIndex = index
                }
                return
            }
        }

        // If past all segments, select last one
        if currentTime >= (result.segments.last?.endTime ?? 0) {
            currentSegmentIndex = result.segments.count - 1
        } else {
            currentSegmentIndex = nil
        }
    }

    // MARK: - Queue Management

    /// Add files to the queue
    func addFiles(_ urls: [URL]) {
        let newFiles = urls
            .filter { isSupported($0) }
            .filter { url in !queuedFiles.contains { $0.url == url } }
            .map { QueuedFile(url: $0, status: .pending, progress: 0.0) }

        queuedFiles.append(contentsOf: newFiles)
    }

    // MARK: - URL Methods

    /// Validate a URL and fetch metadata
    func validateURL() {
        let urlString = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        NSLog("[FileTranscriptionVM] validateURL called with: %@", urlString)
        guard !urlString.isEmpty else {
            NSLog("[FileTranscriptionVM] URL is empty, returning")
            return
        }

        isValidatingURL = true
        urlValidationError = nil
        urlPreviewMetadata = nil
        NSLog("[FileTranscriptionVM] Starting validation task...")

        Task {
            do {
                NSLog("[FileTranscriptionVM] Calling urlDownloadService.validateURL...")
                let metadata = try await urlDownloadService.validateURL(urlString)
                NSLog("[FileTranscriptionVM] Got metadata: %@", metadata.title)
                await MainActor.run {
                    urlPreviewMetadata = metadata
                    isValidatingURL = false
                }
            } catch let error as URLDownloadError {
                NSLog("[FileTranscriptionVM] URLDownloadError: %@", error.localizedDescription)
                await MainActor.run {
                    urlValidationError = error.localizedDescription
                    isValidatingURL = false
                }
            } catch {
                NSLog("[FileTranscriptionVM] Error: %@", error.localizedDescription)
                await MainActor.run {
                    urlValidationError = error.localizedDescription
                    isValidatingURL = false
                }
            }
        }
    }

    /// Add a URL from the preview metadata to the queue
    func addURLFromPreview() {
        guard let metadata = urlPreviewMetadata else { return }

        // Check if already in queue
        let alreadyQueued = queuedFiles.contains { file in
            if case .remote(let existingURL, _, _) = file.source {
                return existingURL == metadata.originalURL
            }
            return false
        }

        guard !alreadyQueued else {
            urlValidationError = "This video is already in the queue"
            return
        }

        let newFile = QueuedFile(metadata: metadata)
        queuedFiles.append(newFile)

        // Clear URL input
        urlInput = ""
        urlPreviewMetadata = nil
        urlValidationError = nil
    }

    /// Check if yt-dlp is available
    var isYtdlpAvailable: Bool {
        urlDownloadService.isYtdlpAvailable
    }

    /// Remove a file from the queue
    func removeFile(_ file: QueuedFile) {
        // Cancel if processing or downloading
        if file.status == .processing || file.status == .downloading {
            parallelTasks[file.id]?.cancel()
            parallelTasks.removeValue(forKey: file.id)
            urlDownloadService.cancelDownload()
        }

        // Clean up downloaded file for remote sources
        if case .remote(_, let downloadedURL, _) = file.source, let url = downloadedURL {
            urlDownloadService.cleanupDownload(at: url)
        }

        queuedFiles.removeAll { $0.id == file.id }
        updateOverallProgress()
    }

    /// Remove all completed files
    func removeCompleted() {
        queuedFiles.removeAll { $0.status == .completed }
        updateOverallProgress()
    }

    /// Remove all failed files
    func removeFailed() {
        queuedFiles.removeAll { $0.status == .failed }
        updateOverallProgress()
    }

    /// Clear all files from the queue
    func clearQueue() {
        cancelProcessing()

        // Clean up all downloaded files
        for file in queuedFiles {
            if case .remote(_, let downloadedURL, _) = file.source, let url = downloadedURL {
                urlDownloadService.cleanupDownload(at: url)
            }
        }

        queuedFiles.removeAll()
        currentFileIndex = 0
        overallProgress = 0.0
        resetStatistics()

        // Also clear URL input
        urlInput = ""
        urlPreviewMetadata = nil
        urlValidationError = nil
    }

    /// Clean up all temporary downloads (call on app termination)
    func cleanupAllDownloads() {
        urlDownloadService.cleanupAllDownloads()
    }

    /// Move file up in queue
    func moveUp(_ file: QueuedFile) {
        guard let index = queuedFiles.firstIndex(where: { $0.id == file.id }),
              index > 0,
              queuedFiles[index].status == .pending else { return }

        queuedFiles.swapAt(index, index - 1)
    }

    /// Move file down in queue
    func moveDown(_ file: QueuedFile) {
        guard let index = queuedFiles.firstIndex(where: { $0.id == file.id }),
              index < queuedFiles.count - 1,
              queuedFiles[index].status == .pending else { return }

        queuedFiles.swapAt(index, index + 1)
    }

    /// Move file to top of queue
    func moveToTop(_ file: QueuedFile) {
        guard let index = queuedFiles.firstIndex(where: { $0.id == file.id }),
              index > 0,
              queuedFiles[index].status == .pending else { return }

        let file = queuedFiles.remove(at: index)
        // Find first pending position
        let insertIndex = queuedFiles.firstIndex(where: { $0.status == .pending }) ?? 0
        queuedFiles.insert(file, at: insertIndex)
    }

    /// Move file to bottom of queue
    func moveToBottom(_ file: QueuedFile) {
        guard let index = queuedFiles.firstIndex(where: { $0.id == file.id }),
              queuedFiles[index].status == .pending else { return }

        let file = queuedFiles.remove(at: index)
        queuedFiles.append(file)
    }

    /// Retry a failed file
    func retryFile(_ file: QueuedFile) {
        guard let index = queuedFiles.firstIndex(where: { $0.id == file.id }),
              queuedFiles[index].status == .failed else { return }

        queuedFiles[index].status = .pending
        queuedFiles[index].progress = 0.0
        queuedFiles[index].error = nil
        queuedFiles[index].processingStartTime = nil
        queuedFiles[index].processingEndTime = nil

        // Auto-start if not processing
        if !isProcessing {
            startProcessing()
        }
    }

    /// Retry all failed files
    func retryAllFailed() {
        for index in queuedFiles.indices {
            if queuedFiles[index].status == .failed {
                queuedFiles[index].status = .pending
                queuedFiles[index].progress = 0.0
                queuedFiles[index].error = nil
                queuedFiles[index].processingStartTime = nil
                queuedFiles[index].processingEndTime = nil
            }
        }

        if !isProcessing && pendingCount > 0 {
            startProcessing()
        }
    }

    /// Check if a file type is supported
    func isSupported(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return Self.supportedExtensions.contains(ext)
    }

    private func resetStatistics() {
        processingStartTime = nil
        estimatedTimeRemaining = nil
        averageProcessingSpeed = 0
        completedFileSizes = []
        completedProcessingTimes = []
    }

    // MARK: - Transcription

    /// Start processing the queue
    func startProcessing() {
        guard !isProcessing, !queuedFiles.isEmpty else { return }

        // Resume if paused
        if isPaused {
            resumeProcessing()
            return
        }

        isProcessing = true
        isPaused = false
        processingStartTime = Date()

        switch processingMode {
        case .sequential:
            startSequentialProcessing()
        case .parallel:
            startParallelProcessing()
        }
    }

    private func startSequentialProcessing() {
        processingTask = Task {
            for index in queuedFiles.indices {
                guard !Task.isCancelled else { break }

                // Check for pause
                if isPaused {
                    await withCheckedContinuation { continuation in
                        pauseContinuation = continuation
                    }
                }

                guard queuedFiles[index].status == .pending else { continue }

                currentFileIndex = index
                await processFile(at: index)
                updateOverallProgress()
                updateEstimatedTime()
            }

            isProcessing = false
            isPaused = false
        }
    }

    private func startParallelProcessing() {
        processingTask = Task {
            // Process in batches based on maxConcurrentJobs
            let pendingIndices = queuedFiles.indices.filter { queuedFiles[$0].status == .pending }

            await withTaskGroup(of: Void.self) { group in
                var activeCount = 0
                var indexIterator = pendingIndices.makeIterator()

                // Start initial batch
                while activeCount < maxConcurrentJobs, let index = indexIterator.next() {
                    guard !Task.isCancelled else { break }

                    activeCount += 1
                    group.addTask {
                        await self.processFile(at: index)
                        await MainActor.run {
                            self.updateOverallProgress()
                            self.updateEstimatedTime()
                        }
                    }
                }

                // As tasks complete, start new ones
                for await _ in group {
                    activeCount -= 1

                    // Check for pause/cancel
                    if Task.isCancelled || isPaused { break }

                    // Start next file if available
                    if let index = indexIterator.next() {
                        activeCount += 1
                        group.addTask {
                            await self.processFile(at: index)
                            await MainActor.run {
                                self.updateOverallProgress()
                                self.updateEstimatedTime()
                            }
                        }
                    }
                }
            }

            isProcessing = false
            isPaused = false
        }
    }

    /// Pause processing
    func pauseProcessing() {
        guard isProcessing, !isPaused else { return }
        isPaused = true

        // Mark currently processing files as paused
        for index in queuedFiles.indices {
            if queuedFiles[index].status == .processing {
                queuedFiles[index].status = .paused
            }
        }
    }

    /// Resume processing
    func resumeProcessing() {
        guard isPaused else { return }
        isPaused = false

        // Resume paused files to pending
        for index in queuedFiles.indices {
            if queuedFiles[index].status == .paused {
                queuedFiles[index].status = .pending
            }
        }

        // Resume the continuation if waiting
        pauseContinuation?.resume()
        pauseContinuation = nil

        // If task was cancelled, restart
        if processingTask == nil || processingTask?.isCancelled == true {
            isProcessing = false
            startProcessing()
        }
    }

    /// Cancel processing
    func cancelProcessing() {
        processingTask?.cancel()
        processingTask = nil

        // Cancel all parallel tasks
        for (_, task) in parallelTasks {
            task.cancel()
        }
        parallelTasks.removeAll()

        // Cancel any active download
        urlDownloadService.cancelDownload()

        isProcessing = false
        isPaused = false

        // Resume any waiting continuation
        pauseContinuation?.resume()
        pauseContinuation = nil

        // Reset processing/downloading files
        for index in queuedFiles.indices {
            if queuedFiles[index].status == .processing ||
               queuedFiles[index].status == .paused ||
               queuedFiles[index].status == .downloading {
                queuedFiles[index].status = .pending
                queuedFiles[index].progress = 0.0
                queuedFiles[index].downloadProgress = nil
                queuedFiles[index].processingStartTime = nil
            }
        }
    }

    /// Process a single file
    private func processFile(at index: Int) async {
        guard index < queuedFiles.count else { return }

        let file = queuedFiles[index]
        var audioFileURL: URL
        var downloadedFileURL: URL?

        // Handle remote sources - download first
        if case .remote(_, _, let metadata) = file.source {
            // Update status to downloading
            await MainActor.run {
                queuedFiles[index].status = .downloading
                queuedFiles[index].downloadProgress = 0.0
                queuedFiles[index].processingStartTime = Date()
            }

            do {
                // Download audio from URL
                let downloadedURL = try await urlDownloadService.downloadAudio(from: metadata) { progress in
                    Task { @MainActor in
                        if index < self.queuedFiles.count {
                            self.queuedFiles[index].downloadProgress = progress
                        }
                    }
                }

                // Update source with downloaded URL
                await MainActor.run {
                    if index < queuedFiles.count {
                        queuedFiles[index].source = .remote(
                            originalURL: metadata.originalURL,
                            downloadedURL: downloadedURL,
                            metadata: metadata
                        )
                    }
                }

                audioFileURL = downloadedURL
                downloadedFileURL = downloadedURL
            } catch {
                await MainActor.run {
                    if index < queuedFiles.count {
                        queuedFiles[index].status = .failed
                        queuedFiles[index].error = error.localizedDescription
                        queuedFiles[index].processingEndTime = Date()
                    }
                }
                return
            }
        } else {
            audioFileURL = file.url
        }

        // Now proceed with transcription
        await MainActor.run {
            if index < queuedFiles.count {
                queuedFiles[index].status = .processing
                queuedFiles[index].progress = 0.0
                if queuedFiles[index].processingStartTime == nil {
                    queuedFiles[index].processingStartTime = Date()
                }
            }
        }

        let fileSize = queuedFiles[index].fileSizeBytes

        do {
            guard let appState = appState else {
                throw NSError(domain: "FileTranscription", code: -1, userInfo: [NSLocalizedDescriptionKey: "App state not available"])
            }

            // Get language setting
            let language = appState.settings.selectedLanguage
            let transcriptionLanguage = language == "auto" ? nil : language
            let shouldRemoveFillers = appState.settings.removeFillerWords
            let enableDiarization = appState.settings.enableSpeakerDiarization
            let selectedEngine = appState.settings.transcriptionEngine

            // Transcribe using the selected engine
            let result: TranscriptionResult

            switch selectedEngine {
            case .parakeet:
                // Use Parakeet engine
                guard appState.parakeetService.isModelLoaded else {
                    throw ParakeetServiceError.modelNotLoaded
                }
                result = try await appState.parakeetService.transcribe(audioURL: audioFileURL, removeFillers: shouldRemoveFillers)

            case .whisper:
                // Use Whisper engine
                let whisperService = appState.whisperService
                guard whisperService.isModelLoaded else {
                    throw WhisperServiceError.modelNotLoaded
                }

                if enableDiarization {
                    result = try await whisperService.transcribeWithDiarization(
                        audioURL: audioFileURL,
                        language: transcriptionLanguage,
                        diarizationService: appState.diarizationService ?? SpeakerDiarizationService(),
                        removeFillers: shouldRemoveFillers
                    )
                } else {
                    result = try await whisperService.transcribe(audioURL: audioFileURL, language: transcriptionLanguage, removeFillers: shouldRemoveFillers)
                }
            }

            await MainActor.run {
                guard index < queuedFiles.count else { return }

                queuedFiles[index].status = .completed
                queuedFiles[index].progress = 1.0
                queuedFiles[index].result = result
                queuedFiles[index].processingEndTime = Date()

                // Update statistics
                if let duration = queuedFiles[index].processingDuration {
                    completedFileSizes.append(fileSize)
                    completedProcessingTimes.append(duration)
                    calculateAverageSpeed()
                }

                // Save to persistent history with appropriate source
                let currentFile = queuedFiles[index]
                if case .remote(let originalURL, _, let metadata) = currentFile.source {
                    historyService.save(result, source: .url(
                        urlString: originalURL.absoluteString,
                        platform: metadata.platform,
                        videoTitle: metadata.title
                    ))
                } else {
                    let fileName = audioFileURL.lastPathComponent
                    historyService.save(result, source: .file(fileName: fileName, filePath: audioFileURL.path))
                }

                // Clean up downloaded file after successful transcription
                if let downloadedURL = downloadedFileURL {
                    urlDownloadService.cleanupDownload(at: downloadedURL)
                }
            }
        } catch {
            await MainActor.run {
                guard index < queuedFiles.count else { return }

                queuedFiles[index].status = .failed
                queuedFiles[index].error = error.localizedDescription
                queuedFiles[index].processingEndTime = Date()

                // Clean up downloaded file on failure
                if let downloadedURL = downloadedFileURL {
                    urlDownloadService.cleanupDownload(at: downloadedURL)
                }

                // Auto-retry if enabled (max 1 retry)
                if autoRetryFailed && queuedFiles[index].error?.contains("retry") != true {
                    queuedFiles[index].status = .pending
                    queuedFiles[index].error = "Will retry: \(error.localizedDescription)"
                }
            }
        }
    }

    private func updateOverallProgress() {
        let completed = queuedFiles.filter { $0.status == .completed || $0.status == .failed }.count
        overallProgress = queuedFiles.isEmpty ? 0 : Double(completed) / Double(queuedFiles.count)
    }

    private func calculateAverageSpeed() {
        guard !completedFileSizes.isEmpty, !completedProcessingTimes.isEmpty else { return }

        let totalBytes = completedFileSizes.reduce(0, +)
        let totalTime = completedProcessingTimes.reduce(0, +)

        if totalTime > 0 {
            averageProcessingSpeed = Double(totalBytes) / totalTime
        }
    }

    private func updateEstimatedTime() {
        guard averageProcessingSpeed > 0 else {
            estimatedTimeRemaining = nil
            return
        }

        let remainingFiles = queuedFiles.filter { $0.status == .pending }
        let remainingBytes = remainingFiles.reduce(0) { $0 + $1.fileSizeBytes }

        if remainingBytes > 0 {
            estimatedTimeRemaining = Double(remainingBytes) / averageProcessingSpeed
        } else {
            estimatedTimeRemaining = nil
        }
    }

    // MARK: - Export

    /// Export all completed transcriptions
    func exportAll() async {
        let completedResults = queuedFiles
            .compactMap { $0.result }

        guard !completedResults.isEmpty else { return }

        _ = await ExportService.exportBatch(completedResults, format: selectedExportFormat)
    }

    /// Export a single transcription
    func export(_ file: QueuedFile) async {
        guard let result = file.result else { return }
        _ = await ExportService.exportToFile(result, format: selectedExportFormat)
    }

    /// Copy clean text for a file
    func copyCleanText(_ file: QueuedFile) {
        guard let result = file.result else { return }
        ExportService.copyCleanText(result)
    }

    /// Copy with timestamps for a file
    func copyWithTimestamps(_ file: QueuedFile) {
        guard let result = file.result else { return }
        ExportService.copyWithTimestamps(result)
    }

    // MARK: - File Dropping

    /// Handle file drop
    func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url = url {
                        DispatchQueue.main.async {
                            self.addFiles([url])
                        }
                    }
                }
            }
        }

        return true
    }
}

// MARK: - Computed Properties
extension FileTranscriptionViewModel {
    var pendingCount: Int {
        queuedFiles.filter { $0.status == .pending || $0.status == .paused }.count
    }

    var processingCount: Int {
        queuedFiles.filter { $0.status == .processing || $0.status == .downloading }.count
    }

    var downloadingCount: Int {
        queuedFiles.filter { $0.status == .downloading }.count
    }

    var completedCount: Int {
        queuedFiles.filter { $0.status == .completed }.count
    }

    var failedCount: Int {
        queuedFiles.filter { $0.status == .failed }.count
    }

    var hasCompletedFiles: Bool {
        completedCount > 0
    }

    var hasFailedFiles: Bool {
        failedCount > 0
    }

    var canExport: Bool {
        hasCompletedFiles && !isProcessing
    }

    var canStart: Bool {
        pendingCount > 0 && !isProcessing
    }

    var canPause: Bool {
        isProcessing && !isPaused
    }

    var canResume: Bool {
        isPaused
    }

    /// Currently selected file for playback/viewing
    var selectedFile: QueuedFile? {
        guard let id = selectedFileId else { return nil }
        return queuedFiles.first { $0.id == id }
    }

    /// Whether a file is selected and has completed transcription
    var hasSelectedTranscription: Bool {
        selectedFile?.result != nil
    }

    /// Total size of all queued files
    var totalQueueSize: String {
        let totalBytes = queuedFiles.reduce(0) { $0 + $1.fileSizeBytes }
        return ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }

    /// Formatted estimated time remaining
    var formattedEstimatedTime: String? {
        guard let time = estimatedTimeRemaining, time > 0 else { return nil }

        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2

        return formatter.string(from: time)
    }

    /// Formatted elapsed time
    var formattedElapsedTime: String? {
        guard let start = processingStartTime else { return nil }

        let elapsed = Date().timeIntervalSince(start)
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2

        return formatter.string(from: elapsed)
    }

    /// Processing status text
    var statusText: String {
        if isPaused {
            return "Paused"
        } else if isProcessing {
            if downloadingCount > 0 {
                return "Downloading \(downloadingCount) file\(downloadingCount == 1 ? "" : "s")..."
            }
            let activeCount = processingMode == .parallel ? processingCount : 1
            return "Processing \(activeCount) file\(activeCount == 1 ? "" : "s")..."
        } else if completedCount == queuedFiles.count && !queuedFiles.isEmpty {
            return "All done!"
        } else if failedCount > 0 {
            return "\(failedCount) failed"
        } else {
            return "Ready"
        }
    }
}

// MARK: - Playback Control
extension FileTranscriptionViewModel {

    /// Select a file for viewing/playback
    func selectFile(_ file: QueuedFile) {
        // Stop current playback if switching files
        if selectedFileId != file.id {
            playbackService.stop()
            currentSegmentIndex = nil
        }

        selectedFileId = file.id

        // Load audio if file has completed transcription
        if file.status == .completed {
            Task {
                try? await playbackService.load(url: file.url)
            }
        }
    }

    /// Deselect current file and stop playback
    func deselectFile() {
        playbackService.stop()
        selectedFileId = nil
        currentSegmentIndex = nil
    }

    /// Seek to a specific segment
    func seekToSegment(_ segment: TranscriptionSegment) {
        playbackService.seek(to: segment.startTime)
        // Start playing if not already
        if !playbackService.isPlaying {
            playbackService.play()
        }
    }

    /// Seek to segment at index
    func seekToSegment(at index: Int) {
        guard let result = selectedFile?.result,
              index >= 0 && index < result.segments.count else { return }

        let segment = result.segments[index]
        seekToSegment(segment)
    }

    /// Get segment at the given index
    func segment(at index: Int) -> TranscriptionSegment? {
        guard let result = selectedFile?.result,
              index >= 0 && index < result.segments.count else { return nil }
        return result.segments[index]
    }

    /// Check if segment at index is currently playing
    func isSegmentPlaying(at index: Int) -> Bool {
        return currentSegmentIndex == index && playbackService.isPlaying
    }
}
