import Foundation
import SwiftUI
import Combine

/// Central state coordinator for the application
@MainActor
final class AppState: ObservableObject {
    // MARK: - Published Properties

    // Recording State
    @Published var recordingState: RecordingState = .idle
    @Published var audioLevel: Float = 0.0
    @Published var recordingDuration: TimeInterval = 0.0

    // Transcription
    @Published var lastTranscription: TranscriptionResult?
    @Published var transcriptionHistory: [TranscriptionResult] = []

    // UI State
    @Published var isFloatingWindowVisible = false
    @Published var showOnboarding = false
    @Published var errorMessage: String?
    @Published var showError = false

    // Settings
    @Published var settings: AppSettings

    // MARK: - Services
    let audioService: AudioRecordingService
    let whisperService: WhisperService
    let hotkeyService: HotkeyService
    let textInsertionService: TextInsertionService
    let permissionService: PermissionService
    let modelDownloadService: ModelDownloadService
    let voiceActivityDetector: VoiceActivityDetector

    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var recordingFileURL: URL?

    // MARK: - Initialization
    init() {
        // Load settings first
        let loadedSettings = AppSettings.load()
        self.settings = loadedSettings

        // Initialize services
        self.audioService = AudioRecordingService()
        self.whisperService = WhisperService()
        self.hotkeyService = HotkeyService()
        self.textInsertionService = TextInsertionService()
        self.permissionService = PermissionService()
        self.modelDownloadService = ModelDownloadService()
        self.voiceActivityDetector = VoiceActivityDetector(
            energyThreshold: loadedSettings.vadEnergyThreshold,
            silenceThreshold: loadedSettings.vadSilenceThreshold
        )

        // Setup bindings
        setupBindings()
        setupHotkeyHandlers()

        // Check if onboarding needed
        if !settings.hasCompletedOnboarding {
            showOnboarding = true
        }

        // Load model if available
        Task {
            await loadDefaultModel()
        }
    }

    // MARK: - Command Handling

    /// Enum representing all possible user actions
    enum ActionCommand {
        case toggle
        case start
        case stop
        case cancel
    }

    /// Unified entry point for all recording actions to prevent race conditions
    func handleAction(_ command: ActionCommand) {
        Task { @MainActor in
            NSLog("[AppState] handleAction called: %@ (current state: %@)", String(describing: command), String(describing: recordingState))
            
            switch command {
            case .toggle:
                await toggleRecording()
            case .start:
                await startRecording()
            case .stop:
                await stopRecording()
            case .cancel:
                cancelRecording()
            }
        }
    }

    // MARK: - Recording Control

    /// Toggle recording state
    private func toggleRecording() async {
        switch recordingState {
        case .idle:
            await startRecording()
        case .recording:
            await stopRecording()
        case .processing:
            // Cannot toggle while processing
            break
        }
    }

    /// Start recording audio
    private func startRecording() async {
        guard recordingState == .idle else { return }

        // Check accessibility permissions FIRST if auto-insert is enabled
        if settings.autoInsertText && !textInsertionService.checkAccessibilityAccess() {
            NSLog("[AppState] Accessibility not enabled - requesting permission")
            textInsertionService.requestAccessibilityAccess()
            errorMessage = "Accessibility permission required. Please enable it in System Settings → Privacy & Security → Accessibility, then add EchoText."
            showError = true
            return
        }

        // Save the currently active app BEFORE we do anything else
        // This is the app we'll paste the transcription into later
        textInsertionService.saveActiveApp()

        do {
            recordingFileURL = try await audioService.startRecording()
            recordingState = .recording

            // Enable cancel shortcut only while recording
            hotkeyService.enableCancelShortcut()

            // Start VAD if in voice activity mode
            if settings.recordingMode == .voiceActivity {
                voiceActivityDetector.startMonitoring()
                voiceActivityDetector.onSilenceDetected = { [weak self] in
                    self?.handleAction(.stop)
                }
            }

            // Show floating window
            if settings.showFloatingWindow {
                isFloatingWindowVisible = true
                NotificationCenter.default.post(name: .showFloatingWindow, object: nil)
            }

            NotificationCenter.default.post(name: .recordingStarted, object: nil)
        } catch {
            handleError(error)
        }
    }

    /// Stop recording and transcribe
    private func stopRecording() async {
        guard recordingState == .recording else { return }

        voiceActivityDetector.stopMonitoring()
        hotkeyService.disableCancelShortcut()
        recordingState = .processing

        // Keep floating window visible during processing (will be hidden after transcription)

        guard let audioURL = audioService.stopRecording() else {
            recordingState = .idle
            handleError(AudioRecordingError.noAudioData)
            return
        }

        // Check if recording is too short (less than 0.3 seconds)
        if recordingDuration < 0.3 {
            print("[EchoText] Recording too short (\(recordingDuration)s), discarding.")
            recordingState = .idle
            try? FileManager.default.removeItem(at: audioURL)
            audioService.clearRecordingBuffer()
            return
        }

        // Check if model is loaded
        guard whisperService.isModelLoaded else {
            recordingState = .idle
            handleError(WhisperServiceError.modelNotLoaded)
            try? FileManager.default.removeItem(at: audioURL)
            return
        }

        do {
            // Try using in-memory audio data first (more reliable)
            let result: TranscriptionResult

            if let audioData = audioService.getRecordedAudioData(), !audioData.isEmpty {
                print("[EchoText] Using in-memory audio buffer: \(audioData.count) samples")
                // Use in-memory buffer (bypasses file I/O issues)
                let language = settings.selectedLanguage == "auto" ? nil : settings.selectedLanguage
                result = try await whisperService.transcribe(audioData: audioData, language: language)
            } else {
                print("[EchoText] Using file-based audio: \(audioURL.path)")
                // Fallback to file-based transcription
                let language = settings.selectedLanguage == "auto" ? nil : settings.selectedLanguage
                result = try await whisperService.transcribe(audioURL: audioURL, language: language)
            }

            print("[EchoText] Transcription result: '\(result.text)'")

            // Update state
            lastTranscription = result
            transcriptionHistory.insert(result, at: 0)

            // Insert text if enabled and not empty
            NSLog("[AppState] autoInsertText=%d, result.isEmpty=%d, text='%@'", settings.autoInsertText ? 1 : 0, result.isEmpty ? 1 : 0, result.text)
            if settings.autoInsertText && !result.isEmpty {
                NSLog("[AppState] Calling textInsertionService.insertText...")
                try await textInsertionService.insertText(result.text)
                NSLog("[AppState] Text insertion complete")
            } else {
                NSLog("[AppState] Auto-insert disabled or result empty - NOT inserting")
            }

            // Clear the audio buffer now that we're done
            audioService.clearRecordingBuffer()

            // Cleanup temporary file
            try? FileManager.default.removeItem(at: audioURL)

            NotificationCenter.default.post(
                name: .transcriptionCompleted,
                object: nil,
                userInfo: ["result": result]
            )
        } catch {
            print("[EchoText] Error: \(error.localizedDescription)")
            handleError(error)
            try? FileManager.default.removeItem(at: audioURL)
        }

        recordingState = .idle

        // Hide floating window now that processing is complete
        hideFloatingWindow()

        NotificationCenter.default.post(name: .recordingStopped, object: nil)
    }

    /// Cancel recording without transcribing
    private func cancelRecording() {
        guard recordingState == .recording else { return }

        voiceActivityDetector.stopMonitoring()
        hotkeyService.disableCancelShortcut()
        audioService.cancelRecording()
        recordingState = .idle
        hideFloatingWindow()
    }

    // MARK: - Model Management

    /// Load the default/selected model
    func loadDefaultModel() async {
        guard !whisperService.isModelLoaded else { return }

        do {
            try await whisperService.loadModel(settings.selectedModelId)
        } catch {
            // Model might not be downloaded yet
            print("Could not load model: \(error)")
        }
    }

    /// Load a specific model
    func loadModel(_ modelId: String) async throws {
        try await whisperService.loadModel(modelId)
        settings.selectedModelId = modelId
        settings.save()
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Bind audio level from recording service
        audioService.$audioLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.audioLevel = level
                self?.voiceActivityDetector.processAudioLevel(level)
            }
            .store(in: &cancellables)

        // Bind recording duration
        audioService.$recordingDuration
            .receive(on: DispatchQueue.main)
            .assign(to: &$recordingDuration)

        // Save settings when changed
        settings.objectWillChange
            .debounce(for: 0.5, scheduler: DispatchQueue.main)
            .sink { [weak self] in
                self?.settings.save()
            }
            .store(in: &cancellables)
    }

    private func setupHotkeyHandlers() {
        hotkeyService.setRecordingMode(settings.recordingMode)

        hotkeyService.onToggleRecording = { [weak self] in
            self?.handleAction(.toggle)
        }

        hotkeyService.onStartHoldRecording = { [weak self] in
            self?.handleAction(.start)
        }

        hotkeyService.onStopHoldRecording = { [weak self] in
            self?.handleAction(.stop)
        }

        hotkeyService.onCancelRecording = { [weak self] in
            self?.handleAction(.cancel)
        }

        // Update hotkey service when recording mode changes
        $settings
            .map(\.recordingMode)
            .removeDuplicates()
            .sink { [weak self] mode in
                self?.hotkeyService.setRecordingMode(mode)
            }
            .store(in: &cancellables)
    }

    private func hideFloatingWindow() {
        isFloatingWindowVisible = false
        NotificationCenter.default.post(name: .hideFloatingWindow, object: nil)
    }

    private func handleError(_ error: Error) {
        // Provide more helpful messages for specific errors
        if let textError = error as? TextInsertionError {
            switch textError {
            case .accessibilityNotEnabled:
                errorMessage = "Please enable Accessibility for EchoText in System Settings → Privacy & Security → Accessibility"
            default:
                errorMessage = textError.localizedDescription
            }
        } else {
            errorMessage = error.localizedDescription
        }
        showError = true

        // Auto-dismiss after 8 seconds (longer for accessibility message)
        Task {
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            showError = false
        }
    }
}

// MARK: - Convenience Extensions
extension AppState {
    var isRecording: Bool {
        recordingState == .recording
    }

    var isProcessing: Bool {
        recordingState == .processing
    }

    var isIdle: Bool {
        recordingState == .idle
    }

    var formattedDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
