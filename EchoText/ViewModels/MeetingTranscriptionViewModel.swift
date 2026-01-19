import Foundation
import SwiftUI
import Combine
import AppKit

/// ViewModel for the meeting transcription feature
@MainActor
final class MeetingTranscriptionViewModel: ObservableObject {
    // MARK: - Published Properties

    // State
    @Published private(set) var state: MeetingTranscriptionState = .idle
    @Published private(set) var transcribedSegments: [MeetingSegment] = []
    @Published private(set) var liveText: String = ""

    // Audio sources
    @Published private(set) var availableSources: [AudioSource] = []
    @Published var selectedSource: AudioSource?
    @Published private(set) var detectedMeetingApps: [AudioSource] = []

    // Metrics
    @Published private(set) var currentDuration: TimeInterval = 0.0
    @Published private(set) var audioLevel: Float = 0.0
    @Published private(set) var processingChunks: Int = 0
    @Published private(set) var estimatedDelay: TimeInterval = 0.0

    // Error handling
    @Published var showError = false
    @Published var errorMessage: String = ""

    // Last result
    @Published private(set) var lastResult: MeetingTranscriptionResult?

    // MARK: - Computed Properties

    var isModelLoaded: Bool {
        let settings = AppSettings.load()
        switch settings.transcriptionEngine {
        case .whisper:
            return whisperService.isModelLoaded
        case .parakeet:
            return parakeetService?.isModelLoaded ?? false
        }
    }

    var formattedDuration: String {
        let hours = Int(currentDuration) / 3600
        let minutes = (Int(currentDuration) % 3600) / 60
        let seconds = Int(currentDuration) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    var wordCount: Int {
        transcribedSegments.reduce(0) { $0 + $1.text.split(separator: " ").count }
    }

    // MARK: - Dependencies

    private let systemAudioService: SystemAudioService
    private let whisperService: WhisperService
    private let parakeetService: ParakeetService?
    private let diarizationService: SpeakerDiarizationService?
    private let meetingService: MeetingTranscriptionService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(whisperService: WhisperService, parakeetService: ParakeetService? = nil, diarizationService: SpeakerDiarizationService? = nil) {
        self.whisperService = whisperService
        self.parakeetService = parakeetService
        self.diarizationService = diarizationService
        self.systemAudioService = SystemAudioService()
        self.meetingService = MeetingTranscriptionService(
            systemAudioService: systemAudioService,
            whisperService: whisperService,
            parakeetService: parakeetService,
            diarizationService: diarizationService
        )

        setupBindings()
    }

    // MARK: - Public Methods

    /// Refresh available audio sources
    func refreshSources() async {
        do {
            try await systemAudioService.refreshSources()
        } catch {
            // Permission might not be granted yet - that's okay
            print("[MeetingVM] Source refresh failed: \(error)")
        }
    }

    /// Select an audio source
    func selectSource(_ source: AudioSource) {
        selectedSource = source
        systemAudioService.selectedSource = source
    }

    /// Check if source is a detected meeting app
    func isMeetingApp(_ source: AudioSource) -> Bool {
        detectedMeetingApps.contains(source)
    }

    /// Start recording
    func startRecording() async {
        do {
            try await meetingService.startSession()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    /// Stop recording
    func stopRecording() async {
        lastResult = await meetingService.stopSession()

        // Save to history
        if let result = lastResult {
            let transcriptionResult = result.toTranscriptionResult()
            let source = TranscriptionSource.meeting(audioSource: result.audioSource)
            print("[MeetingVM] Saving meeting to history: \(transcriptionResult.text.prefix(100))... source=\(source)")
            TranscriptionHistoryService.shared.save(transcriptionResult, source: source)
            print("[MeetingVM] Meeting saved to history successfully")
        } else {
            print("[MeetingVM] No result to save - lastResult is nil")
        }
    }

    /// Pause recording
    func pauseRecording() {
        meetingService.pauseSession()
    }

    /// Resume recording
    func resumeRecording() {
        meetingService.resumeSession()
    }

    /// Cancel recording
    func cancelRecording() async {
        await meetingService.cancelSession()
    }

    /// Copy transcript to clipboard as clean text
    func copyCleanText() {
        guard let result = createCurrentResult()?.toTranscriptionResult() else { return }
        ExportService.copyCleanText(result)
    }

    /// Copy with timestamps
    func copyWithTimestamps() {
        guard let result = createCurrentResult()?.toTranscriptionResult() else { return }
        ExportService.copyWithTimestamps(result)
    }

    /// Export transcript
    func exportAs(_ format: ExportFormat) {
        guard let result = createCurrentResult()?.toTranscriptionResult() else { return }

        Task {
            _ = await ExportService.exportToFile(result, format: format)
        }
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Bind state
        meetingService.$state
            .receive(on: DispatchQueue.main)
            .assign(to: &$state)

        // Bind segments
        meetingService.$transcribedSegments
            .receive(on: DispatchQueue.main)
            .assign(to: &$transcribedSegments)

        // Bind live text
        meetingService.$liveText
            .receive(on: DispatchQueue.main)
            .assign(to: &$liveText)

        // Bind duration
        meetingService.$currentDuration
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentDuration)

        // Bind processing chunks
        meetingService.$processingChunks
            .receive(on: DispatchQueue.main)
            .assign(to: &$processingChunks)

        // Bind estimated delay
        meetingService.$estimatedDelay
            .receive(on: DispatchQueue.main)
            .assign(to: &$estimatedDelay)

        // Bind audio sources
        systemAudioService.$availableSources
            .receive(on: DispatchQueue.main)
            .assign(to: &$availableSources)

        // Bind selected source
        systemAudioService.$selectedSource
            .receive(on: DispatchQueue.main)
            .assign(to: &$selectedSource)

        // Bind detected meeting apps
        systemAudioService.$detectedMeetingApps
            .receive(on: DispatchQueue.main)
            .assign(to: &$detectedMeetingApps)

        // Bind audio level
        systemAudioService.$audioLevel
            .receive(on: DispatchQueue.main)
            .assign(to: &$audioLevel)
    }

    private func createCurrentResult() -> MeetingTranscriptionResult? {
        guard !transcribedSegments.isEmpty else { return nil }

        // Determine which model was used
        let settings = AppSettings.load()
        let modelUsed: String
        switch settings.transcriptionEngine {
        case .whisper:
            modelUsed = whisperService.loadedModelId ?? "whisper-unknown"
        case .parakeet:
            modelUsed = parakeetService?.loadedModelId ?? "parakeet-unknown"
        }

        return MeetingTranscriptionResult(
            id: UUID(),
            segments: transcribedSegments,
            startTime: Date().addingTimeInterval(-currentDuration),
            endTime: Date(),
            audioSource: selectedSource?.name ?? "Unknown",
            totalDuration: currentDuration,
            modelUsed: modelUsed
        )
    }
}
