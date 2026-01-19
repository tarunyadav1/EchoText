import Foundation
import AVFoundation
import Combine

#if canImport(FluidAudio)
import FluidAudio
#endif

/// Error types for Parakeet transcription operations
enum ParakeetServiceError: LocalizedError {
    case modelNotLoaded
    case modelLoadFailed(Error)
    case transcriptionFailed(Error)
    case invalidAudioFile
    case audioLoadFailed(Error)
    case fluidAudioNotAvailable
    case englishOnlyModel

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Parakeet model is not loaded. Please download a model first."
        case .modelLoadFailed(let error):
            return "Failed to load Parakeet model: \(error.localizedDescription)"
        case .transcriptionFailed(let error):
            return "Transcription failed: \(error.localizedDescription)"
        case .invalidAudioFile:
            return "The audio file is invalid or unsupported."
        case .audioLoadFailed(let error):
            return "Failed to load audio file: \(error.localizedDescription)"
        case .fluidAudioNotAvailable:
            return "FluidAudio framework is not available. Please ensure the package is properly installed."
        case .englishOnlyModel:
            return "Parakeet currently only supports English transcription. Please switch to Whisper for other languages."
        }
    }
}

/// Service responsible for Parakeet-based speech-to-text transcription using FluidAudio
@MainActor
final class ParakeetService: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var isModelLoaded = false
    @Published private(set) var isTranscribing = false
    @Published private(set) var loadedModelId: String?
    @Published private(set) var transcriptionProgress: Double = 0.0
    @Published private(set) var isDownloading = false
    @Published private(set) var downloadProgress: Double = 0.0

    // MARK: - Private Properties
    #if canImport(FluidAudio)
    private var asrManager: AsrManager?
    #endif
    private var currentTask: Task<TranscriptionResult, Error>?

    // Model storage location
    private var modelsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("EchoText/ParakeetModels", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Initialization
    init() {}

    // MARK: - Model Loading

    /// Load a Parakeet model by ID
    func loadModel(_ modelId: String) async throws {
        #if canImport(FluidAudio)
        // Unload existing model first
        unloadModel()

        do {
            isDownloading = true
            downloadProgress = 0.0

            // Determine version from model ID
            let version: AsrModelVersion = modelId.contains("v3") ? .v3 : .v2

            // Download and load models using FluidAudio
            let models = try await AsrModels.downloadAndLoad(version: version)

            isDownloading = false
            downloadProgress = 0.8

            // Initialize ASR manager
            asrManager = AsrManager()
            try await asrManager?.initialize(models: models)

            downloadProgress = 1.0
            isModelLoaded = true
            loadedModelId = modelId
        } catch {
            isModelLoaded = false
            loadedModelId = nil
            isDownloading = false
            throw ParakeetServiceError.modelLoadFailed(error)
        }
        #else
        throw ParakeetServiceError.fluidAudioNotAvailable
        #endif
    }

    /// Unload the current model to free memory
    func unloadModel() {
        #if canImport(FluidAudio)
        asrManager = nil
        #endif
        isModelLoaded = false
        loadedModelId = nil
    }

    // MARK: - Transcription

    /// Transcribe audio from a file URL
    func transcribe(
        audioURL: URL,
        removeFillers: Bool = false
    ) async throws -> TranscriptionResult {
        #if canImport(FluidAudio)
        guard let asrManager = asrManager, isModelLoaded else {
            throw ParakeetServiceError.modelNotLoaded
        }

        isTranscribing = true
        transcriptionProgress = 0.0

        defer {
            isTranscribing = false
            transcriptionProgress = 1.0
        }

        let startTime = Date()

        do {
            // Load audio file
            let audioData = try await loadAudioFile(url: audioURL)

            transcriptionProgress = 0.3

            // Perform transcription
            let result = try await asrManager.transcribe(audioData)

            transcriptionProgress = 0.9

            let processingTime = Date().timeIntervalSince(startTime)

            // Convert FluidAudio result to our TranscriptionResult format
            return convertToTranscriptionResult(
                result: result,
                audioDuration: result.duration,
                processingTime: processingTime,
                removeFillers: removeFillers
            )
        } catch let error as ParakeetServiceError {
            throw error
        } catch {
            throw ParakeetServiceError.transcriptionFailed(error)
        }
        #else
        throw ParakeetServiceError.fluidAudioNotAvailable
        #endif
    }

    /// Transcribe audio from Float array (for real-time recording)
    func transcribe(
        audioData: [Float],
        removeFillers: Bool = false
    ) async throws -> TranscriptionResult {
        #if canImport(FluidAudio)
        guard let asrManager = asrManager, isModelLoaded else {
            throw ParakeetServiceError.modelNotLoaded
        }

        isTranscribing = true
        transcriptionProgress = 0.0

        defer {
            isTranscribing = false
            transcriptionProgress = 1.0
        }

        let startTime = Date()

        do {
            transcriptionProgress = 0.3

            // Perform transcription directly on audio data
            let result = try await asrManager.transcribe(audioData)

            transcriptionProgress = 0.9

            let processingTime = Date().timeIntervalSince(startTime)

            // Calculate audio duration (samples at 16kHz)
            let audioDuration = Double(audioData.count) / 16000.0

            // Convert FluidAudio result to our TranscriptionResult format
            return convertToTranscriptionResult(
                result: result,
                audioDuration: audioDuration,
                processingTime: processingTime,
                removeFillers: removeFillers
            )
        } catch let error as ParakeetServiceError {
            throw error
        } catch {
            throw ParakeetServiceError.transcriptionFailed(error)
        }
        #else
        throw ParakeetServiceError.fluidAudioNotAvailable
        #endif
    }

    /// Cancel ongoing transcription
    func cancelTranscription() {
        currentTask?.cancel()
        currentTask = nil
        isTranscribing = false
    }

    // MARK: - Private Methods

    #if canImport(FluidAudio)
    private func convertToTranscriptionResult(
        result: ASRResult,
        audioDuration: TimeInterval,
        processingTime: TimeInterval,
        removeFillers: Bool
    ) -> TranscriptionResult {
        var cleanedText = result.text
        var segments: [TranscriptionSegment] = []

        // Create segments from token timings if available
        if let tokenTimings = result.tokenTimings, !tokenTimings.isEmpty {
            // Group tokens into sentence-like segments (by punctuation or time gaps)
            segments = groupTokensIntoSegments(tokenTimings)
        } else {
            // Single segment if no timings available
            segments = [
                TranscriptionSegment(
                    id: 0,
                    text: cleanedText,
                    startTime: 0,
                    endTime: audioDuration
                )
            ]
        }

        // Apply filler word removal if enabled
        if removeFillers {
            let fillerService = FillerWordService.shared
            cleanedText = fillerService.removeFillers(from: cleanedText)
            segments = segments.map { fillerService.removeFillers(from: $0) }
        }

        return TranscriptionResult(
            text: cleanedText,
            segments: segments,
            language: "en", // Parakeet v2 is English-only
            duration: audioDuration,
            processingTime: processingTime,
            modelUsed: loadedModelId ?? "parakeet-unknown"
        )
    }

    private func groupTokensIntoSegments(_ tokenTimings: [TokenTiming]) -> [TranscriptionSegment] {
        guard !tokenTimings.isEmpty else { return [] }

        var segments: [TranscriptionSegment] = []
        var currentSegmentTokens: [TokenTiming] = []
        var segmentStartTime: TimeInterval = tokenTimings[0].startTime

        for (index, token) in tokenTimings.enumerated() {
            currentSegmentTokens.append(token)

            // Check if we should end the current segment
            let shouldEndSegment: Bool = {
                // End on sentence-ending punctuation
                if token.token.hasSuffix(".") || token.token.hasSuffix("?") || token.token.hasSuffix("!") {
                    return true
                }

                // End if there's a significant pause (> 0.5s) before the next token
                if index < tokenTimings.count - 1 {
                    let nextToken = tokenTimings[index + 1]
                    if nextToken.startTime - token.endTime > 0.5 {
                        return true
                    }
                }

                // End if segment is getting too long (> 30 seconds)
                if token.endTime - segmentStartTime > 30.0 {
                    return true
                }

                return false
            }()

            if shouldEndSegment || index == tokenTimings.count - 1 {
                let segmentText = currentSegmentTokens.map { $0.token }.joined()
                let segmentEndTime = currentSegmentTokens.last?.endTime ?? token.endTime

                segments.append(TranscriptionSegment(
                    id: segments.count,
                    text: segmentText.trimmingCharacters(in: .whitespaces),
                    startTime: segmentStartTime,
                    endTime: segmentEndTime
                ))

                // Reset for next segment
                currentSegmentTokens = []
                if index < tokenTimings.count - 1 {
                    segmentStartTime = tokenTimings[index + 1].startTime
                }
            }
        }

        return segments
    }

    private func loadAudioFile(url: URL) async throws -> [Float] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ParakeetServiceError.invalidAudioFile
        }

        do {
            let audioFile = try AVAudioFile(forReading: url)
            let format = audioFile.processingFormat
            let frameCount = AVAudioFrameCount(audioFile.length)

            guard frameCount > 0 else {
                throw ParakeetServiceError.invalidAudioFile
            }

            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                throw ParakeetServiceError.invalidAudioFile
            }

            try audioFile.read(into: buffer)

            // Convert to 16kHz mono if needed
            let targetSampleRate: Double = 16000.0

            if format.sampleRate != targetSampleRate || format.channelCount != 1 {
                guard let outputFormat = AVAudioFormat(
                    commonFormat: .pcmFormatFloat32,
                    sampleRate: targetSampleRate,
                    channels: 1,
                    interleaved: false
                ) else {
                    throw ParakeetServiceError.invalidAudioFile
                }

                guard let converter = AVAudioConverter(from: format, to: outputFormat) else {
                    throw ParakeetServiceError.invalidAudioFile
                }

                let ratio = targetSampleRate / format.sampleRate
                let outputFrameCapacity = AVAudioFrameCount(Double(frameCount) * ratio)

                guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputFrameCapacity) else {
                    throw ParakeetServiceError.invalidAudioFile
                }

                var error: NSError?
                converter.convert(to: outputBuffer, error: &error) { _, outStatus in
                    outStatus.pointee = .haveData
                    return buffer
                }

                if let error = error {
                    throw ParakeetServiceError.audioLoadFailed(error)
                }

                return bufferToFloatArray(outputBuffer)
            } else {
                return bufferToFloatArray(buffer)
            }
        } catch let error as ParakeetServiceError {
            throw error
        } catch {
            throw ParakeetServiceError.audioLoadFailed(error)
        }
    }

    private func bufferToFloatArray(_ buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channelData = buffer.floatChannelData else {
            return []
        }

        let frameLength = Int(buffer.frameLength)
        var audioArray = [Float](repeating: 0, count: frameLength)

        for i in 0..<frameLength {
            audioArray[i] = channelData[0][i]
        }

        return audioArray
    }
    #endif
}

// MARK: - Model Management Extension
extension ParakeetService {
    /// Check if a model is downloaded
    func isModelDownloaded(_ modelId: String) -> Bool {
        // FluidAudio manages its own model cache
        let modelPath = modelsDirectory.appendingPathComponent(modelId)
        return FileManager.default.fileExists(atPath: modelPath.path)
    }

    /// Get list of downloaded models
    func getDownloadedModels() -> [String] {
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: modelsDirectory.path) else {
            return []
        }
        return contents.filter { !$0.hasPrefix(".") }
    }

    /// Delete a downloaded model
    func deleteModel(_ modelId: String) throws {
        // Unload if currently loaded
        if loadedModelId == modelId {
            unloadModel()
        }

        // Delete from FluidAudio cache
        #if canImport(FluidAudio)
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let fluidAudioCache = cacheDir.appendingPathComponent("FluidAudio")

        if FileManager.default.fileExists(atPath: fluidAudioCache.path) {
            try? FileManager.default.removeItem(at: fluidAudioCache)
        }
        #endif

        // Also remove from our tracking directory
        let modelPath = modelsDirectory.appendingPathComponent(modelId)
        if FileManager.default.fileExists(atPath: modelPath.path) {
            try FileManager.default.removeItem(at: modelPath)
        }
    }

    /// Get the total size of downloaded Parakeet models
    func getDownloadedModelsSize() -> Int64 {
        var totalSize: Int64 = 0

        #if canImport(FluidAudio)
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let fluidAudioCache = cacheDir.appendingPathComponent("FluidAudio")

        if let enumerator = FileManager.default.enumerator(at: fluidAudioCache, includingPropertiesForKeys: [.fileSizeKey]) {
            while let url = enumerator.nextObject() as? URL {
                if let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = resourceValues.fileSize {
                    totalSize += Int64(fileSize)
                }
            }
        }
        #endif

        return totalSize
    }

    /// Format the downloaded models size for display
    var formattedDownloadedModelsSize: String {
        ByteCountFormatter.string(fromByteCount: getDownloadedModelsSize(), countStyle: .file)
    }
}
