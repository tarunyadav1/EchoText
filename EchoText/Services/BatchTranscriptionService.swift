import Foundation
import SwiftUI
import Combine
import UniformTypeIdentifiers

/// Represents a file in the batch transcription queue
struct BatchQueuedFile: Identifiable, Equatable {
    let id: UUID
    let url: URL
    var status: BatchFileStatus
    var progress: Double
    var result: TranscriptionResult?
    var error: String?
    var processingStartTime: Date?
    var processingEndTime: Date?
    var retryCount: Int

    /// File status in the batch queue
    enum BatchFileStatus: Equatable {
        case pending
        case processing
        case completed
        case failed
        case cancelled
    }

    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.status = .pending
        self.progress = 0.0
        self.retryCount = 0
    }

    var fileName: String {
        url.lastPathComponent
    }

    var fileExtension: String {
        url.pathExtension.uppercased()
    }

    var fileSize: String {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int64 else {
            return "Unknown"
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var fileSizeBytes: Int64 {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int64 else {
            return 0
        }
        return size
    }

    var processingDuration: TimeInterval? {
        guard let start = processingStartTime, let end = processingEndTime else { return nil }
        return end.timeIntervalSince(start)
    }

    static func == (lhs: BatchQueuedFile, rhs: BatchQueuedFile) -> Bool {
        lhs.id == rhs.id
    }
}

/// Batch transcription state
enum BatchTranscriptionState {
    case idle
    case processing
    case paused
    case completed
}

/// Error types for batch transcription
enum BatchTranscriptionError: LocalizedError {
    case queueEmpty
    case alreadyProcessing
    case whisperNotAvailable
    case modelNotLoaded
    case fileAccessDenied(String)
    case transcriptionFailed(String, Error)

    var errorDescription: String? {
        switch self {
        case .queueEmpty:
            return "No files in the queue to process"
        case .alreadyProcessing:
            return "Batch processing is already in progress"
        case .whisperNotAvailable:
            return "Whisper service is not available"
        case .modelNotLoaded:
            return "Please load a Whisper model first"
        case .fileAccessDenied(let path):
            return "Cannot access file: \(path)"
        case .transcriptionFailed(let file, let error):
            return "Failed to transcribe \(file): \(error.localizedDescription)"
        }
    }
}

/// Service responsible for managing batch transcription of multiple audio/video files
@MainActor
final class BatchTranscriptionService: ObservableObject {
    // MARK: - Published Properties

    /// Queue of files to be transcribed
    @Published private(set) var queue: [BatchQueuedFile] = []

    /// Current batch processing state
    @Published private(set) var state: BatchTranscriptionState = .idle

    /// Overall progress (0.0 to 1.0)
    @Published private(set) var overallProgress: Double = 0.0

    /// Index of the currently processing file
    @Published private(set) var currentIndex: Int = 0

    /// Time when processing started
    @Published private(set) var processingStartTime: Date?

    /// Estimated time remaining
    @Published private(set) var estimatedTimeRemaining: TimeInterval?

    /// Average processing speed (bytes per second)
    @Published private(set) var averageProcessingSpeed: Double = 0

    // MARK: - Configuration

    /// Whether to automatically save results as each file completes
    var autoSaveResults: Bool = true

    /// Directory for auto-saved results (nil uses same directory as source file)
    var autoSaveDirectory: URL?

    /// Export format for auto-saved results
    var autoSaveFormat: ExportFormat = .txt

    /// Maximum retry attempts for failed files
    var maxRetryAttempts: Int = 1

    // MARK: - Private Properties

    private weak var whisperService: WhisperService?
    private weak var appState: AppState?
    private var processingTask: Task<Void, Never>?
    private var pauseContinuation: CheckedContinuation<Void, Never>?
    private var completedFileSizes: [Int64] = []
    private var completedProcessingTimes: [TimeInterval] = []
    private let historyService = TranscriptionHistoryService.shared

    /// Supported file extensions
    static let supportedExtensions = ["mp3", "wav", "m4a", "aac", "flac", "ogg", "mp4", "mov", "m4v"]

    /// Supported UTTypes for file picking
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

    // MARK: - Initialization

    init(whisperService: WhisperService? = nil, appState: AppState? = nil) {
        self.whisperService = whisperService
        self.appState = appState
    }

    func configure(whisperService: WhisperService, appState: AppState) {
        self.whisperService = whisperService
        self.appState = appState
    }

    // MARK: - Queue Management

    /// Add a file to the queue
    func addFile(_ url: URL) {
        guard isSupported(url) else { return }
        guard !queue.contains(where: { $0.url == url }) else { return }

        let file = BatchQueuedFile(url: url)
        queue.append(file)
    }

    /// Add multiple files to the queue
    func addFiles(_ urls: [URL]) {
        for url in urls {
            addFile(url)
        }
    }

    /// Remove a file from the queue by ID
    func removeFile(id: UUID) {
        guard state != .processing || queue.first(where: { $0.id == id })?.status != .processing else {
            return // Cannot remove currently processing file
        }
        queue.removeAll { $0.id == id }
        updateOverallProgress()
    }

    /// Remove a file from the queue
    func removeFile(_ file: BatchQueuedFile) {
        removeFile(id: file.id)
    }

    /// Remove all completed files from the queue
    func removeCompleted() {
        queue.removeAll { $0.status == .completed }
        updateOverallProgress()
    }

    /// Remove all failed files from the queue
    func removeFailed() {
        queue.removeAll { $0.status == .failed }
        updateOverallProgress()
    }

    /// Clear the entire queue (stops processing if active)
    func clearQueue() {
        cancel()
        queue.removeAll()
        resetStatistics()
    }

    /// Move a file up in the queue
    func moveUp(_ file: BatchQueuedFile) {
        guard let index = queue.firstIndex(where: { $0.id == file.id }),
              index > 0,
              queue[index].status == .pending else { return }
        queue.swapAt(index, index - 1)
    }

    /// Move a file down in the queue
    func moveDown(_ file: BatchQueuedFile) {
        guard let index = queue.firstIndex(where: { $0.id == file.id }),
              index < queue.count - 1,
              queue[index].status == .pending else { return }
        queue.swapAt(index, index + 1)
    }

    /// Move a file to the top of the queue (after any currently processing)
    func moveToTop(_ file: BatchQueuedFile) {
        guard let index = queue.firstIndex(where: { $0.id == file.id }),
              index > 0,
              queue[index].status == .pending else { return }

        let file = queue.remove(at: index)
        let insertIndex = queue.firstIndex(where: { $0.status == .pending }) ?? 0
        queue.insert(file, at: insertIndex)
    }

    /// Move a file to the bottom of the queue
    func moveToBottom(_ file: BatchQueuedFile) {
        guard let index = queue.firstIndex(where: { $0.id == file.id }),
              queue[index].status == .pending else { return }

        let file = queue.remove(at: index)
        queue.append(file)
    }

    /// Reorder files by moving from one index to another
    func reorderFiles(from source: IndexSet, to destination: Int) {
        // Only allow reordering pending files
        let pendingIndices = Set(queue.indices.filter { queue[$0].status == .pending })
        guard source.allSatisfy({ pendingIndices.contains($0) }) else { return }

        queue.move(fromOffsets: source, toOffset: destination)
    }

    /// Retry a failed file
    func retryFile(_ file: BatchQueuedFile) {
        guard let index = queue.firstIndex(where: { $0.id == file.id }),
              queue[index].status == .failed else { return }

        queue[index].status = .pending
        queue[index].progress = 0.0
        queue[index].error = nil
        queue[index].processingStartTime = nil
        queue[index].processingEndTime = nil
        queue[index].retryCount += 1

        // Auto-start if not processing
        if state == .idle {
            start()
        }
    }

    /// Retry all failed files
    func retryAllFailed() {
        for index in queue.indices {
            if queue[index].status == .failed {
                queue[index].status = .pending
                queue[index].progress = 0.0
                queue[index].error = nil
                queue[index].processingStartTime = nil
                queue[index].processingEndTime = nil
                queue[index].retryCount += 1
            }
        }

        if state == .idle && pendingCount > 0 {
            start()
        }
    }

    /// Check if a file type is supported
    func isSupported(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return Self.supportedExtensions.contains(ext)
    }

    // MARK: - Processing Control

    /// Start processing the queue
    func start() {
        guard state == .idle || state == .paused else { return }
        guard !queue.isEmpty else { return }
        guard pendingCount > 0 else { return }

        // Resume if paused
        if state == .paused {
            resume()
            return
        }

        state = .processing
        processingStartTime = Date()
        startSequentialProcessing()
    }

    /// Pause processing (completes current file)
    func pause() {
        guard state == .processing else { return }
        state = .paused
    }

    /// Resume processing after pause
    func resume() {
        guard state == .paused else { return }
        state = .processing

        // Resume the continuation if waiting
        pauseContinuation?.resume()
        pauseContinuation = nil

        // If task was cancelled, restart
        if processingTask == nil || processingTask?.isCancelled == true {
            startSequentialProcessing()
        }
    }

    /// Cancel all processing
    func cancel() {
        processingTask?.cancel()
        processingTask = nil

        state = .idle

        // Resume any waiting continuation
        pauseContinuation?.resume()
        pauseContinuation = nil

        // Reset processing files to pending
        for index in queue.indices {
            if queue[index].status == .processing {
                queue[index].status = .cancelled
                queue[index].progress = 0.0
                queue[index].processingStartTime = nil
            }
        }
    }

    // MARK: - Export

    /// Get all completed results
    var completedResults: [TranscriptionResult] {
        queue.compactMap { $0.result }
    }

    /// Export all completed results to a directory
    func exportAllResults(format: ExportFormat) async -> URL? {
        let results = completedResults
        guard !results.isEmpty else { return nil }
        return await ExportService.exportBatch(results, format: format)
    }

    /// Export a single file's result
    func exportResult(for file: BatchQueuedFile, format: ExportFormat) async -> URL? {
        guard let result = file.result else { return nil }
        return await ExportService.exportToFile(result, format: format)
    }

    // MARK: - Private Methods

    private func startSequentialProcessing() {
        processingTask = Task {
            for index in queue.indices {
                guard !Task.isCancelled else { break }

                // Check for pause
                if state == .paused {
                    await withCheckedContinuation { continuation in
                        pauseContinuation = continuation
                    }
                }

                // Skip non-pending files
                guard queue[index].status == .pending else { continue }

                currentIndex = index
                await processFile(at: index)
                updateOverallProgress()
                updateEstimatedTime()
            }

            // Processing complete
            if !Task.isCancelled {
                state = .completed
            } else {
                state = .idle
            }
        }
    }

    private func processFile(at index: Int) async {
        guard index < queue.count else { return }

        queue[index].status = .processing
        queue[index].progress = 0.0
        queue[index].processingStartTime = Date()

        let fileSize = queue[index].fileSizeBytes
        let fileURL = queue[index].url

        do {
            guard let appState = appState else {
                throw BatchTranscriptionError.whisperNotAvailable
            }

            // Get settings
            let language = appState.settings.selectedLanguage
            let transcriptionLanguage = language == "auto" ? nil : language
            let shouldRemoveFillers = appState.settings.removeFillerWords
            let selectedEngine = appState.settings.transcriptionEngine

            // Check model is loaded for selected engine
            switch selectedEngine {
            case .parakeet:
                guard appState.parakeetService.isModelLoaded else {
                    throw BatchTranscriptionError.modelNotLoaded
                }
            case .whisper:
                guard let whisperService = whisperService, whisperService.isModelLoaded else {
                    throw BatchTranscriptionError.modelNotLoaded
                }
            }

            // Simulate progress updates (WhisperKit doesn't provide granular progress)
            let progressTask = Task {
                var progress = 0.0
                while !Task.isCancelled && progress < 0.9 {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    progress += 0.05
                    if index < queue.count && queue[index].status == .processing {
                        queue[index].progress = min(progress, 0.9)
                    }
                }
            }

            // Perform transcription using the selected engine
            let result: TranscriptionResult
            switch selectedEngine {
            case .parakeet:
                result = try await appState.parakeetService.transcribe(audioURL: fileURL, removeFillers: shouldRemoveFillers)
            case .whisper:
                result = try await whisperService!.transcribe(
                    audioURL: fileURL,
                    language: transcriptionLanguage,
                    removeFillers: shouldRemoveFillers
                )
            }

            progressTask.cancel()

            // Update queue entry
            queue[index].status = .completed
            queue[index].progress = 1.0
            queue[index].result = result
            queue[index].processingEndTime = Date()

            // Update statistics
            if let duration = queue[index].processingDuration {
                completedFileSizes.append(fileSize)
                completedProcessingTimes.append(duration)
                calculateAverageSpeed()
            }

            // Save to history
            let fileName = fileURL.lastPathComponent
            historyService.save(result, source: .file(fileName: fileName, filePath: fileURL.path))

            // Auto-save if enabled
            if autoSaveResults {
                await autoSaveResult(for: queue[index])
            }

        } catch {
            queue[index].status = .failed
            queue[index].error = error.localizedDescription
            queue[index].processingEndTime = Date()

            // Auto-retry if attempts remaining
            if queue[index].retryCount < maxRetryAttempts {
                queue[index].status = .pending
                queue[index].error = "Will retry: \(error.localizedDescription)"
                queue[index].retryCount += 1
            }
        }
    }

    private func autoSaveResult(for file: BatchQueuedFile) async {
        guard let result = file.result else { return }

        let saveDirectory = autoSaveDirectory ?? file.url.deletingLastPathComponent()
        let baseName = file.url.deletingPathExtension().lastPathComponent
        let fileName = "\(baseName)_transcript.\(autoSaveFormat.fileExtension)"
        let saveURL = saveDirectory.appendingPathComponent(fileName)

        if let data = ExportService.export(result, format: autoSaveFormat) {
            try? data.write(to: saveURL)
        }
    }

    private func updateOverallProgress() {
        let completed = queue.filter { $0.status == .completed || $0.status == .failed }.count
        overallProgress = queue.isEmpty ? 0 : Double(completed) / Double(queue.count)
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

        let remainingFiles = queue.filter { $0.status == .pending }
        let remainingBytes = remainingFiles.reduce(0) { $0 + $1.fileSizeBytes }

        if remainingBytes > 0 {
            estimatedTimeRemaining = Double(remainingBytes) / averageProcessingSpeed
        } else {
            estimatedTimeRemaining = nil
        }
    }

    private func resetStatistics() {
        overallProgress = 0.0
        currentIndex = 0
        processingStartTime = nil
        estimatedTimeRemaining = nil
        averageProcessingSpeed = 0
        completedFileSizes = []
        completedProcessingTimes = []
    }
}

// MARK: - Computed Properties

extension BatchTranscriptionService {
    /// Number of pending files
    var pendingCount: Int {
        queue.filter { $0.status == .pending }.count
    }

    /// Number of completed files
    var completedCount: Int {
        queue.filter { $0.status == .completed }.count
    }

    /// Number of failed files
    var failedCount: Int {
        queue.filter { $0.status == .failed }.count
    }

    /// Number of files currently processing
    var processingCount: Int {
        queue.filter { $0.status == .processing }.count
    }

    /// Total number of files in queue
    var totalCount: Int {
        queue.count
    }

    /// Whether there are completed files
    var hasCompletedFiles: Bool {
        completedCount > 0
    }

    /// Whether there are failed files
    var hasFailedFiles: Bool {
        failedCount > 0
    }

    /// Whether export is possible
    var canExport: Bool {
        hasCompletedFiles && state != .processing
    }

    /// Whether processing can start
    var canStart: Bool {
        pendingCount > 0 && state == .idle
    }

    /// Whether processing can be paused
    var canPause: Bool {
        state == .processing
    }

    /// Whether processing can be resumed
    var canResume: Bool {
        state == .paused
    }

    /// Whether the queue is empty
    var isEmpty: Bool {
        queue.isEmpty
    }

    /// Total size of all queued files
    var totalQueueSize: String {
        let totalBytes = queue.reduce(0) { $0 + $1.fileSizeBytes }
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

    /// Current status text
    var statusText: String {
        switch state {
        case .idle:
            if queue.isEmpty {
                return "Ready to start"
            } else if failedCount > 0 && pendingCount == 0 {
                return "\(failedCount) failed"
            } else {
                return "\(pendingCount) file\(pendingCount == 1 ? "" : "s") ready"
            }
        case .processing:
            let current = currentIndex + 1
            return "Processing \(current) of \(totalCount)..."
        case .paused:
            return "Paused"
        case .completed:
            if failedCount > 0 {
                return "Completed with \(failedCount) failure\(failedCount == 1 ? "" : "s")"
            }
            return "All \(completedCount) file\(completedCount == 1 ? "" : "s") completed"
        }
    }

    /// Currently processing file (if any)
    var currentFile: BatchQueuedFile? {
        guard state == .processing, currentIndex < queue.count else { return nil }
        return queue[currentIndex]
    }
}
