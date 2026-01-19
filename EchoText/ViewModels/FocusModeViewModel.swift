import Foundation
import SwiftUI
import Combine

/// ViewModel for Focus Mode
@MainActor
final class FocusModeViewModel: ObservableObject {
    // MARK: - Published Properties

    /// The transcribed text accumulated so far
    @Published var transcribedText: String = ""

    /// Whether currently recording
    @Published var isRecording: Bool = false

    /// Whether currently transcribing a chunk
    @Published var isTranscribing: Bool = false

    /// Recording duration in seconds
    @Published var recordingDuration: TimeInterval = 0.0

    /// Current word count
    @Published var wordCount: Int = 0

    /// Error message if any
    @Published var errorMessage: String?

    /// Whether customization panel is visible
    @Published var isCustomizationVisible: Bool = true

    // MARK: - Services

    private let audioService: AudioRecordingService
    private let whisperService: WhisperService
    private var streamingTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Private Properties

    private var recordingStartTime: Date?
    private var durationTimer: Timer?
    private var audioBuffer: [Float] = []
    private let chunkSizeInSamples = 32000 // 2 seconds at 16kHz

    // MARK: - Initialization

    init(audioService: AudioRecordingService, whisperService: WhisperService) {
        self.audioService = audioService
        self.whisperService = whisperService
        setupBindings()
    }

    // MARK: - Public Methods

    /// Start recording and streaming transcription
    func startRecording() async {
        guard !isRecording else { return }

        // Reset state
        transcribedText = ""
        wordCount = 0
        errorMessage = nil
        audioBuffer = []

        do {
            _ = try await audioService.startRecording()
            isRecording = true
            recordingStartTime = Date()
            startDurationTimer()

            // Start the streaming transcription task
            startStreamingTranscription()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Stop recording and finalize transcription
    func stopRecording() async {
        guard isRecording else { return }

        isRecording = false
        stopDurationTimer()
        streamingTask?.cancel()
        streamingTask = nil

        // Stop audio recording
        _ = audioService.stopRecording()

        // Get any remaining audio and transcribe it
        if let remainingAudio = audioService.getRecordedAudioData(), !remainingAudio.isEmpty {
            // Transcribe the final full audio for accuracy
            await transcribeFinalAudio(remainingAudio)
        }

        audioService.clearRecordingBuffer()
    }

    /// Cancel recording without saving
    func cancelRecording() {
        isRecording = false
        stopDurationTimer()
        streamingTask?.cancel()
        streamingTask = nil
        audioService.cancelRecording()
    }

    /// Toggle recording state
    func toggleRecording() async {
        if isRecording {
            await stopRecording()
        } else {
            await startRecording()
        }
    }

    /// Copy transcription to clipboard
    func copyToClipboard() {
        guard !transcribedText.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(transcribedText, forType: .string)
    }

    /// Reset the view model state
    func reset() {
        transcribedText = ""
        wordCount = 0
        recordingDuration = 0
        errorMessage = nil
        isRecording = false
        isTranscribing = false
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Update word count when text changes
        $transcribedText
            .map { text in
                text.split(separator: " ").count
            }
            .assign(to: &$wordCount)
    }

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
        streamingTask = Task {
            // Poll for audio chunks periodically
            while isRecording && !Task.isCancelled {
                // Wait for a chunk interval
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

                guard isRecording && !Task.isCancelled else { break }

                // Get current audio data
                if let audioData = audioService.getRecordedAudioData(), audioData.count > audioBuffer.count {
                    // Get new samples since last transcription
                    let newSamples = Array(audioData.suffix(from: audioBuffer.count))
                    audioBuffer = audioData

                    // If we have enough new data, transcribe
                    if newSamples.count >= chunkSizeInSamples / 2 {
                        await transcribeChunk(audioData)
                    }
                }
            }
        }
    }

    private func transcribeChunk(_ audioData: [Float]) async {
        guard whisperService.isModelLoaded else {
            errorMessage = "Model not loaded"
            return
        }

        isTranscribing = true
        defer { isTranscribing = false }

        do {
            let shouldRemoveFillers = AppSettings.load().removeFillerWords
            let result = try await whisperService.transcribe(audioData: audioData, language: nil, removeFillers: shouldRemoveFillers)
            let newText = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !newText.isEmpty {
                transcribedText = newText
            }
        } catch {
            // Don't show errors for streaming chunks - they may be too short
            NSLog("[FocusModeViewModel] Chunk transcription error: \(error.localizedDescription)")
        }
    }

    private func transcribeFinalAudio(_ audioData: [Float]) async {
        guard whisperService.isModelLoaded else {
            errorMessage = "Model not loaded"
            return
        }

        isTranscribing = true
        defer { isTranscribing = false }

        do {
            let shouldRemoveFillers = AppSettings.load().removeFillerWords
            let result = try await whisperService.transcribe(audioData: audioData, language: nil, removeFillers: shouldRemoveFillers)
            let finalText = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !finalText.isEmpty {
                transcribedText = finalText
            }
        } catch {
            errorMessage = "Transcription failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Formatted Duration

    var formattedDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
