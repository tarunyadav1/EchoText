import Foundation
import AVFoundation
import WhisperKit
import Combine

/// Error types for Whisper transcription operations
enum WhisperServiceError: LocalizedError {
    case modelNotLoaded
    case modelLoadFailed(Error)
    case transcriptionFailed(Error)
    case invalidAudioFile
    case audioLoadFailed(Error)

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Whisper model is not loaded. Please download a model first."
        case .modelLoadFailed(let error):
            return "Failed to load Whisper model: \(error.localizedDescription)"
        case .transcriptionFailed(let error):
            return "Transcription failed: \(error.localizedDescription)"
        case .invalidAudioFile:
            return "The audio file is invalid or unsupported."
        case .audioLoadFailed(let error):
            return "Failed to load audio file: \(error.localizedDescription)"
        }
    }
}

/// Advanced Whisper transcription parameters
struct WhisperAdvancedOptions {
    /// Controls randomness in transcription (0.0 = deterministic, 1.0 = max randomness)
    var temperature: Double = 0.0
    /// Top-K sampling parameter (higher = more diverse but potentially less accurate)
    /// Maps to WhisperKit's topK parameter
    var topK: Int = 5
    /// Sample length for decoding (higher = longer context window)
    /// Maps to WhisperKit's sampleLength parameter
    var sampleLength: Int = 224
    /// Threshold for detecting silence/no speech (lower = more sensitive)
    var noSpeechThreshold: Double = 0.6
    /// Threshold for compression ratio to detect hallucinations
    var compressionRatioThreshold: Double = 2.4

    /// Create from AppSettings
    static func from(_ settings: AppSettings) -> WhisperAdvancedOptions {
        return WhisperAdvancedOptions(
            temperature: settings.whisperTemperature,
            topK: settings.whisperBeamSize,  // beamSize maps to topK
            sampleLength: settings.whisperBestOf * 224,  // bestOf influences sample length
            noSpeechThreshold: settings.whisperNoSpeechThreshold,
            compressionRatioThreshold: settings.whisperCompressionRatioThreshold
        )
    }

    /// Default options
    static var `default`: WhisperAdvancedOptions {
        return WhisperAdvancedOptions()
    }
}

/// Service responsible for Whisper-based speech-to-text transcription
@MainActor
final class WhisperService: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var isModelLoaded = false
    @Published private(set) var isTranscribing = false
    @Published private(set) var loadedModelId: String?
    @Published private(set) var transcriptionProgress: Double = 0.0

    // MARK: - Private Properties
    private var whisperKit: WhisperKit?
    private var currentTask: Task<TranscriptionResult, Error>?

    // Model storage location
    private var modelsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("EchoText/Models", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Initialization
    init() {}

    // MARK: - Model Loading

    /// Load a Whisper model by ID
    func loadModel(_ modelId: String) async throws {
        // Unload existing model first
        unloadModel()

        do {
            // Extract model name from ID (e.g., "openai_whisper-base" -> "base")
            let modelName = extractModelName(from: modelId)

            // Initialize WhisperKit with the specified model
            whisperKit = try await WhisperKit(
                model: modelName,
                downloadBase: modelsDirectory,
                verbose: false,
                prewarm: true
            )

            isModelLoaded = true
            loadedModelId = modelId
        } catch {
            isModelLoaded = false
            loadedModelId = nil
            throw WhisperServiceError.modelLoadFailed(error)
        }
    }

    /// Unload the current model to free memory
    func unloadModel() {
        whisperKit = nil
        isModelLoaded = false
        loadedModelId = nil
    }

    // MARK: - Transcription

    /// Transcribe audio from a file URL
    func transcribe(
        audioURL: URL,
        language: String? = nil,
        prompt: String? = nil,
        removeFillers: Bool = false,
        advancedOptions: WhisperAdvancedOptions = .default
    ) async throws -> TranscriptionResult {
        guard let whisperKit = whisperKit, isModelLoaded else {
            throw WhisperServiceError.modelNotLoaded
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

            // Configure transcription options with advanced parameters
            let options = configureDecodingOptions(
                language: language,
                prompt: prompt,
                advancedOptions: advancedOptions,
                tokenizer: whisperKit.tokenizer
            )

            // Perform transcription
            let results = try await whisperKit.transcribe(
                audioArray: audioData,
                decodeOptions: options
            )

            let processingTime = Date().timeIntervalSince(startTime)

            // Convert results to our format
            guard let result = results.first else {
                throw WhisperServiceError.transcriptionFailed(NSError(
                    domain: "WhisperService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "No transcription result"]
                ))
            }

            let segments = result.segments.enumerated().map { index, segment in
                TranscriptionSegment(
                    id: index,
                    text: WhisperService.cleanWhisperTokens(segment.text),
                    startTime: TimeInterval(segment.start),
                    endTime: TimeInterval(segment.end)
                )
            }

            // Calculate audio duration
            let audioDuration = audioData.count > 0 ? Double(audioData.count) / 16000.0 : 0.0

            // Clean the full text from special tokens
            var cleanedText = WhisperService.cleanWhisperTokens(result.text)
            var cleanedSegments = segments

            // Apply filler word removal if enabled
            if removeFillers {
                let fillerService = FillerWordService.shared
                cleanedText = fillerService.removeFillers(from: cleanedText)
                cleanedSegments = segments.map { fillerService.removeFillers(from: $0) }
            }

            return TranscriptionResult(
                text: cleanedText,
                segments: cleanedSegments,
                language: result.language,
                duration: audioDuration,
                processingTime: processingTime,
                modelUsed: loadedModelId ?? "unknown"
            )
        } catch let error as WhisperServiceError {
            throw error
        } catch {
            throw WhisperServiceError.transcriptionFailed(error)
        }
    }

    /// Transcribe audio from Float array (for real-time recording)
    func transcribe(
        audioData: [Float],
        language: String? = nil,
        prompt: String? = nil,
        removeFillers: Bool = false,
        advancedOptions: WhisperAdvancedOptions = .default
    ) async throws -> TranscriptionResult {
        guard let whisperKit = whisperKit, isModelLoaded else {
            throw WhisperServiceError.modelNotLoaded
        }

        isTranscribing = true
        transcriptionProgress = 0.0

        defer {
            isTranscribing = false
            transcriptionProgress = 1.0
        }

        let startTime = Date()

        do {
            // Configure transcription options with advanced parameters
            let options = configureDecodingOptions(
                language: language,
                prompt: prompt,
                advancedOptions: advancedOptions,
                tokenizer: whisperKit.tokenizer
            )

            // Perform transcription
            let results = try await whisperKit.transcribe(
                audioArray: audioData,
                decodeOptions: options
            )

            let processingTime = Date().timeIntervalSince(startTime)

            // Convert results to our format
            guard let result = results.first else {
                throw WhisperServiceError.transcriptionFailed(NSError(
                    domain: "WhisperService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "No transcription result"]
                ))
            }

            let segments = result.segments.enumerated().map { index, segment in
                TranscriptionSegment(
                    id: index,
                    text: WhisperService.cleanWhisperTokens(segment.text),
                    startTime: TimeInterval(segment.start),
                    endTime: TimeInterval(segment.end)
                )
            }

            // Calculate audio duration
            let audioDuration = audioData.count > 0 ? Double(audioData.count) / 16000.0 : 0.0

            // Clean the full text from special tokens
            var cleanedText = WhisperService.cleanWhisperTokens(result.text)
            var cleanedSegments = segments

            // Apply filler word removal if enabled
            if removeFillers {
                let fillerService = FillerWordService.shared
                cleanedText = fillerService.removeFillers(from: cleanedText)
                cleanedSegments = segments.map { fillerService.removeFillers(from: $0) }
            }

            return TranscriptionResult(
                text: cleanedText,
                segments: cleanedSegments,
                language: result.language,
                duration: audioDuration,
                processingTime: processingTime,
                modelUsed: loadedModelId ?? "unknown"
            )
        } catch let error as WhisperServiceError {
            throw error
        } catch {
            throw WhisperServiceError.transcriptionFailed(error)
        }
    }

    /// Cancel ongoing transcription
    func cancelTranscription() {
        currentTask?.cancel()
        currentTask = nil
        isTranscribing = false
    }

    // MARK: - Private Methods

    /// Configure DecodingOptions with language, prompt, and advanced parameters
    private func configureDecodingOptions(
        language: String?,
        prompt: String?,
        advancedOptions: WhisperAdvancedOptions,
        tokenizer: (any WhisperTokenizer)?
    ) -> DecodingOptions {
        var options = DecodingOptions()

        // Language setting
        if let language = language, language != "auto" {
            options.language = language
        }

        // Prompt tokens
        if let prompt = prompt, !prompt.isEmpty, let tokenizer = tokenizer {
            let tokens = tokenizer.encode(text: " " + prompt.trimmingCharacters(in: .whitespaces))
            options.promptTokens = tokens.filter { $0 < tokenizer.specialTokens.specialTokenBegin }
            options.usePrefillPrompt = true
        }

        // Advanced parameters - using WhisperKit's actual DecodingOptions properties
        options.temperature = Float(advancedOptions.temperature)
        options.temperatureFallbackCount = advancedOptions.temperature > 0 ? 5 : 0
        options.topK = advancedOptions.topK
        options.sampleLength = advancedOptions.sampleLength
        options.noSpeechThreshold = Float(advancedOptions.noSpeechThreshold)
        options.compressionRatioThreshold = Float(advancedOptions.compressionRatioThreshold)

        // Standard settings
        options.verbose = false

        return options
    }

    private func extractModelName(from modelId: String) -> String {
        // Convert model ID to WhisperKit model name
        // e.g., "openai_whisper-base" -> "base"
        // e.g., "openai_whisper-large-v3-turbo" -> "large-v3-turbo"
        if modelId.contains("whisper-") {
            let components = modelId.components(separatedBy: "whisper-")
            if components.count > 1 {
                return components[1]
            }
        }
        return modelId
    }

    private func loadAudioFile(url: URL) async throws -> [Float] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw WhisperServiceError.invalidAudioFile
        }

        do {
            // Try using AVAudioFile directly for more control
            let audioFile = try AVAudioFile(forReading: url)
            let format = audioFile.processingFormat
            let frameCount = AVAudioFrameCount(audioFile.length)

            guard frameCount > 0 else {
                throw WhisperServiceError.invalidAudioFile
            }

            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                throw WhisperServiceError.invalidAudioFile
            }

            try audioFile.read(into: buffer)

            // Convert to 16kHz mono if needed
            let targetSampleRate: Double = 16000.0

            if format.sampleRate != targetSampleRate || format.channelCount != 1 {
                // Need to resample
                guard let outputFormat = AVAudioFormat(
                    commonFormat: .pcmFormatFloat32,
                    sampleRate: targetSampleRate,
                    channels: 1,
                    interleaved: false
                ) else {
                    throw WhisperServiceError.invalidAudioFile
                }

                guard let converter = AVAudioConverter(from: format, to: outputFormat) else {
                    throw WhisperServiceError.invalidAudioFile
                }

                let ratio = targetSampleRate / format.sampleRate
                let outputFrameCapacity = AVAudioFrameCount(Double(frameCount) * ratio)

                guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputFrameCapacity) else {
                    throw WhisperServiceError.invalidAudioFile
                }

                var error: NSError?
                converter.convert(to: outputBuffer, error: &error) { _, outStatus in
                    outStatus.pointee = .haveData
                    return buffer
                }

                if let error = error {
                    throw WhisperServiceError.audioLoadFailed(error)
                }

                return bufferToFloatArray(outputBuffer)
            } else {
                return bufferToFloatArray(buffer)
            }
        } catch let error as WhisperServiceError {
            throw error
        } catch {
            throw WhisperServiceError.audioLoadFailed(error)
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
}

// MARK: - Diarization Integration
extension WhisperService {
    /// Transcribe audio with speaker diarization
    func transcribeWithDiarization(
        audioURL: URL,
        language: String? = nil,
        diarizationService: SpeakerDiarizationService,
        removeFillers: Bool = false,
        advancedOptions: WhisperAdvancedOptions = .default
    ) async throws -> TranscriptionResult {
        // First, perform transcription
        var result = try await transcribe(
            audioURL: audioURL,
            language: language,
            removeFillers: removeFillers,
            advancedOptions: advancedOptions
        )

        // Then, perform diarization
        let diarizationSegments = try await diarizationService.diarize(audioURL: audioURL)

        // Align transcription segments with diarization
        let alignedSegments = diarizationService.alignSegments(
            transcriptionSegments: result.segments,
            diarizationSegments: diarizationSegments
        )

        // Create speaker mapping
        let speakerIds = alignedSegments.compactMap { $0.speakerId }
        let speakerMapping = SpeakerMapping.create(from: speakerIds)

        // Update segments with speaker IDs
        let segmentsWithSpeakers = alignedSegments.map { aligned in
            aligned.segment.withSpeaker(aligned.speakerId)
        }

        // Create new result with speaker information
        return TranscriptionResult(
            id: result.id,
            text: result.text,
            segments: segmentsWithSpeakers,
            language: result.language,
            duration: result.duration,
            processingTime: result.processingTime,
            modelUsed: result.modelUsed,
            timestamp: result.timestamp,
            speakerMapping: speakerMapping
        )
    }
}

// MARK: - Model Management Extension
extension WhisperService {
    /// Check if a model is downloaded
    func isModelDownloaded(_ modelId: String) -> Bool {
        let modelName = extractModelName(from: modelId)
        let modelPath = modelsDirectory.appendingPathComponent(modelName)
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
        let modelName = extractModelName(from: modelId)
        let modelPath = modelsDirectory.appendingPathComponent(modelName)
        try FileManager.default.removeItem(at: modelPath)

        if loadedModelId == modelId {
            unloadModel()
        }
    }
}

// MARK: - Text Cleaning Extension
extension WhisperService {
    /// Clean Whisper special tokens from transcription text
    static func cleanWhisperTokens(_ text: String) -> String {
        var cleaned = text

        // Remove special tokens like <|startoftranscript|>, <|en|>, <|transcribe|>, <|endoftext|>
        let specialTokenPatterns = [
            "<\\|startoftranscript\\|>",
            "<\\|endoftext\\|>",
            "<\\|transcribe\\|>",
            "<\\|translate\\|>",
            "<\\|notimestamps\\|>",
            "<\\|[a-z]{2}\\|>",  // Language codes like <|en|>, <|es|>, etc.
            "<\\|\\d+\\.\\d+\\|>",  // Timestamp tokens like <|0.00|>, <|4.24|>
        ]

        for pattern in specialTokenPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                cleaned = regex.stringByReplacingMatches(
                    in: cleaned,
                    options: [],
                    range: NSRange(cleaned.startIndex..., in: cleaned),
                    withTemplate: ""
                )
            }
        }

        // Clean up extra whitespace
        cleaned = cleaned.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned
    }
}
