import Foundation
import Combine

/// Represents the state of a meeting transcription session
enum MeetingTranscriptionState: Equatable {
    case idle
    case starting
    case recording
    case processing
    case paused
    case stopping
    case error(String)

    static func == (lhs: MeetingTranscriptionState, rhs: MeetingTranscriptionState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.starting, .starting), (.recording, .recording),
             (.processing, .processing), (.paused, .paused), (.stopping, .stopping):
            return true
        case (.error(let l), .error(let r)):
            return l == r
        default:
            return false
        }
    }
}

/// Represents a transcribed segment from a meeting
struct MeetingSegment: Identifiable {
    let id: UUID
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let chunkId: UUID
    let confidence: Float?
    let speakerId: String?

    var duration: TimeInterval {
        endTime - startTime
    }

    var formattedTimeRange: String {
        let start = formatTime(startTime)
        let end = formatTime(endTime)
        return "\(start) - \(end)"
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// Complete meeting transcription result
struct MeetingTranscriptionResult: Identifiable {
    let id: UUID
    let segments: [MeetingSegment]
    let startTime: Date
    let endTime: Date
    let audioSource: String
    let totalDuration: TimeInterval
    let modelUsed: String

    var fullText: String {
        segments.map { $0.text }.joined(separator: " ")
    }

    var wordCount: Int {
        fullText.split(separator: " ").count
    }

    /// Convert to basic TranscriptionResult for export
    func toTranscriptionResult() -> TranscriptionResult {
        let transcriptionSegments = segments.map { segment in
            TranscriptionSegment(
                id: Int(segment.id.hashValue), // Simple hash for ID
                text: segment.text,
                startTime: segment.startTime,
                endTime: segment.endTime,
                speakerId: segment.speakerId
            )
        }

        return TranscriptionResult(
            id: id,
            text: segments.map { $0.text }.joined(separator: " "),
            segments: transcriptionSegments,
            language: nil, // Unknown for meeting
            duration: totalDuration,
            processingTime: 0,
            modelUsed: modelUsed,
            timestamp: startTime,
            speakerMapping: nil // Could be added if needed
        )
    }
}

/// Service that orchestrates meeting transcription with chunked processing
@MainActor
final class MeetingTranscriptionService: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var state: MeetingTranscriptionState = .idle
    @Published private(set) var transcribedSegments: [MeetingSegment] = []
    @Published private(set) var liveText: String = ""
    @Published private(set) var currentDuration: TimeInterval = 0.0
    @Published private(set) var processingChunks: Int = 0
    @Published private(set) var estimatedDelay: TimeInterval = 0.0

    // MARK: - Dependencies
    private let systemAudioService: SystemAudioService
    private let whisperService: WhisperService
    private let parakeetService: ParakeetService?
    private let diarizationService: SpeakerDiarizationService?
    private let chunkManager: AudioChunkManager

    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var transcriptionTasks: [UUID: Task<Void, Never>] = [:]
    private var sessionStartTime: Date?
    private var lastChunkEndTime: TimeInterval = 0.0

    // Queue for managing chunk transcription order
    private var pendingResults: [UUID: TranscriptionResult] = [:]
    private var expectedChunkOrder: [UUID] = []

    // Configuration
    private var selectedLanguage: String?

    // Speaker diarization
    private var collectedAudioSamples: [Float] = []

    // MARK: - Initialization

    init(systemAudioService: SystemAudioService, whisperService: WhisperService, parakeetService: ParakeetService? = nil, diarizationService: SpeakerDiarizationService? = nil) {
        self.systemAudioService = systemAudioService
        self.whisperService = whisperService
        self.parakeetService = parakeetService
        self.diarizationService = diarizationService
        self.chunkManager = AudioChunkManager(configuration: .default)

        setupBindings()
    }

    // MARK: - Public Methods

    /// Start a meeting transcription session
    func startSession(language: String? = nil) async throws {
        guard state == .idle else { return }

        state = .starting
        selectedLanguage = language
        transcribedSegments = []
        liveText = ""
        lastChunkEndTime = 0.0
        pendingResults = [:]
        expectedChunkOrder = []
        collectedAudioSamples = []

        // Ensure audio source is selected
        guard systemAudioService.selectedSource != nil else {
            state = .error("No audio source selected")
            throw SystemAudioError.noSourceSelected
        }

        // Check the appropriate model is loaded based on engine selection
        let settings = AppSettings.load()
        switch settings.transcriptionEngine {
        case .whisper:
            guard whisperService.isModelLoaded else {
                state = .error("Whisper model not loaded")
                throw WhisperServiceError.modelNotLoaded
            }
        case .parakeet:
            guard let parakeet = parakeetService, parakeet.isModelLoaded else {
                state = .error("Parakeet model not loaded")
                throw WhisperServiceError.modelNotLoaded
            }
        }

        do {
            // Configure chunk manager based on selected engine
            // Parakeet is 190x realtime, so we use much smaller chunks for instant results
            let isParakeet = settings.transcriptionEngine == .parakeet
            print("[MeetingTranscription] Engine from settings: \(settings.transcriptionEngine), isParakeet: \(isParakeet)")
            chunkManager.configuration = isParakeet ? .realtime : .default
            print("[MeetingTranscription] Chunk config set: min=\(chunkManager.configuration.minChunkDuration), max=\(chunkManager.configuration.maxChunkDuration)")

            // Start chunk manager
            chunkManager.startMonitoring()

            // Setup chunk callback
            chunkManager.onChunkReady = { [weak self] chunk in
                Task { @MainActor in
                    await self?.handleChunk(chunk)
                }
            }

            // Start system audio capture
            try await systemAudioService.startCapture()

            sessionStartTime = Date()
            state = .recording

            print("[MeetingTranscription] Started with \(settings.transcriptionEngine) engine, chunk config: min=\(chunkManager.configuration.minChunkDuration)s, max=\(chunkManager.configuration.maxChunkDuration)s")
        } catch {
            state = .error(error.localizedDescription)
            throw error
        }
    }

    /// Stop the meeting transcription session
    func stopSession() async -> MeetingTranscriptionResult? {
        guard state == .recording || state == .paused else { return nil }

        state = .stopping

        // Stop audio capture
        let remainingAudio = await systemAudioService.stopCapture()

        // Process any remaining audio in chunk manager
        if let finalChunk = chunkManager.stopMonitoring() {
            await handleChunk(finalChunk)
        }

        // Wait for all pending transcriptions to complete
        for (_, task) in transcriptionTasks {
            await task.value
        }

        // Process ordered results
        processOrderedResults()

        // Run speaker diarization on collected audio if enabled in settings
        let enableDiarization = AppSettings.load().enableSpeakerDiarization
        if enableDiarization, let diarization = diarizationService, !collectedAudioSamples.isEmpty {
            await runSpeakerDiarization(with: diarization)
        }

        state = .idle

        // Create final result
        guard let startTime = sessionStartTime else { return nil }
        let endTime = Date()

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
            startTime: startTime,
            endTime: endTime,
            audioSource: systemAudioService.selectedSource?.name ?? "Unknown",
            totalDuration: endTime.timeIntervalSince(startTime),
            modelUsed: modelUsed
        )
    }

    /// Run speaker diarization on collected audio and assign speaker IDs to segments
    private func runSpeakerDiarization(with diarization: SpeakerDiarizationService) async {
        // Save collected audio to temp file for diarization
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("meeting_audio_\(UUID().uuidString).wav")

        do {
            // Write audio samples to WAV file
            try await writeAudioToWAV(samples: collectedAudioSamples, url: tempURL)

            // Run diarization
            let diarizationSegments = try await diarization.diarize(audioURL: tempURL)

            // Align diarization results with transcription segments
            transcribedSegments = transcribedSegments.map { segment in
                let speakerId = findSpeakerForTimeRange(
                    startTime: segment.startTime,
                    endTime: segment.endTime,
                    diarizationSegments: diarizationSegments
                )
                return MeetingSegment(
                    id: segment.id,
                    text: segment.text,
                    startTime: segment.startTime,
                    endTime: segment.endTime,
                    chunkId: segment.chunkId,
                    confidence: segment.confidence,
                    speakerId: speakerId
                )
            }

            // Clean up temp file
            try? FileManager.default.removeItem(at: tempURL)

        } catch {
            print("[MeetingTranscription] Speaker diarization failed: \(error)")
            // Continue without diarization - segments will have nil speakerId
        }
    }

    /// Find the speaker for a given time range
    private func findSpeakerForTimeRange(startTime: TimeInterval, endTime: TimeInterval, diarizationSegments: [DiarizationSegment]) -> String? {
        var bestOverlap: TimeInterval = 0
        var bestSpeaker: String?

        for diarization in diarizationSegments {
            let overlapStart = max(startTime, diarization.startTime)
            let overlapEnd = min(endTime, diarization.endTime)
            let overlap = max(0, overlapEnd - overlapStart)

            if overlap > bestOverlap {
                bestOverlap = overlap
                bestSpeaker = diarization.speakerId
            }
        }

        return bestSpeaker
    }

    /// Write audio samples to a WAV file
    private func writeAudioToWAV(samples: [Float], url: URL) async throws {
        let sampleRate: Double = 16000
        let channels: UInt32 = 1
        let bitsPerSample: UInt32 = 16

        var fileData = Data()

        // WAV header
        fileData.append("RIFF".data(using: .ascii)!)
        let dataSize = UInt32(samples.count * 2) // 16-bit samples
        let fileSize = dataSize + 36
        withUnsafeBytes(of: fileSize.littleEndian) { fileData.append(contentsOf: $0) }
        fileData.append("WAVE".data(using: .ascii)!)

        // fmt chunk
        fileData.append("fmt ".data(using: .ascii)!)
        withUnsafeBytes(of: UInt32(16).littleEndian) { fileData.append(contentsOf: $0) } // chunk size
        withUnsafeBytes(of: UInt16(1).littleEndian) { fileData.append(contentsOf: $0) } // PCM format
        withUnsafeBytes(of: UInt16(channels).littleEndian) { fileData.append(contentsOf: $0) }
        withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { fileData.append(contentsOf: $0) }
        let byteRate = UInt32(sampleRate) * channels * bitsPerSample / 8
        withUnsafeBytes(of: byteRate.littleEndian) { fileData.append(contentsOf: $0) }
        let blockAlign = UInt16(channels * bitsPerSample / 8)
        withUnsafeBytes(of: blockAlign.littleEndian) { fileData.append(contentsOf: $0) }
        withUnsafeBytes(of: UInt16(bitsPerSample).littleEndian) { fileData.append(contentsOf: $0) }

        // data chunk
        fileData.append("data".data(using: .ascii)!)
        withUnsafeBytes(of: dataSize.littleEndian) { fileData.append(contentsOf: $0) }

        // Convert float samples to 16-bit PCM
        for sample in samples {
            let clampedSample = max(-1.0, min(1.0, sample))
            let pcmSample = Int16(clampedSample * 32767.0)
            withUnsafeBytes(of: pcmSample.littleEndian) { fileData.append(contentsOf: $0) }
        }

        try fileData.write(to: url)
    }

    /// Pause the transcription session (keeps audio capture running but pauses transcription)
    func pauseSession() {
        guard state == .recording else { return }
        state = .paused
        systemAudioService.pauseTimer()
    }

    /// Resume a paused session
    func resumeSession() {
        guard state == .paused else { return }
        state = .recording
        systemAudioService.resumeTimer()
    }

    /// Cancel the session without saving
    func cancelSession() async {
        state = .stopping

        _ = await systemAudioService.stopCapture()
        _ = chunkManager.stopMonitoring()

        // Cancel all pending transcription tasks
        for (_, task) in transcriptionTasks {
            task.cancel()
        }
        transcriptionTasks = [:]

        transcribedSegments = []
        liveText = ""
        pendingResults = [:]
        expectedChunkOrder = []
        state = .idle
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Bind audio samples from system audio to chunk manager
        systemAudioService.onAudioChunk = { [weak self] samples, timestamp in
            Task { @MainActor in
                self?.chunkManager.processAudioSamples(samples, timestamp: timestamp)
                // Collect samples for speaker diarization (always collect, check setting at end)
                self?.collectedAudioSamples.append(contentsOf: samples)
            }
        }

        // Bind duration
        systemAudioService.$capturedDuration
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentDuration)

        // Update estimated delay based on processing queue
        $processingChunks
            .map { Double($0) * 15.0 }  // Rough estimate: 15 seconds per chunk
            .assign(to: &$estimatedDelay)
    }

    private func handleChunk(_ chunk: AudioChunk) async {
        guard state == .recording else { return }

        processingChunks += 1
        expectedChunkOrder.append(chunk.id)

        // Start transcription task for this chunk
        let task = Task { @MainActor in
            await transcribeChunk(chunk)
        }

        transcriptionTasks[chunk.id] = task
    }

    private func transcribeChunk(_ chunk: AudioChunk) async {
        do {
            let settings = AppSettings.load()
            let shouldRemoveFillers = settings.removeFillerWords
            let result: TranscriptionResult

            // Use the selected transcription engine
            switch settings.transcriptionEngine {
            case .whisper:
                result = try await whisperService.transcribe(
                    audioData: chunk.samples,
                    language: selectedLanguage,
                    removeFillers: shouldRemoveFillers
                )
            case .parakeet:
                guard let parakeet = parakeetService else {
                    throw WhisperServiceError.modelNotLoaded
                }
                result = try await parakeet.transcribe(
                    audioData: chunk.samples,
                    removeFillers: shouldRemoveFillers
                )
            }

            // Store result for ordered processing
            pendingResults[chunk.id] = result

            // Update live text immediately for responsiveness
            if !result.text.isEmpty {
                liveText += " " + result.text
                liveText = liveText.trimmingCharacters(in: .whitespaces)
            }

            // Process results in order
            processOrderedResults()

        } catch {
            print("[MeetingTranscription] Chunk transcription failed: \(error)")
        }

        processingChunks -= 1
        transcriptionTasks.removeValue(forKey: chunk.id)
    }

    private func processOrderedResults() {
        // Process results in the order chunks were received
        while let nextChunkId = expectedChunkOrder.first,
              let result = pendingResults[nextChunkId] {

            expectedChunkOrder.removeFirst()
            pendingResults.removeValue(forKey: nextChunkId)

            // Convert result segments to meeting segments
            for segment in result.segments {
                let meetingSegment = MeetingSegment(
                    id: UUID(),
                    text: segment.text.trimmingCharacters(in: .whitespaces),
                    startTime: lastChunkEndTime + segment.startTime,
                    endTime: lastChunkEndTime + segment.endTime,
                    chunkId: nextChunkId,
                    confidence: nil,
                    speakerId: segment.speakerId
                )

                if !meetingSegment.text.isEmpty {
                    transcribedSegments.append(meetingSegment)
                }
            }

            lastChunkEndTime += result.duration
        }
    }
}

// MARK: - Export Support

extension MeetingTranscriptionResult {
    /// Export as plain text
    func exportAsText() -> String {
        var output = "Meeting Transcription\n"
        output += "Date: \(startTime.formatted())\n"
        output += "Duration: \(formatDuration(totalDuration))\n"
        output += "Source: \(audioSource)\n"
        output += "---\n\n"

        for segment in segments {
            let timestamp = segment.formattedTimeRange
            if let speaker = segment.speakerId {
                output += "[\(timestamp)] \(speaker): \(segment.text)\n"
            } else {
                output += "[\(timestamp)] \(segment.text)\n"
            }
        }

        return output
    }

    /// Export as SRT subtitle format
    func exportAsSRT() -> String {
        var output = ""
        for (index, segment) in segments.enumerated() {
            output += "\(index + 1)\n"
            output += "\(formatSRTTime(segment.startTime)) --> \(formatSRTTime(segment.endTime))\n"
            output += "\(segment.text)\n\n"
        }
        return output
    }

    /// Export as VTT subtitle format
    func exportAsVTT() -> String {
        var output = "WEBVTT\n\n"
        for segment in segments {
            output += "\(formatVTTTime(segment.startTime)) --> \(formatVTTTime(segment.endTime))\n"
            output += "\(segment.text)\n\n"
        }
        return output
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func formatSRTTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, seconds, milliseconds)
    }

    private func formatVTTTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d:%02d.%03d", hours, minutes, seconds, milliseconds)
    }
}
