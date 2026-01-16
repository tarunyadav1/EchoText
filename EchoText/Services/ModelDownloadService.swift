import Foundation
import Combine
import WhisperKit

/// Represents the download state for a model
struct ModelDownloadState: Equatable {
    let modelId: String
    var status: DownloadStatus
    var progress: Double
    var error: String?

    enum DownloadStatus: Equatable {
        case notDownloaded
        case downloading
        case downloaded
        case failed
    }

    static func == (lhs: ModelDownloadState, rhs: ModelDownloadState) -> Bool {
        lhs.modelId == rhs.modelId &&
        lhs.status == rhs.status &&
        lhs.progress == rhs.progress &&
        lhs.error == rhs.error
    }
}

/// Service responsible for downloading and managing Whisper models
@MainActor
final class ModelDownloadService: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var downloadStates: [String: ModelDownloadState] = [:]
    @Published private(set) var totalStorageUsed: Int64 = 0

    // MARK: - Private Properties
    private var downloadTasks: [String: Task<Void, Error>] = [:]

    private var modelsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("EchoText/Models", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Initialization
    init() {
        refreshDownloadStates()
    }

    // MARK: - Public Methods

    /// Refresh the download states for all available models
    func refreshDownloadStates() {
        for model in WhisperModel.availableModels {
            let isDownloaded = isModelDownloaded(model.id)
            downloadStates[model.id] = ModelDownloadState(
                modelId: model.id,
                status: isDownloaded ? .downloaded : .notDownloaded,
                progress: isDownloaded ? 1.0 : 0.0
            )
        }

        calculateTotalStorageUsed()
    }

    /// Download a model
    func downloadModel(_ modelId: String) async throws {
        guard WhisperModel.availableModels.first(where: { $0.id == modelId }) != nil else {
            throw NSError(domain: "ModelDownload", code: -1, userInfo: [NSLocalizedDescriptionKey: "Model not found"])
        }

        // Update state to downloading
        downloadStates[modelId] = ModelDownloadState(
            modelId: modelId,
            status: .downloading,
            progress: 0.0
        )

        let task = Task<Void, Error> {
            do {
                // Extract model name for WhisperKit
                let modelName = extractModelName(from: modelId)

                print("[EchoText] Starting download of model: \(modelName)")

                // Update progress to show we're starting
                downloadStates[modelId] = ModelDownloadState(
                    modelId: modelId,
                    status: .downloading,
                    progress: 0.1
                )

                // Actually download the model using WhisperKit
                // WhisperKit will download and cache the model
                let _ = try await WhisperKit(
                    model: modelName,
                    downloadBase: modelsDirectory,
                    verbose: true,
                    prewarm: false
                )

                print("[EchoText] Model download completed: \(modelName)")

                // Mark as downloaded
                downloadStates[modelId] = ModelDownloadState(
                    modelId: modelId,
                    status: .downloaded,
                    progress: 1.0
                )

                calculateTotalStorageUsed()

            } catch is CancellationError {
                downloadStates[modelId] = ModelDownloadState(
                    modelId: modelId,
                    status: .notDownloaded,
                    progress: 0.0
                )
                throw CancellationError()
            } catch {
                print("[EchoText] Model download failed: \(error)")
                downloadStates[modelId] = ModelDownloadState(
                    modelId: modelId,
                    status: .failed,
                    progress: 0.0,
                    error: error.localizedDescription
                )
                throw error
            }
        }

        downloadTasks[modelId] = task
        try await task.value
        downloadTasks.removeValue(forKey: modelId)
    }

    /// Cancel a model download
    func cancelDownload(_ modelId: String) {
        downloadTasks[modelId]?.cancel()
        downloadTasks.removeValue(forKey: modelId)

        downloadStates[modelId] = ModelDownloadState(
            modelId: modelId,
            status: .notDownloaded,
            progress: 0.0
        )
    }

    /// Delete a downloaded model
    func deleteModel(_ modelId: String) throws {
        let modelName = extractModelName(from: modelId)
        let modelPath = modelsDirectory.appendingPathComponent(modelName)

        if FileManager.default.fileExists(atPath: modelPath.path) {
            try FileManager.default.removeItem(at: modelPath)
        }

        downloadStates[modelId] = ModelDownloadState(
            modelId: modelId,
            status: .notDownloaded,
            progress: 0.0
        )

        calculateTotalStorageUsed()
    }

    /// Check if a model is downloaded
    func isModelDownloaded(_ modelId: String) -> Bool {
        let modelName = extractModelName(from: modelId)
        let modelPath = modelsDirectory.appendingPathComponent(modelName)

        // Check if directory exists and has files
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: modelPath.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                let contents = try? FileManager.default.contentsOfDirectory(atPath: modelPath.path)
                return (contents?.count ?? 0) > 0
            }
        }
        return false
    }

    /// Get the download state for a model
    func getDownloadState(for modelId: String) -> ModelDownloadState {
        return downloadStates[modelId] ?? ModelDownloadState(
            modelId: modelId,
            status: .notDownloaded,
            progress: 0.0
        )
    }

    // MARK: - Private Methods

    private func extractModelName(from modelId: String) -> String {
        if modelId.contains("whisper-") {
            let components = modelId.components(separatedBy: "whisper-")
            if components.count > 1 {
                return components[1]
            }
        }
        return modelId
    }

    private func calculateTotalStorageUsed() {
        var total: Int64 = 0

        if let enumerator = FileManager.default.enumerator(
            at: modelsDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = resourceValues.fileSize {
                    total += Int64(fileSize)
                }
            }
        }

        totalStorageUsed = total
    }
}

// MARK: - Storage Formatting
extension ModelDownloadService {
    var formattedStorageUsed: String {
        ByteCountFormatter.string(fromByteCount: totalStorageUsed, countStyle: .file)
    }
}

// MARK: - Cleanup
extension ModelDownloadService {
    /// Delete all downloaded models and app data
    func deleteAllData() throws {
        // Cancel any ongoing downloads
        for (modelId, task) in downloadTasks {
            task.cancel()
            downloadTasks.removeValue(forKey: modelId)
        }

        // Delete models directory
        if FileManager.default.fileExists(atPath: modelsDirectory.path) {
            try FileManager.default.removeItem(at: modelsDirectory)
        }

        // Reset states
        downloadStates.removeAll()
        totalStorageUsed = 0

        // Refresh states
        refreshDownloadStates()
    }

    /// Get the app support directory path for user reference
    var appDataDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("EchoText", isDirectory: true)
    }

    /// Delete all app data including settings, cache, and models
    static func deleteAllAppData() throws {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDataPath = appSupport.appendingPathComponent("EchoText", isDirectory: true)

        if fileManager.fileExists(atPath: appDataPath.path) {
            try fileManager.removeItem(at: appDataPath)
        }

        // Also clear UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
    }
}
