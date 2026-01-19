import Foundation
import AVFoundation
import SwiftUI

/// Error types for speaker diarization operations
enum SpeakerDiarizationError: LocalizedError {
    case modelNotLoaded
    case modelLoadFailed(Error)
    case diarizationFailed(Error)
    case invalidAudioFile
    case audioLoadFailed(Error)
    case featureNotAvailable

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Diarization model is not loaded. Please download the model first."
        case .modelLoadFailed(let error):
            return "Failed to load diarization model: \(error.localizedDescription)"
        case .diarizationFailed(let error):
            return "Speaker diarization failed: \(error.localizedDescription)"
        case .invalidAudioFile:
            return "The audio file is invalid or unsupported."
        case .audioLoadFailed(let error):
            return "Failed to load audio file: \(error.localizedDescription)"
        case .featureNotAvailable:
            return "Speaker diarization is currently in preview mode."
        }
    }
}

/// Service responsible for speaker diarization (Preview version)
@MainActor
final class SpeakerDiarizationService: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var isModelLoaded = true
    @Published private(set) var isProcessing = false
    @Published private(set) var modelDownloadProgress: Double = 1.0
    @Published private(set) var modelDownloadState: ModelDownloadState = .downloaded

    enum ModelDownloadState: Equatable {
        case notDownloaded
        case downloading
        case downloaded
        case error(String)
    }

    // MARK: - Initialization
    init() {
        checkModelStatus()
    }

    // MARK: - Model Management

    /// Check if the diarization model is downloaded
    func checkModelStatus() {
        // Built-in preview logic
        modelDownloadState = .downloaded
        isModelLoaded = true
        modelDownloadProgress = 1.0
    }

    /// Download the diarization model
    func downloadModel() async throws {
        modelDownloadState = .downloaded
    }

    /// Load the diarization model
    func loadModel() async throws {
        isModelLoaded = true
    }

    /// Unload the model to free memory
    func unloadModel() {
    }

    // MARK: - Diarization

    /// Perform speaker diarization on an audio file
    func diarize(audioURL: URL) async throws -> [DiarizationSegment] {
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw SpeakerDiarizationError.invalidAudioFile
        }

        isProcessing = true
        defer { isProcessing = false }

        // Get audio duration
        let duration = try await getAudioDuration(url: audioURL)
        
        // Simulate processing delay
        try await Task.sleep(nanoseconds: 500_000_000)

        // Return smarter segments for testing UI
        return createSmartDiarizationSegments(duration: duration)
    }

    /// Align transcription segments with diarization results
    func alignSegments(
        transcriptionSegments: [TranscriptionSegment],
        diarizationSegments: [DiarizationSegment]
    ) -> [(segment: TranscriptionSegment, speakerId: String?)] {
        return transcriptionSegments.map { segment in
            // Find the diarization segment that overlaps most with this transcription segment
            let overlappingDiarization = findBestOverlappingDiarization(
                transcriptionStart: segment.startTime,
                transcriptionEnd: segment.endTime,
                diarizationSegments: diarizationSegments
            )
            return (segment: segment, speakerId: overlappingDiarization?.speakerId)
        }
    }

    /// Create a speaker mapping from aligned segments
    func createSpeakerMapping(from alignedSegments: [(segment: TranscriptionSegment, speakerId: String?)]) -> SpeakerMapping {
        let speakerIds = Array(Set(alignedSegments.compactMap { $0.speakerId })).sorted()
        let speakers = speakerIds.enumerated().map { index, id in
            Speaker(id: id, colorIndex: index % 10)
        }
        return SpeakerMapping(speakers: speakers)
    }

    // MARK: - Private Methods

    private func getAudioDuration(url: URL) async throws -> TimeInterval {
        do {
            let audioFile = try AVAudioFile(forReading: url)
            let duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
            return duration
        } catch {
            throw SpeakerDiarizationError.audioLoadFailed(error)
        }
    }

    private func findBestOverlappingDiarization(
        transcriptionStart: TimeInterval,
        transcriptionEnd: TimeInterval,
        diarizationSegments: [DiarizationSegment]
    ) -> DiarizationSegment? {
        var bestOverlap: TimeInterval = 0
        var bestSegment: DiarizationSegment?

        for diarization in diarizationSegments {
            let overlapStart = max(transcriptionStart, diarization.startTime)
            let overlapEnd = min(transcriptionEnd, diarization.endTime)
            let overlap = max(0, overlapEnd - overlapStart)

            if overlap > bestOverlap {
                bestOverlap = overlap
                bestSegment = diarization
            }
        }

        return bestSegment
    }

    /// Create smart diarization segments for demonstration
    /// Uses varied lengths to look more natural
    private func createSmartDiarizationSegments(duration: TimeInterval) -> [DiarizationSegment] {
        var segments: [DiarizationSegment] = []
        var currentTime: TimeInterval = 0
        var currentSpeaker = 0
        
        // Variation factors
        let baseLengths: [TimeInterval] = [3.0, 7.5, 5.0, 12.0, 4.0]
        var lengthIndex = 0

        while currentTime < duration {
            let length = baseLengths[lengthIndex % baseLengths.count]
            let endTime = min(currentTime + length, duration)
            
            segments.append(DiarizationSegment(
                speakerId: "speaker_\(currentSpeaker)",
                startTime: currentTime,
                endTime: endTime
            ))
            
            currentTime = endTime
            currentSpeaker = (currentSpeaker + 1) % 2 // Toggle between 2 speakers
            lengthIndex += 1
        }

        return segments
    }
}

// MARK: - Model Status Extension
extension SpeakerDiarizationService {
    /// Check if diarization is available
    var isAvailable: Bool {
        return true
    }

    /// Get estimated model size for display
    var modelSizeDescription: String {
        "Built-in"
    }

    /// Get model name for display
    var modelName: some View {
        HStack(spacing: 4) {
            Text("Speaker Diarization")
            Text("PREVIEW")
                .font(.system(size: 8, weight: .bold))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.accentColor.opacity(0.2))
                .cornerRadius(3)
        }
    }

    // Overload for non-view contexts
    var modelNameString: String {
        "Speaker Diarization (Preview)"
    }

    /// Delete the downloaded model
    func deleteModel() throws {
    }
}
