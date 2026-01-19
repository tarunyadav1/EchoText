import Foundation
import SwiftUI
import Combine
import UniformTypeIdentifiers

/// ViewModel for batch transcription UI
@MainActor
final class BatchTranscriptionViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Service that handles the actual batch processing
    @Published private(set) var service: BatchTranscriptionService

    /// Whether the file drop zone is being targeted
    @Published var isDragging: Bool = false

    /// Currently selected file for viewing details
    @Published var selectedFileId: UUID?

    /// Show settings popover
    @Published var showSettings: Bool = false

    /// Selected export format
    @Published var selectedExportFormat: ExportFormat = .txt

    /// Show export confirmation
    @Published var showExportConfirmation: Bool = false

    /// Last export result URL
    @Published var lastExportURL: URL?

    /// Error message for display
    @Published var errorMessage: String?

    /// Show error alert
    @Published var showError: Bool = false

    /// Success message for toast
    @Published var successMessage: String?

    /// Show success toast
    @Published var showSuccess: Bool = false

    // MARK: - Settings

    /// Auto-save results as each file completes
    @Published var autoSaveEnabled: Bool = false {
        didSet {
            service.autoSaveResults = autoSaveEnabled
        }
    }

    /// Auto-save format
    @Published var autoSaveFormat: ExportFormat = .txt {
        didSet {
            service.autoSaveFormat = autoSaveFormat
        }
    }

    /// Maximum retry attempts
    @Published var maxRetryAttempts: Int = 1 {
        didSet {
            service.maxRetryAttempts = maxRetryAttempts
        }
    }

    // MARK: - Dependencies

    private weak var appState: AppState?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(appState: AppState) {
        self.appState = appState
        self.service = BatchTranscriptionService()

        // Configure service with dependencies
        if let whisperService = appState.whisperService as WhisperService? {
            service.configure(whisperService: whisperService, appState: appState)
        }

        // Observe service state changes
        setupBindings()
    }

    /// Reconfigure with the actual app state (called from view onAppear)
    func configure(appState: AppState) {
        self.appState = appState
        if let whisperService = appState.whisperService as WhisperService? {
            service.configure(whisperService: whisperService, appState: appState)
        }
    }

    private func setupBindings() {
        // Observe service state for notifications
        service.$state
            .removeDuplicates()
            .sink { [weak self] state in
                self?.handleStateChange(state)
            }
            .store(in: &cancellables)

        // Forward queue changes to trigger view updates
        service.$queue
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        // Forward overall progress changes
        service.$overallProgress
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    private func handleStateChange(_ state: BatchTranscriptionState) {
        switch state {
        case .completed:
            let completed = service.completedCount
            let failed = service.failedCount
            if failed > 0 {
                showSuccessMessage("Completed \(completed) file\(completed == 1 ? "" : "s") with \(failed) failure\(failed == 1 ? "" : "s")")
            } else {
                showSuccessMessage("Successfully transcribed \(completed) file\(completed == 1 ? "" : "s")")
            }
        default:
            break
        }
    }

    // MARK: - Queue Management

    /// Add files to the queue
    func addFiles(_ urls: [URL]) {
        let validURLs = urls.filter { service.isSupported($0) }
        service.addFiles(validURLs)

        if validURLs.count < urls.count {
            let skipped = urls.count - validURLs.count
            showErrorMessage("\(skipped) file\(skipped == 1 ? "" : "s") skipped (unsupported format)")
        }
    }

    /// Remove a file from the queue
    func removeFile(_ file: BatchQueuedFile) {
        service.removeFile(file)
    }

    /// Remove completed files
    func removeCompleted() {
        service.removeCompleted()
    }

    /// Remove failed files
    func removeFailed() {
        service.removeFailed()
    }

    /// Clear all files
    func clearQueue() {
        service.clearQueue()
        selectedFileId = nil
    }

    /// Move file up in queue
    func moveUp(_ file: BatchQueuedFile) {
        service.moveUp(file)
    }

    /// Move file down in queue
    func moveDown(_ file: BatchQueuedFile) {
        service.moveDown(file)
    }

    /// Retry a failed file
    func retryFile(_ file: BatchQueuedFile) {
        service.retryFile(file)
    }

    /// Retry all failed files
    func retryAllFailed() {
        service.retryAllFailed()
    }

    // MARK: - Processing Control

    /// Start batch processing
    func startProcessing() {
        guard service.canStart else { return }

        // Check if model is loaded for the selected engine
        guard let appState = appState else {
            showErrorMessage("App state not available")
            return
        }

        let selectedEngine = appState.settings.transcriptionEngine
        switch selectedEngine {
        case .parakeet:
            guard appState.parakeetService.isModelLoaded else {
                showErrorMessage("Please download and load a Parakeet model first")
                return
            }
        case .whisper:
            guard appState.whisperService.isModelLoaded else {
                showErrorMessage("Please download and load a Whisper model first")
                return
            }
        }

        service.start()
    }

    /// Pause processing
    func pauseProcessing() {
        service.pause()
    }

    /// Resume processing
    func resumeProcessing() {
        service.resume()
    }

    /// Cancel processing
    func cancelProcessing() {
        service.cancel()
    }

    // MARK: - Export

    /// Export all completed results
    func exportAll() {
        Task {
            if let url = await service.exportAllResults(format: selectedExportFormat) {
                lastExportURL = url
                showSuccessMessage("Exported \(service.completedCount) file\(service.completedCount == 1 ? "" : "s")")
            }
        }
    }

    /// Export a single file's result
    func exportFile(_ file: BatchQueuedFile) {
        Task {
            if let url = await service.exportResult(for: file, format: selectedExportFormat) {
                lastExportURL = url
                showSuccessMessage("Exported transcript")
            }
        }
    }

    /// Copy transcript text to clipboard
    func copyTranscript(_ file: BatchQueuedFile) {
        guard let result = file.result else { return }
        ExportService.copyCleanText(result)
        showSuccessMessage("Copied to clipboard")
    }

    /// Copy transcript with timestamps to clipboard
    func copyWithTimestamps(_ file: BatchQueuedFile) {
        guard let result = file.result else { return }
        ExportService.copyWithTimestamps(result)
        showSuccessMessage("Copied with timestamps")
    }

    // MARK: - File Selection

    /// Select a file for viewing
    func selectFile(_ file: BatchQueuedFile) {
        selectedFileId = file.id
    }

    /// Deselect current file
    func deselectFile() {
        selectedFileId = nil
    }

    /// Get currently selected file
    var selectedFile: BatchQueuedFile? {
        guard let id = selectedFileId else { return nil }
        return service.queue.first { $0.id == id }
    }

    // MARK: - Drag & Drop

    /// Handle file drop from providers
    func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            let types = provider.registeredTypeIdentifiers

            // Try loading as file URL first (most common for Finder drops)
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                loadFileURL(from: provider, typeIdentifier: UTType.fileURL.identifier)
            }
            // Try loading from any audio type
            else if let audioType = types.first(where: { type in
                UTType(type)?.conforms(to: .audio) == true || UTType(type)?.conforms(to: .movie) == true
            }) {
                loadFileURL(from: provider, typeIdentifier: audioType)
            }
            // Fallback to URL object loading
            else if provider.canLoadObject(ofClass: URL.self) {
                _ = provider.loadObject(ofClass: URL.self) { [weak self] url, _ in
                    if let url = url {
                        DispatchQueue.main.async {
                            self?.addFiles([url])
                        }
                    }
                }
            } else if let firstType = types.first {
                // Last resort: try the first registered type
                loadFileURL(from: provider, typeIdentifier: firstType)
            }
        }

        return true
    }

    /// Helper to load file URL from a provider with a given type identifier
    private func loadFileURL(from provider: NSItemProvider, typeIdentifier: String) {
        provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { [weak self] item, error in
            guard error == nil else { return }

            DispatchQueue.main.async {
                if let data = item as? Data {
                    // Try to decode as URL string
                    if let urlString = String(data: data, encoding: .utf8),
                       let url = URL(string: urlString) {
                        self?.addFiles([url])
                        return
                    }
                    // Try to decode as bookmark data
                    var isStale = false
                    if let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale) {
                        self?.addFiles([url])
                        return
                    }
                }

                if let url = item as? URL {
                    self?.addFiles([url])
                } else if let nsurl = item as? NSURL, let url = nsurl as URL? {
                    self?.addFiles([url])
                }
            }
        }
    }

    /// Check if a file type is supported
    func isSupported(_ url: URL) -> Bool {
        service.isSupported(url)
    }

    // MARK: - File Picker

    /// Open file picker to add files
    func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = BatchTranscriptionService.supportedTypes

        if panel.runModal() == .OK {
            addFiles(panel.urls)
        }
    }

    // MARK: - Notifications

    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true

        // Auto-dismiss
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            showError = false
        }
    }

    private func showSuccessMessage(_ message: String) {
        successMessage = message
        showSuccess = true

        // Auto-dismiss
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            showSuccess = false
        }
    }
}

// MARK: - Computed Properties

extension BatchTranscriptionViewModel {
    /// Queue of files (forwarded from service)
    var queue: [BatchQueuedFile] {
        service.queue
    }

    /// Current processing state
    var state: BatchTranscriptionState {
        service.state
    }

    /// Overall progress
    var overallProgress: Double {
        service.overallProgress
    }

    /// Whether processing is active
    var isProcessing: Bool {
        service.state == .processing
    }

    /// Whether processing is paused
    var isPaused: Bool {
        service.state == .paused
    }

    /// Pending file count
    var pendingCount: Int {
        service.pendingCount
    }

    /// Completed file count
    var completedCount: Int {
        service.completedCount
    }

    /// Failed file count
    var failedCount: Int {
        service.failedCount
    }

    /// Whether queue is empty
    var isEmpty: Bool {
        service.isEmpty
    }

    /// Whether can start processing
    var canStart: Bool {
        service.canStart
    }

    /// Whether can pause
    var canPause: Bool {
        service.canPause
    }

    /// Whether can resume
    var canResume: Bool {
        service.canResume
    }

    /// Whether can export
    var canExport: Bool {
        service.canExport
    }

    /// Has completed files
    var hasCompletedFiles: Bool {
        service.hasCompletedFiles
    }

    /// Has failed files
    var hasFailedFiles: Bool {
        service.hasFailedFiles
    }

    /// Status text
    var statusText: String {
        service.statusText
    }

    /// Formatted elapsed time
    var formattedElapsedTime: String? {
        service.formattedElapsedTime
    }

    /// Formatted estimated time
    var formattedEstimatedTime: String? {
        service.formattedEstimatedTime
    }

    /// Total queue size
    var totalQueueSize: String {
        service.totalQueueSize
    }
}
