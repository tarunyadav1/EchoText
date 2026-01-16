import Foundation

/// Represents the result of a transcription operation
struct TranscriptionResult: Identifiable, Codable {
    let id: UUID
    let text: String
    let segments: [TranscriptionSegment]
    let language: String?
    let duration: TimeInterval
    let processingTime: TimeInterval
    let modelUsed: String
    let timestamp: Date

    init(
        id: UUID = UUID(),
        text: String,
        segments: [TranscriptionSegment] = [],
        language: String? = nil,
        duration: TimeInterval,
        processingTime: TimeInterval,
        modelUsed: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.segments = segments
        self.language = language
        self.duration = duration
        self.processingTime = processingTime
        self.modelUsed = modelUsed
        self.timestamp = timestamp
    }

    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var wordCount: Int {
        text.split(separator: " ").count
    }

    var realTimeFactor: Double {
        guard duration > 0 else { return 0 }
        return processingTime / duration
    }
}

/// Represents a segment of transcribed text with timing information
struct TranscriptionSegment: Identifiable, Codable {
    let id: Int
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval

    var duration: TimeInterval {
        endTime - startTime
    }

    var formattedTimeRange: String {
        let start = formatTime(startTime)
        let end = formatTime(endTime)
        return "\(start) → \(end)"
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d.%03d", minutes, seconds, milliseconds)
    }
}
