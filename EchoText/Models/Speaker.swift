import Foundation
import SwiftUI

/// Represents a speaker identified in a transcription
struct Speaker: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var displayName: String
    var colorIndex: Int

    /// Default name for a speaker based on their ID
    static func defaultName(for id: String) -> String {
        // Extract number from speaker ID like "speaker_0" -> "Speaker 1"
        if let lastComponent = id.split(separator: "_").last,
           let number = Int(lastComponent) {
            return "Speaker \(number + 1)"
        }
        return id.capitalized
    }

    init(id: String, displayName: String? = nil, colorIndex: Int = 0) {
        self.id = id
        self.displayName = displayName ?? Self.defaultName(for: id)
        self.colorIndex = colorIndex
    }
}

/// Manages speaker assignments and name mappings for a transcription
struct SpeakerMapping: Codable, Equatable {
    private(set) var speakers: [Speaker]

    init(speakers: [Speaker] = []) {
        self.speakers = speakers
    }

    /// Create a speaker mapping from a list of speaker IDs
    static func create(from speakerIds: [String]) -> SpeakerMapping {
        let uniqueIds = Array(Set(speakerIds)).sorted()
        let speakers = uniqueIds.enumerated().map { index, id in
            Speaker(id: id, colorIndex: index % 10)
        }
        return SpeakerMapping(speakers: speakers)
    }

    /// Get a speaker by ID
    func speaker(for id: String) -> Speaker? {
        speakers.first { $0.id == id }
    }

    /// Get display name for a speaker ID
    func displayName(for speakerId: String) -> String {
        speaker(for: speakerId)?.displayName ?? Speaker.defaultName(for: speakerId)
    }

    /// Get color index for a speaker ID
    func colorIndex(for speakerId: String) -> Int {
        speaker(for: speakerId)?.colorIndex ?? 0
    }

    /// Update a speaker's display name
    mutating func updateDisplayName(_ name: String, for speakerId: String) {
        if let index = speakers.firstIndex(where: { $0.id == speakerId }) {
            speakers[index].displayName = name
        }
    }

    /// Update a speaker's color index
    mutating func updateColorIndex(_ colorIndex: Int, for speakerId: String) {
        if let index = speakers.firstIndex(where: { $0.id == speakerId }) {
            speakers[index].colorIndex = colorIndex
        }
    }

    /// Add a new speaker if not already present
    mutating func addSpeaker(_ speakerId: String) {
        guard !speakers.contains(where: { $0.id == speakerId }) else { return }
        let colorIndex = speakers.count % 10
        let speaker = Speaker(id: speakerId, colorIndex: colorIndex)
        speakers.append(speaker)
    }

    /// Check if mapping is empty
    var isEmpty: Bool {
        speakers.isEmpty
    }

    /// Number of speakers
    var count: Int {
        speakers.count
    }
}

/// A diarization segment representing when a speaker is talking
struct DiarizationSegment: Codable, Equatable {
    let speakerId: String
    let startTime: TimeInterval
    let endTime: TimeInterval

    var duration: TimeInterval {
        endTime - startTime
    }
}
