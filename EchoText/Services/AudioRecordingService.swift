import Foundation
import AVFoundation
import Combine

/// Error types for audio recording operations
enum AudioRecordingError: LocalizedError {
    case microphoneAccessDenied
    case engineConfigurationFailed
    case recordingFailed(Error)
    case noAudioData

    var errorDescription: String? {
        switch self {
        case .microphoneAccessDenied:
            return "Microphone access was denied. Please enable it in System Preferences."
        case .engineConfigurationFailed:
            return "Failed to configure the audio engine."
        case .recordingFailed(let error):
            return "Recording failed: \(error.localizedDescription)"
        case .noAudioData:
            return "No audio data was recorded."
        }
    }
}

/// Service responsible for audio recording using AVAudioEngine
@MainActor
final class AudioRecordingService: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var isRecording = false
    @Published private(set) var audioLevel: Float = 0.0
    @Published private(set) var recordingDuration: TimeInterval = 0.0

    // MARK: - Private Properties
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var recordingBuffer: [Float] = []
    private var recordingStartTime: Date?
    private var durationTimer: Timer?

    // Audio format for Whisper (16kHz, mono, Float32)
    private let sampleRate: Double = 16000.0
    private let channelCount: AVAudioChannelCount = 1

    private var temporaryFileURL: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("echotext_recording_\(UUID().uuidString)")
            .appendingPathExtension("wav")
    }

    // MARK: - Initialization
    init() {
        setupAudioSession()
    }

    deinit {
        // Clean up audio engine directly without calling MainActor method
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        durationTimer?.invalidate()
    }

    // MARK: - Public Methods

    /// Start recording audio from the microphone
    func startRecording() async throws -> URL {
        guard !isRecording else {
            throw AudioRecordingError.recordingFailed(NSError(domain: "AudioRecording", code: -1, userInfo: [NSLocalizedDescriptionKey: "Already recording"]))
        }

        // Request microphone permission
        let hasPermission = await requestMicrophonePermission()
        guard hasPermission else {
            throw AudioRecordingError.microphoneAccessDenied
        }

        // Setup and start recording
        let fileURL = temporaryFileURL
        try await setupAudioEngine(outputURL: fileURL)
        try startAudioEngine()

        recordingStartTime = Date()
        isRecording = true
        startDurationTimer()

        return fileURL
    }

    /// Stop recording and return the audio file URL
    func stopRecording() -> URL? {
        guard isRecording else { return nil }

        stopDurationTimer()
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)

        // Get file URL before closing
        let fileURL = audioFile?.url

        // Close the audio file properly by setting it to nil
        // This flushes any remaining data to disk
        audioFile = nil

        // Small delay to ensure file is flushed
        Thread.sleep(forTimeInterval: 0.1)

        audioEngine = nil

        isRecording = false
        audioLevel = 0.0
        recordingDuration = 0.0
        recordingStartTime = nil

        // Note: recordingBuffer is intentionally NOT cleared here
        // so it can be accessed via getRecordedAudioData() after stopping

        return fileURL
    }

    /// Clear the recorded audio buffer (call after transcription is complete)
    func clearRecordingBuffer() {
        recordingBuffer = []
    }

    /// Cancel recording and delete the temporary file
    func cancelRecording() {
        if let url = stopRecording() {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Get the recorded audio as Float array (for direct WhisperKit input)
    func getRecordedAudioData() -> [Float]? {
        guard !recordingBuffer.isEmpty else { return nil }
        return recordingBuffer
    }

    // MARK: - Private Methods

    private func setupAudioSession() {
        // macOS doesn't require AVAudioSession setup like iOS
    }

    private func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func setupAudioEngine(outputURL: URL) async throws {
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw AudioRecordingError.engineConfigurationFailed
        }

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Create output format for Whisper (16kHz mono)
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channelCount,
            interleaved: false
        ) else {
            throw AudioRecordingError.engineConfigurationFailed
        }

        // Create audio file for recording
        do {
            audioFile = try AVAudioFile(
                forWriting: outputURL,
                settings: outputFormat.settings,
                commonFormat: .pcmFormatFloat32,
                interleaved: false
            )
        } catch {
            throw AudioRecordingError.recordingFailed(error)
        }

        // Create converter for sample rate conversion if needed
        let converter = AVAudioConverter(from: inputFormat, to: outputFormat)

        // Clear buffer
        recordingBuffer = []

        // Install tap on input node
        let bufferSize: AVAudioFrameCount = 1024
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer, converter: converter, outputFormat: outputFormat)
        }
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter?, outputFormat: AVAudioFormat) {
        // Calculate audio level for visualization
        if let channelData = buffer.floatChannelData?[0] {
            let frameLength = Int(buffer.frameLength)
            var sum: Float = 0.0
            for i in 0..<frameLength {
                sum += abs(channelData[i])
            }
            let averageLevel = sum / Float(frameLength)

            Task { @MainActor in
                self.audioLevel = min(averageLevel * 10, 1.0) // Scale for visualization
            }
        }

        // Convert and write to file
        guard let converter = converter else {
            // No conversion needed, write directly
            writeBuffer(buffer)
            return
        }

        // Convert sample rate if needed
        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputFrameCapacity) else {
            return
        }

        var error: NSError?
        let status = converter.convert(to: outputBuffer, error: &error) { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        if status == .haveData {
            writeBuffer(outputBuffer)
        }
    }

    private func writeBuffer(_ buffer: AVAudioPCMBuffer) {
        // Write to file
        do {
            try audioFile?.write(from: buffer)
        } catch {
            print("Error writing audio buffer: \(error)")
        }

        // Also store in memory buffer for direct access
        if let channelData = buffer.floatChannelData?[0] {
            let frameLength = Int(buffer.frameLength)
            for i in 0..<frameLength {
                recordingBuffer.append(channelData[i])
            }
        }
    }

    private func startAudioEngine() throws {
        guard let audioEngine = audioEngine else {
            throw AudioRecordingError.engineConfigurationFailed
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
            throw AudioRecordingError.recordingFailed(error)
        }
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
}

// MARK: - Audio Level Analysis Extension
extension AudioRecordingService {
    /// Compute the RMS (root mean square) level of audio data
    static func computeRMSLevel(from samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0.0 }

        var sum: Float = 0.0
        for sample in samples {
            sum += sample * sample
        }

        return sqrt(sum / Float(samples.count))
    }

    /// Compute decibel level from RMS
    static func computeDecibelLevel(from rms: Float) -> Float {
        guard rms > 0 else { return -160.0 }
        return 20.0 * log10(rms)
    }
}
