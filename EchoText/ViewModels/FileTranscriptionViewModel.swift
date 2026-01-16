import Foundation
import SwiftUI
import Combine
import UniformTypeIdentifiers

/// Represents a file in the transcription queue
struct QueuedFile: Identifiable {
    let id = UUID()
    let url: URL
    var status: TranscriptionStatus
    var progress: Double
    var result: TranscriptionResult?
    var error: String?

    enum TranscriptionStatus {
        case pending
        case processing
        case completed
        case failed
    }

    var fileName: String {
        url.lastPathComponent
    }

    var fileSize: String {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int64 else {
            return "Unknown"
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

/// ViewModel for file-based transcription
@MainActor
final class FileTranscriptionViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var queuedFiles: [QueuedFile] = []
    @Published var isProcessing: Bool = false
    @Published var currentFileIndex: Int = 0
    @Published var overallProgress: Double = 0.0
    @Published var selectedExportFormat: ExportFormat = .txt
    @Published var showExportPanel: Bool = false
    @Published var isDragging: Bool = false

    // MARK: - Dependencies
    private weak var appState: AppState?
    private var processingTask: Task<Void, Never>?

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

    /// Remove a file from the queue
    func removeFile(_ file: QueuedFile) {
        queuedFiles.removeAll { $0.id == file.id }
    }

    /// Clear all files from the queue
    func clearQueue() {
        queuedFiles.removeAll()
        currentFileIndex = 0
        overallProgress = 0.0
    }

    /// Check if a file type is supported
    func isSupported(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return Self.supportedExtensions.contains(ext)
    }

    // MARK: - Transcription

    /// Start processing the queue
    func startProcessing() {
        guard !isProcessing, !queuedFiles.isEmpty else { return }

        isProcessing = true
        currentFileIndex = 0

        processingTask = Task {
            for index in queuedFiles.indices {
                guard !Task.isCancelled else { break }

                currentFileIndex = index
                await processFile(at: index)
                updateOverallProgress()
            }

            isProcessing = false
        }
    }

    /// Cancel processing
    func cancelProcessing() {
        processingTask?.cancel()
        processingTask = nil
        isProcessing = false

        // Reset pending files
        for index in queuedFiles.indices {
            if queuedFiles[index].status == .processing {
                queuedFiles[index].status = .pending
                queuedFiles[index].progress = 0.0
            }
        }
    }

    /// Process a single file
    private func processFile(at index: Int) async {
        guard index < queuedFiles.count else { return }

        queuedFiles[index].status = .processing
        queuedFiles[index].progress = 0.0

        let fileURL = queuedFiles[index].url

        do {
            guard let whisperService = appState?.whisperService else {
                throw NSError(domain: "FileTranscription", code: -1, userInfo: [NSLocalizedDescriptionKey: "Whisper service not available"])
            }

            // Get language setting
            let language = appState?.settings.selectedLanguage
            let transcriptionLanguage = language == "auto" ? nil : language

            // Transcribe
            let result = try await whisperService.transcribe(audioURL: fileURL, language: transcriptionLanguage)

            queuedFiles[index].status = .completed
            queuedFiles[index].progress = 1.0
            queuedFiles[index].result = result
        } catch {
            queuedFiles[index].status = .failed
            queuedFiles[index].error = error.localizedDescription
        }
    }

    private func updateOverallProgress() {
        let completed = queuedFiles.filter { $0.status == .completed || $0.status == .failed }.count
        overallProgress = Double(completed) / Double(queuedFiles.count)
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

    // MARK: - File Dropping

    /// Handle file drop
    func handleDrop(providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []

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
        queuedFiles.filter { $0.status == .pending }.count
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

    var canExport: Bool {
        hasCompletedFiles && !isProcessing
    }
}
