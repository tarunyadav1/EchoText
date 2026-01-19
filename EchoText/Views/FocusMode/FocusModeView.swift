import SwiftUI
import Combine
import AppKit

/// Main Focus Mode view - full screen distraction-free transcription
struct FocusModeView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = FocusModeViewModelWrapper()
    @State private var settings: FocusModeSettings = FocusModeSettings()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                settings.theme.backgroundColor
                    .ignoresSafeArea()

                // Main content
                VStack(spacing: 0) {
                    // Top status bar
                    topStatusBar
                        .padding(.top, 60)

                    Spacer()

                    // Centered text area
                    textArea
                        .frame(maxWidth: min(geometry.size.width * 0.8, 900))

                    Spacer()

                    // Bottom bar with stats and customization
                    bottomBar

                    // Customization panel
                    FocusModeCustomizationPanel(
                        settings: $settings,
                        isVisible: $viewModel.isCustomizationVisible
                    )
                    .padding(.horizontal, 40)
                    .padding(.bottom, 30)
                }
            }
        }
        .preferredColorScheme(.dark)
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.escape) {
            exitFocusMode()
            return .handled
        }
        .onAppear {
            setupAndStart()
        }
        .onDisappear {
            cleanup()
        }
        .onChange(of: settings) { _, newSettings in
            appState.settings.focusModeSettings = newSettings
            appState.settings.save()
        }
        .onReceive(NotificationCenter.default.publisher(for: .exitFocusMode)) { _ in
            exitFocusMode()
        }
    }

    // MARK: - Top Status Bar

    private var topStatusBar: some View {
        HStack {
            Spacer()

            FocusModeStatusIndicator(
                isRecording: viewModel.isRecording,
                isTranscribing: viewModel.isTranscribing,
                shortcutHint: appState.hotkeyService.toggleRecordingShortcutString
            )

            Spacer()
        }
    }

    // MARK: - Text Area

    private var textArea: some View {
        VStack(spacing: 16) {
            FocusModeTextView(
                text: viewModel.transcribedText,
                settings: settings,
                showCursor: viewModel.isRecording
            )
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            // Escape hint
            if settings.showHints {
                FocusModeHint(text: "Press Esc to exit")
            }

            Spacer()

            // Stats
            if settings.showWordCount || settings.showDuration {
                FocusModeStatsBadge(
                    wordCount: viewModel.wordCount,
                    duration: viewModel.formattedDuration,
                    showWordCount: settings.showWordCount,
                    showDuration: settings.showDuration
                )
            }
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 16)
    }

    // MARK: - Private Methods

    private func setupAndStart() {
        settings = appState.settings.focusModeSettings

        // Configure the view model with services (both transcription engines)
        viewModel.configure(
            audioService: appState.audioService,
            whisperService: appState.whisperService,
            parakeetService: appState.parakeetService
        )

        // Start recording
        Task {
            await viewModel.startRecording()
        }
    }

    private func cleanup() {
        Task {
            await viewModel.stopRecording()
        }
    }

    private func exitFocusMode() {
        Task {
            // Stop recording if still recording
            if viewModel.isRecording {
                await viewModel.stopRecording()
            }

            // Copy to clipboard if there's text
            if !viewModel.transcribedText.isEmpty {
                viewModel.copyToClipboard()

                // Add to transcription history
                let result = TranscriptionResult(
                    text: viewModel.transcribedText,
                    segments: [],
                    language: nil,
                    duration: viewModel.recordingDuration,
                    processingTime: 0,
                    modelUsed: appState.whisperService.loadedModelId ?? "unknown"
                )
                appState.transcriptionHistory.insert(result, at: 0)
            }

            // Close the window
            appState.handleAction(.exitFocusMode)
        }
    }
}

// MARK: - ViewModel Wrapper

/// Observable wrapper that can be created at init time and configured later
@MainActor
final class FocusModeViewModelWrapper: ObservableObject {
    // MARK: - Published Properties
    @Published var transcribedText: String = ""
    @Published var isRecording: Bool = false
    @Published var isTranscribing: Bool = false
    @Published var recordingDuration: TimeInterval = 0.0
    @Published var wordCount: Int = 0
    @Published var errorMessage: String?
    @Published var isCustomizationVisible: Bool = true

    // MARK: - Services
    private var audioService: AudioRecordingService?
    private var whisperService: WhisperService?
    private var parakeetService: ParakeetService?
    private var streamingTask: Task<Void, Never>?
    private var isConfigured = false

    // MARK: - Private Properties
    private var recordingStartTime: Date?
    private var durationTimer: Timer?

    // MARK: - Streaming Transcription State
    /// Confirmed text that won't change (from finalized chunks)
    private var confirmedText: String = ""
    /// Last sample index where we finalized the transcription
    private var lastFinalizedSample: Int = 0
    /// How often to transcribe (in seconds)
    private let chunkIntervalSeconds: Double = 1.5
    /// Sliding window size in seconds (transcribe last N seconds for context)
    private let windowSizeSeconds: Double = 8.0
    /// Overlap to keep for context when finalizing
    private let overlapSeconds: Double = 2.0
    /// Sample rate
    private let sampleRate: Int = 16000

    // MARK: - Configuration

    func configure(audioService: AudioRecordingService, whisperService: WhisperService, parakeetService: ParakeetService) {
        self.audioService = audioService
        self.whisperService = whisperService
        self.parakeetService = parakeetService
        self.isConfigured = true
        NSLog("[FocusModeVM] Configured with services (whisper loaded: \(whisperService.isModelLoaded), parakeet loaded: \(parakeetService.isModelLoaded))")
    }

    /// Check if the active engine's model is loaded
    private var isActiveEngineModelLoaded: Bool {
        let settings = AppSettings.load()
        switch settings.transcriptionEngine {
        case .whisper:
            return whisperService?.isModelLoaded ?? false
        case .parakeet:
            return parakeetService?.isModelLoaded ?? false
        }
    }

    // MARK: - Public Methods

    func startRecording() async {
        guard isConfigured else {
            NSLog("[FocusModeVM] Not configured yet")
            return
        }
        guard let audioService = audioService else {
            NSLog("[FocusModeVM] Audio service not available")
            return
        }
        guard !isRecording else {
            NSLog("[FocusModeVM] Already recording")
            return
        }

        // Reset state
        transcribedText = ""
        wordCount = 0
        errorMessage = nil
        confirmedText = ""
        lastFinalizedSample = 0

        do {
            NSLog("[FocusModeVM] Starting recording... calling audioService.startRecording()")
            let recordingURL = try await audioService.startRecording()
            NSLog("[FocusModeVM] audioService.startRecording() returned: \(recordingURL.path)")

            // Update state on main thread
            isRecording = true
            recordingStartTime = Date()
            startDurationTimer()

            NSLog("[FocusModeVM] Recording started successfully, isRecording=\(isRecording)")

            // Start streaming transcription
            startStreamingTranscription()
        } catch {
            NSLog("[FocusModeVM] Failed to start recording: \(error)")
            NSLog("[FocusModeVM] Error type: \(type(of: error))")
            errorMessage = error.localizedDescription
        }
    }

    func stopRecording() async {
        guard let audioService = audioService else { return }
        guard isRecording else { return }

        NSLog("[FocusModeVM] Stopping recording...")

        isRecording = false
        stopDurationTimer()
        streamingTask?.cancel()
        streamingTask = nil

        // Stop audio recording
        _ = audioService.stopRecording()

        // Final transcription
        if let audioData = audioService.getRecordedAudioData(), !audioData.isEmpty {
            await transcribeFinal(audioData)
        }

        audioService.clearRecordingBuffer()
        NSLog("[FocusModeVM] Recording stopped")
    }

    func copyToClipboard() {
        guard !transcribedText.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(transcribedText, forType: .string)
        NSLog("[FocusModeVM] Copied to clipboard: \(transcribedText.prefix(50))...")
    }

    var formattedDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Private Methods

    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let startTime = self.recordingStartTime else { return }
                self.recordingDuration = Date().timeIntervalSince(startTime)
            }
        }
    }

    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }

    private func startStreamingTranscription() {
        NSLog("[FocusModeVM] Starting streaming transcription task...")

        // Use Task.detached to avoid main actor contention
        streamingTask = Task.detached { [weak self] in
            guard let self = self else {
                NSLog("[FocusModeVM] Self is nil in streaming task")
                return
            }

            // Get initial isRecording value
            let initialRecording = await self.isRecording
            NSLog("[FocusModeVM] Streaming task started, isRecording=\(initialRecording)")

            while await self.isRecording && !Task.isCancelled {
                // Wait between transcription attempts
                try? await Task.sleep(nanoseconds: UInt64(1.5 * 1_000_000_000)) // 1.5 seconds

                let stillRecording = await self.isRecording
                guard stillRecording && !Task.isCancelled else {
                    NSLog("[FocusModeVM] Exiting streaming loop (isRecording=\(stillRecording), cancelled=\(Task.isCancelled))")
                    break
                }

                NSLog("[FocusModeVM] Calling transcribeWithSlidingWindow...")
                await self.transcribeWithSlidingWindow()
            }

            NSLog("[FocusModeVM] Streaming transcription task ended")
        }
    }

    /// Transcribe using a sliding window for better live performance
    /// Instead of transcribing all audio, we only transcribe the last N seconds
    private func transcribeWithSlidingWindow() async {
        guard let audioService = audioService else {
            NSLog("[FocusModeVM] Audio service is nil!")
            return
        }

        // Check which engine is selected and if its model is loaded
        let settings = AppSettings.load()
        NSLog("[FocusModeVM] transcribeWithSlidingWindow - engine=\(settings.transcriptionEngine.rawValue), isActiveEngineModelLoaded=\(isActiveEngineModelLoaded)")

        guard isActiveEngineModelLoaded else {
            NSLog("[FocusModeVM] Active engine model not loaded (engine: \(settings.transcriptionEngine.rawValue))")
            return
        }

        let audioData = audioService.getRecordedAudioData()
        NSLog("[FocusModeVM] Audio data count: \(audioData?.count ?? 0), lastFinalizedSample: \(lastFinalizedSample)")

        guard let fullAudioData = audioData,
              fullAudioData.count > lastFinalizedSample + sampleRate / 2 else { // Need at least 0.5s new audio
            NSLog("[FocusModeVM] Not enough new audio data")
            return
        }

        isTranscribing = true
        defer { isTranscribing = false }

        // Calculate window size in samples
        let windowSamples = Int(windowSizeSeconds * Double(sampleRate))

        // Determine what audio to transcribe
        // If we have less than the window size, transcribe everything
        // Otherwise, transcribe just the sliding window
        let audioToTranscribe: [Float]
        let isFullTranscription: Bool

        if fullAudioData.count <= windowSamples {
            // Audio is shorter than window - transcribe all of it
            audioToTranscribe = fullAudioData
            isFullTranscription = true
        } else {
            // Use sliding window - transcribe last N seconds
            let startIndex = max(0, fullAudioData.count - windowSamples)
            audioToTranscribe = Array(fullAudioData[startIndex...])
            isFullTranscription = false
        }

        do {
            let shouldRemoveFillers = settings.removeFillerWords

            // For live transcription in Focus Mode, always use Whisper for reliability
            // Parakeet has issues with streaming/live transcription
            guard let whisperService = whisperService else {
                NSLog("[FocusModeVM] Whisper service is nil!")
                return
            }

            // Check if Whisper model is loaded
            guard whisperService.isModelLoaded else {
                NSLog("[FocusModeVM] Whisper model not loaded, cannot transcribe. Please load a Whisper model for Focus Mode.")
                errorMessage = "Please load a Whisper model for Focus Mode"
                return
            }

            NSLog("[FocusModeVM] Calling whisperService.transcribe with \(audioToTranscribe.count) samples...")
            let result = try await whisperService.transcribe(
                audioData: audioToTranscribe,
                language: nil,
                removeFillers: shouldRemoveFillers
            )
            NSLog("[FocusModeVM] Whisper transcription completed: '\(result.text.prefix(50))'")

            let windowText = result.text.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !windowText.isEmpty else { return }

            // Update the displayed text
            if isFullTranscription {
                // Short recording - just use the full transcription
                transcribedText = windowText
            } else {
                // Longer recording - need to merge confirmed text with window text
                // For now, we'll use a simple approach: show confirmed + recent window overlap
                transcribedText = mergeTranscriptions(confirmed: confirmedText, windowText: windowText)

                // Periodically finalize older text to prevent memory issues
                // Finalize when we have enough audio beyond the window
                let overlapSamples = Int(overlapSeconds * Double(sampleRate))
                let finalizableSamples = fullAudioData.count - windowSamples - overlapSamples

                if finalizableSamples > sampleRate * 10 { // 10+ seconds to finalize
                    // Finalize the older portion - take first half of the window text as confirmed
                    let words = windowText.split(separator: " ")
                    if words.count > 4 {
                        let confirmUpTo = words.count / 2
                        let newConfirmed = words.prefix(confirmUpTo).joined(separator: " ")

                        if confirmedText.isEmpty {
                            confirmedText = newConfirmed
                        } else {
                            confirmedText = confirmedText + " " + newConfirmed
                        }

                        lastFinalizedSample = fullAudioData.count - windowSamples / 2
                        NSLog("[FocusModeVM] Finalized up to sample \(lastFinalizedSample)")
                    }
                }
            }

            wordCount = transcribedText.split(separator: " ").count
            NSLog("[FocusModeVM] Live (\(wordCount) words): \(transcribedText.suffix(50))...")
        } catch {
            NSLog("[FocusModeVM] Transcription error: \(error)")
            NSLog("[FocusModeVM] Error type: \(type(of: error)), localizedDescription: \(error.localizedDescription)")
        }
        NSLog("[FocusModeVM] transcribeWithSlidingWindow completed")
    }

    /// Merge confirmed text with new window transcription
    private func mergeTranscriptions(confirmed: String, windowText: String) -> String {
        guard !confirmed.isEmpty else {
            return windowText
        }

        // Simple merge: confirmed text + window text
        // The window should have some overlap with what was confirmed
        // We try to find where the window starts in relation to confirmed text
        let confirmedWords = confirmed.split(separator: " ")
        let windowWords = windowText.split(separator: " ")

        guard !confirmedWords.isEmpty, !windowWords.isEmpty else {
            return confirmed.isEmpty ? windowText : confirmed
        }

        // Look for overlap: check if beginning of window matches end of confirmed
        // This is a simple heuristic - just take the window text for recent content
        return confirmed + " " + windowText
    }

    private func transcribeFinal(_ audioData: [Float]) async {
        let settings = AppSettings.load()

        // For Focus Mode, always use Whisper
        guard let whisperService = whisperService, whisperService.isModelLoaded else {
            NSLog("[FocusModeVM] Whisper not available for final transcription")
            // Keep whatever live transcription we had
            return
        }

        isTranscribing = true
        defer { isTranscribing = false }

        do {
            let shouldRemoveFillers = settings.removeFillerWords
            NSLog("[FocusModeVM] Final transcription of \(audioData.count) samples using Whisper...")

            let result = try await whisperService.transcribe(
                audioData: audioData,
                language: nil,
                removeFillers: shouldRemoveFillers
            )

            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)

            if !text.isEmpty {
                // Use the full final transcription as the authoritative result
                transcribedText = text
                wordCount = text.split(separator: " ").count
            }
            NSLog("[FocusModeVM] Final result (\(wordCount) words): \(text.prefix(100))...")
        } catch {
            // If final transcription fails, keep the live transcription we had
            NSLog("[FocusModeVM] Final transcription error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Preview

#Preview {
    FocusModeView()
        .environmentObject(AppState())
}
