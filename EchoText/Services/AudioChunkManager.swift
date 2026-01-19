import Foundation
import Combine

/// Represents an audio chunk ready for transcription
struct AudioChunk: Identifiable {
    let id: UUID
    let samples: [Float]
    let startTime: TimeInterval
    let endTime: TimeInterval
    let isComplete: Bool  // False if chunk was force-split mid-speech

    var duration: TimeInterval {
        endTime - startTime
    }

    var sampleCount: Int {
        samples.count
    }
}

/// Configuration for chunk management
struct ChunkConfiguration {
    /// Minimum chunk duration in seconds
    var minChunkDuration: TimeInterval = 5.0

    /// Maximum chunk duration before force-split
    var maxChunkDuration: TimeInterval = 30.0

    /// Silence duration (seconds) to trigger chunk boundary
    var silenceThreshold: TimeInterval = 1.5

    /// Energy threshold for voice activity (0.0-1.0)
    var energyThreshold: Float = 0.01

    /// Overlap between chunks in seconds
    var overlapDuration: TimeInterval = 1.0

    /// Sample rate (must match Whisper input requirement)
    let sampleRate: Double = 16000.0

    static let `default` = ChunkConfiguration()

    static let aggressive = ChunkConfiguration(
        minChunkDuration: 3.0,
        maxChunkDuration: 20.0,
        silenceThreshold: 1.0,
        energyThreshold: 0.02
    )

    static let conservative = ChunkConfiguration(
        minChunkDuration: 10.0,
        maxChunkDuration: 45.0,
        silenceThreshold: 2.0,
        energyThreshold: 0.005
    )

    /// Optimized for fast models like Parakeet (190x realtime)
    /// Uses very small chunks for near-instant transcription
    static let realtime = ChunkConfiguration(
        minChunkDuration: 1.5,
        maxChunkDuration: 5.0,
        silenceThreshold: 0.5,
        energyThreshold: 0.015,
        overlapDuration: 0.3
    )
}

/// Manages audio chunking with voice activity detection for optimal transcription boundaries
@MainActor
final class AudioChunkManager: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var currentChunkDuration: TimeInterval = 0.0
    @Published private(set) var isSpeechActive = false
    @Published private(set) var silenceDuration: TimeInterval = 0.0
    @Published private(set) var pendingChunksCount: Int = 0

    // MARK: - Configuration
    var configuration: ChunkConfiguration

    // MARK: - Callbacks
    /// Called when a chunk is ready for transcription
    var onChunkReady: ((AudioChunk) -> Void)?

    // MARK: - Private Properties
    private var audioBuffer: [Float] = []
    private var bufferStartTime: TimeInterval = 0.0
    private var lastSpeechTime: Date = Date()
    private var isMonitoring = false
    private var pendingChunks: [AudioChunk] = []

    // Sliding window for energy calculation
    private let energyWindowSize = 1600  // 100ms at 16kHz
    private var energyWindow: [Float] = []

    // MARK: - Initialization

    init(configuration: ChunkConfiguration = .default) {
        self.configuration = configuration
    }

    // MARK: - Public Methods

    /// Start monitoring audio for chunk boundaries
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        audioBuffer = []
        bufferStartTime = 0.0
        lastSpeechTime = Date()
        silenceDuration = 0.0
        pendingChunks = []
    }

    /// Stop monitoring and flush any remaining audio as a final chunk
    func stopMonitoring() -> AudioChunk? {
        guard isMonitoring else { return nil }
        isMonitoring = false

        // Create final chunk from remaining buffer
        let finalChunk = flushBuffer(isComplete: true)
        pendingChunks = []
        pendingChunksCount = 0

        return finalChunk
    }

    /// Process incoming audio samples
    /// - Parameters:
    ///   - samples: Audio samples (16kHz mono Float32)
    ///   - timestamp: Start timestamp of these samples
    func processAudioSamples(_ samples: [Float], timestamp: TimeInterval) {
        guard isMonitoring else { return }

        // Set buffer start time if this is the first samples
        if audioBuffer.isEmpty {
            bufferStartTime = timestamp
        }

        // Append to buffer
        audioBuffer.append(contentsOf: samples)

        // Update energy window for VAD
        energyWindow.append(contentsOf: samples)
        if energyWindow.count > energyWindowSize {
            energyWindow.removeFirst(energyWindow.count - energyWindowSize)
        }

        // Calculate current energy level
        let currentEnergy = computeRMSLevel(from: energyWindow)

        // Update speech detection state
        if currentEnergy > configuration.energyThreshold {
            isSpeechActive = true
            lastSpeechTime = Date()
            silenceDuration = 0.0
        } else {
            isSpeechActive = false
            silenceDuration = Date().timeIntervalSince(lastSpeechTime)
        }

        // Calculate current buffer duration
        currentChunkDuration = Double(audioBuffer.count) / configuration.sampleRate

        // Check if we should create a chunk
        checkChunkBoundary()
    }

    /// Force flush the current buffer as a chunk
    func forceFlush() -> AudioChunk? {
        return flushBuffer(isComplete: false)
    }

    /// Get all pending chunks that haven't been processed yet
    func getPendingChunks() -> [AudioChunk] {
        let chunks = pendingChunks
        pendingChunks = []
        pendingChunksCount = 0
        return chunks
    }

    // MARK: - Private Methods

    private func checkChunkBoundary() {
        let bufferDuration = Double(audioBuffer.count) / configuration.sampleRate

        // Force split if we exceed max duration
        if bufferDuration >= configuration.maxChunkDuration {
            if let chunk = flushBuffer(isComplete: false) {
                emitChunk(chunk)
            }
            return
        }

        // Check for natural boundary (silence after speech)
        if bufferDuration >= configuration.minChunkDuration &&
           !isSpeechActive &&
           silenceDuration >= configuration.silenceThreshold {
            if let chunk = flushBuffer(isComplete: true) {
                emitChunk(chunk)
            }
        }
    }

    private func flushBuffer(isComplete: Bool) -> AudioChunk? {
        guard !audioBuffer.isEmpty else { return nil }

        let endTime = bufferStartTime + Double(audioBuffer.count) / configuration.sampleRate

        // Calculate overlap samples
        let overlapSamples = Int(configuration.overlapDuration * configuration.sampleRate)

        // Create chunk
        let chunk = AudioChunk(
            id: UUID(),
            samples: audioBuffer,
            startTime: bufferStartTime,
            endTime: endTime,
            isComplete: isComplete
        )

        // Keep overlap for next chunk
        if audioBuffer.count > overlapSamples && isMonitoring {
            let overlapStart = audioBuffer.count - overlapSamples
            audioBuffer = Array(audioBuffer.suffix(from: overlapStart))
            bufferStartTime = endTime - configuration.overlapDuration
        } else {
            audioBuffer = []
            bufferStartTime = endTime
        }

        currentChunkDuration = Double(audioBuffer.count) / configuration.sampleRate

        return chunk
    }

    private func emitChunk(_ chunk: AudioChunk) {
        pendingChunks.append(chunk)
        pendingChunksCount = pendingChunks.count
        onChunkReady?(chunk)
    }

    /// Compute RMS level from audio samples
    private func computeRMSLevel(from samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0.0 }

        var sum: Float = 0.0
        for sample in samples {
            sum += sample * sample
        }

        return sqrt(sum / Float(samples.count))
    }
}

// MARK: - Convenience Methods

extension AudioChunkManager {
    /// Reset the manager to initial state
    func reset() {
        audioBuffer = []
        bufferStartTime = 0.0
        currentChunkDuration = 0.0
        silenceDuration = 0.0
        isSpeechActive = false
        pendingChunks = []
        pendingChunksCount = 0
        energyWindow = []
        isMonitoring = false
    }

    /// Get statistics about chunk management
    var statistics: ChunkStatistics {
        ChunkStatistics(
            currentBufferDuration: currentChunkDuration,
            currentBufferSamples: audioBuffer.count,
            pendingChunks: pendingChunksCount,
            isSpeechActive: isSpeechActive,
            silenceDuration: silenceDuration
        )
    }
}

/// Statistics about the chunk manager state
struct ChunkStatistics {
    let currentBufferDuration: TimeInterval
    let currentBufferSamples: Int
    let pendingChunks: Int
    let isSpeechActive: Bool
    let silenceDuration: TimeInterval
}
