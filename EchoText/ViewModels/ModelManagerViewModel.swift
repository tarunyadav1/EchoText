import Foundation
import SwiftUI
import Combine

/// ViewModel for model management
@MainActor
final class ModelManagerViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var models: [WhisperModel] = WhisperModel.availableModels
    @Published var selectedModelId: String = ""
    @Published var isLoadingModel: Bool = false
    @Published var loadingError: String?

    // MARK: - Dependencies
    private weak var appState: AppState?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init(appState: AppState) {
        self.appState = appState
        self.selectedModelId = appState.settings.selectedModelId
        setupBindings()
    }

    // MARK: - Actions

    /// Download a model
    func downloadModel(_ modelId: String) async {
        guard let downloadService = appState?.modelDownloadService else { return }

        do {
            try await downloadService.downloadModel(modelId)
        } catch {
            loadingError = error.localizedDescription
        }
    }

    /// Cancel download
    func cancelDownload(_ modelId: String) {
        appState?.modelDownloadService.cancelDownload(modelId)
    }

    /// Delete a model
    func deleteModel(_ modelId: String) {
        do {
            try appState?.modelDownloadService.deleteModel(modelId)

            // If this was the selected model, reset to default
            if modelId == selectedModelId {
                selectedModelId = WhisperModel.defaultModel.id
            }
        } catch {
            loadingError = error.localizedDescription
        }
    }

    /// Select and load a model
    func selectModel(_ modelId: String) async {
        guard modelId != selectedModelId else { return }

        isLoadingModel = true
        loadingError = nil

        do {
            try await appState?.loadModel(modelId)
            selectedModelId = modelId
        } catch {
            loadingError = error.localizedDescription
        }

        isLoadingModel = false
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Sync with download service
        appState?.modelDownloadService.$downloadStates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - Computed Properties

    func downloadState(for modelId: String) -> ModelDownloadState {
        appState?.modelDownloadService.getDownloadState(for: modelId) ?? ModelDownloadState(
            modelId: modelId,
            status: .notDownloaded,
            progress: 0.0
        )
    }

    func isDownloaded(_ modelId: String) -> Bool {
        downloadState(for: modelId).status == .downloaded
    }

    func isDownloading(_ modelId: String) -> Bool {
        downloadState(for: modelId).status == .downloading
    }

    func downloadProgress(_ modelId: String) -> Double {
        downloadState(for: modelId).progress
    }

    var currentModelName: String {
        models.first { $0.id == selectedModelId }?.name ?? "No model selected"
    }

    var isModelLoaded: Bool {
        appState?.whisperService.isModelLoaded ?? false
    }

    var totalStorageUsed: String {
        appState?.modelDownloadService.formattedStorageUsed ?? "0 MB"
    }
}

// MARK: - Model Recommendations
extension ModelManagerViewModel {
    /// Get recommended model based on device capabilities
    var recommendedModel: WhisperModel {
        // Check available memory
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let memoryInGB = Double(physicalMemory) / 1_073_741_824

        if memoryInGB >= 16 {
            // 16GB+ RAM: Can use Large models
            return models.first { $0.size == .largev3Turbo } ?? models.first { $0.size == .medium } ?? WhisperModel.defaultModel
        } else if memoryInGB >= 8 {
            // 8GB RAM: Medium model
            return models.first { $0.size == .small } ?? WhisperModel.defaultModel
        } else {
            // Less than 8GB: Use Base or Tiny
            return models.first { $0.size == .base } ?? WhisperModel.defaultModel
        }
    }

    var recommendedModelReason: String {
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let memoryInGB = Double(physicalMemory) / 1_073_741_824

        return "Based on your \(Int(memoryInGB))GB RAM, we recommend this model for the best balance of speed and accuracy."
    }
}
