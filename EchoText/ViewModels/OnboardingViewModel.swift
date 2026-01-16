import Foundation
import SwiftUI
import Combine

/// Onboarding steps
enum OnboardingStep: Int, CaseIterable {
    case welcome
    case permissions
    case modelDownload
    case shortcut
    case complete

    var title: String {
        switch self {
        case .welcome:
            return "Welcome to Echo-text"
        case .permissions:
            return "Permissions"
        case .modelDownload:
            return "Download Model"
        case .shortcut:
            return "Set Your Shortcut"
        case .complete:
            return "You're All Set!"
        }
    }

    var description: String {
        switch self {
        case .welcome:
            return "Fast, accurate voice-to-text transcription that runs entirely on your Mac."
        case .permissions:
            return "Echo-text needs a few permissions to work properly."
        case .modelDownload:
            return "Download a speech recognition model to get started."
        case .shortcut:
            return "Choose a keyboard shortcut to start dictating from anywhere."
        case .complete:
            return "You're ready to start dictating. Press your shortcut to begin!"
        }
    }

    var iconName: String {
        switch self {
        case .welcome:
            return "waveform.circle.fill"
        case .permissions:
            return "hand.raised.circle.fill"
        case .modelDownload:
            return "arrow.down.circle.fill"
        case .shortcut:
            return "keyboard.fill"
        case .complete:
            return "checkmark.circle.fill"
        }
    }
}

/// ViewModel for onboarding flow
@MainActor
final class OnboardingViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var currentStep: OnboardingStep = .welcome
    @Published var selectedModelId: String = WhisperModel.defaultModel.id
    @Published var isDownloading: Bool = false
    @Published var downloadProgress: Double = 0.0
    @Published var downloadError: String?
    @Published var microphonePermissionGranted: Bool = false
    @Published var accessibilityPermissionGranted: Bool = false
    @Published var modelDownloaded: Bool = false

    // MARK: - Dependencies
    private weak var appState: AppState?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init(appState: AppState) {
        self.appState = appState

        // Initialize permission states
        self.microphonePermissionGranted = appState.permissionService.microphoneStatus.isGranted
        self.accessibilityPermissionGranted = appState.permissionService.accessibilityStatus.isGranted

        // Initialize model download state
        let selectedId = WhisperModel.defaultModel.id
        let downloadState = appState.modelDownloadService.getDownloadState(for: selectedId)
        self.modelDownloaded = downloadState.status == .downloaded

        setupBindings()
    }

    // MARK: - Navigation

    /// Move to next step
    func nextStep() {
        guard let nextIndex = OnboardingStep.allCases.firstIndex(of: currentStep).map({ $0 + 1 }),
              nextIndex < OnboardingStep.allCases.count else {
            completeOnboarding()
            return
        }

        withAnimation {
            currentStep = OnboardingStep.allCases[nextIndex]
        }
    }

    /// Move to previous step
    func previousStep() {
        guard let prevIndex = OnboardingStep.allCases.firstIndex(of: currentStep).map({ $0 - 1 }),
              prevIndex >= 0 else { return }

        withAnimation {
            currentStep = OnboardingStep.allCases[prevIndex]
        }
    }

    /// Skip to a specific step
    func goToStep(_ step: OnboardingStep) {
        withAnimation {
            currentStep = step
        }
    }

    /// Complete onboarding
    func completeOnboarding() {
        appState?.settings.hasCompletedOnboarding = true
        appState?.settings.save()
        appState?.showOnboarding = false
    }

    // MARK: - Step Actions

    // Permissions
    func requestMicrophonePermission() async {
        _ = await appState?.permissionService.requestMicrophonePermission()
    }

    func requestAccessibilityPermission() {
        appState?.permissionService.requestAccessibilityPermission()
    }

    func checkPermissions() {
        appState?.permissionService.checkAllPermissions()
        // Manually update the published properties to ensure UI updates
        if let permissionService = appState?.permissionService {
            microphonePermissionGranted = permissionService.microphoneStatus.isGranted
            accessibilityPermissionGranted = permissionService.accessibilityStatus.isGranted
        }
    }

    // Model Download
    func downloadSelectedModel() async {
        guard let downloadService = appState?.modelDownloadService else { return }

        isDownloading = true
        downloadError = nil

        do {
            try await downloadService.downloadModel(selectedModelId)

            // Also load the model
            try await appState?.loadModel(selectedModelId)

            isDownloading = false
        } catch {
            isDownloading = false
            downloadError = error.localizedDescription
        }
    }

    func cancelDownload() {
        appState?.modelDownloadService.cancelDownload(selectedModelId)
        isDownloading = false
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Track download progress and state
        appState?.modelDownloadService.$downloadStates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] states in
                guard let self = self else { return }
                if let state = states[self.selectedModelId] {
                    self.downloadProgress = state.progress
                    self.modelDownloaded = state.status == .downloaded
                }
            }
            .store(in: &cancellables)

        // Track microphone permission changes
        appState?.permissionService.$microphoneStatus
            .receive(on: DispatchQueue.main)
            .map { $0.isGranted }
            .sink { [weak self] isGranted in
                self?.microphonePermissionGranted = isGranted
            }
            .store(in: &cancellables)

        // Track accessibility permission changes
        appState?.permissionService.$accessibilityStatus
            .receive(on: DispatchQueue.main)
            .map { $0.isGranted }
            .sink { [weak self] isGranted in
                self?.accessibilityPermissionGranted = isGranted
            }
            .store(in: &cancellables)
    }

    // MARK: - Computed Properties

    var canProceed: Bool {
        switch currentStep {
        case .welcome:
            return true
        case .permissions:
            return microphonePermissionGranted
        case .modelDownload:
            return modelDownloaded
        case .shortcut:
            return true
        case .complete:
            return true
        }
    }

    var isModelDownloaded: Bool {
        modelDownloaded
    }


    var progressPercentage: Double {
        Double(OnboardingStep.allCases.firstIndex(of: currentStep) ?? 0) / Double(OnboardingStep.allCases.count - 1)
    }

    var isFirstStep: Bool {
        currentStep == .welcome
    }

    var isLastStep: Bool {
        currentStep == .complete
    }

    var recommendedModels: [WhisperModel] {
        // Show top 3 recommended models
        [
            WhisperModel.availableModels.first { $0.size == .base },
            WhisperModel.availableModels.first { $0.size == .small },
            WhisperModel.availableModels.first { $0.size == .largev3Turbo }
        ].compactMap { $0 }
    }
}
