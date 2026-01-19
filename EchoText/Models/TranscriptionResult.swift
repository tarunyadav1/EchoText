import Foundation

/// Represents the result of a transcription operation
struct TranscriptionResult: Identifiable, Codable {
    let id: UUID
    private(set) var text: String
    private(set) var segments: [TranscriptionSegment]
    let language: String?
    let duration: TimeInterval
    let processingTime: TimeInterval
    let modelUsed: String
    let timestamp: Date
    var speakerMapping: SpeakerMapping?

    /// Track if the result has been edited
    private(set) var isEdited: Bool = false
    private(set) var lastEditedAt: Date?

    /// Translations dictionary keyed by language code (e.g., "es", "fr")
    /// Each entry contains translated segments for that language
    private(set) var translations: [String: [TranscriptionSegment]] = [:]

    enum CodingKeys: String, CodingKey {
        case id, text, segments, language, duration, processingTime
        case modelUsed, timestamp, speakerMapping, isEdited, lastEditedAt
        case translations
    }

    init(
        id: UUID = UUID(),
        text: String,
        segments: [TranscriptionSegment] = [],
        language: String? = nil,
        duration: TimeInterval,
        processingTime: TimeInterval,
        modelUsed: String,
        timestamp: Date = Date(),
        speakerMapping: SpeakerMapping? = nil,
        isEdited: Bool = false,
        lastEditedAt: Date? = nil,
        translations: [String: [TranscriptionSegment]] = [:]
    ) {
        self.id = id
        self.text = text
        self.segments = segments
        self.language = language
        self.duration = duration
        self.processingTime = processingTime
        self.modelUsed = modelUsed
        self.timestamp = timestamp
        self.speakerMapping = speakerMapping
        self.isEdited = isEdited
        self.lastEditedAt = lastEditedAt
        self.translations = translations
    }

    /// Check if this transcription has speaker diarization
    var hasSpeakerDiarization: Bool {
        speakerMapping != nil && !(speakerMapping?.isEmpty ?? true) && segments.contains { $0.speakerId != nil }
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

    /// Get all favorited segments
    var favoritedSegments: [TranscriptionSegment] {
        segments.filter { $0.isFavorite }
    }

    /// Check if any segments are favorited
    var hasFavoritedSegments: Bool {
        segments.contains { $0.isFavorite }
    }

    /// Get all available translation language codes
    var availableTranslationLanguages: [String] {
        Array(translations.keys).sorted()
    }

    /// Check if translations exist for a given language
    func hasTranslation(for languageCode: String) -> Bool {
        translations[languageCode] != nil && !(translations[languageCode]?.isEmpty ?? true)
    }

    // MARK: - Translation Methods

    /// Get translated segments for a specific language
    /// - Parameter languageCode: The ISO 639-1 language code (e.g., "es", "fr", "de")
    /// - Returns: Array of translated segments, or nil if no translation exists
    func getTranslation(for languageCode: String) -> [TranscriptionSegment]? {
        translations[languageCode]
    }

    /// Add or update a translation for a specific language
    /// - Parameters:
    ///   - segments: The translated segments
    ///   - languageCode: The ISO 639-1 language code
    mutating func setTranslation(_ segments: [TranscriptionSegment], for languageCode: String) {
        translations[languageCode] = segments
        markAsEdited()
    }

    /// Remove a translation for a specific language
    /// - Parameter languageCode: The ISO 639-1 language code
    mutating func removeTranslation(for languageCode: String) {
        translations.removeValue(forKey: languageCode)
        markAsEdited()
    }

    /// Remove all translations
    mutating func clearAllTranslations() {
        translations.removeAll()
        markAsEdited()
    }

    /// Get combined text for a translation
    /// - Parameter languageCode: The ISO 639-1 language code
    /// - Returns: Combined text from all translated segments, or nil if no translation exists
    func getTranslatedText(for languageCode: String) -> String? {
        guard let translatedSegments = translations[languageCode] else { return nil }
        return translatedSegments.map { $0.text.trimmingCharacters(in: .whitespaces) }.joined(separator: " ")
    }

    // MARK: - Editing Methods

    /// Update a segment's text at the given index
    mutating func updateSegment(at index: Int, newText: String) {
        guard index >= 0 && index < segments.count else { return }
        segments[index] = segments[index].withText(newText)
        recalculateFullText()
        markAsEdited()
    }

    /// Update a segment by its UUID
    mutating func updateSegment(id segmentId: UUID, newText: String) {
        guard let index = segments.firstIndex(where: { $0.uuid == segmentId }) else { return }
        updateSegment(at: index, newText: newText)
    }

    /// Toggle favorite status for a segment at the given index
    mutating func toggleSegmentFavorite(at index: Int) {
        guard index >= 0 && index < segments.count else { return }
        segments[index] = segments[index].withFavoriteToggled()
        markAsEdited()
    }

    /// Toggle favorite status for a segment by its UUID
    mutating func toggleSegmentFavorite(id segmentId: UUID) {
        guard let index = segments.firstIndex(where: { $0.uuid == segmentId }) else { return }
        toggleSegmentFavorite(at: index)
    }

    /// Set favorite status for a segment by its UUID
    mutating func setSegmentFavorite(id segmentId: UUID, isFavorite: Bool) {
        guard let index = segments.firstIndex(where: { $0.uuid == segmentId }) else { return }
        segments[index] = segments[index].withFavorite(isFavorite)
        markAsEdited()
    }

    /// Delete a segment at the given index
    mutating func deleteSegment(at index: Int) {
        guard index >= 0 && index < segments.count else { return }
        segments.remove(at: index)
        // Re-index remaining segments
        segments = segments.enumerated().map { idx, segment in
            TranscriptionSegment(
                id: idx,
                uuid: segment.uuid,
                text: segment.text,
                startTime: segment.startTime,
                endTime: segment.endTime,
                speakerId: segment.speakerId,
                isFavorite: segment.isFavorite
            )
        }
        recalculateFullText()
        markAsEdited()
    }

    /// Delete a segment by its UUID
    mutating func deleteSegment(id segmentId: UUID) {
        guard let index = segments.firstIndex(where: { $0.uuid == segmentId }) else { return }
        deleteSegment(at: index)
    }

    /// Delete multiple segments by their UUIDs
    mutating func deleteSegments(ids segmentIds: Set<UUID>) {
        segments.removeAll { segmentIds.contains($0.uuid) }
        // Re-index remaining segments
        segments = segments.enumerated().map { idx, segment in
            TranscriptionSegment(
                id: idx,
                uuid: segment.uuid,
                text: segment.text,
                startTime: segment.startTime,
                endTime: segment.endTime,
                speakerId: segment.speakerId,
                isFavorite: segment.isFavorite
            )
        }
        recalculateFullText()
        markAsEdited()
    }

    /// Merge a segment with the next segment
    mutating func mergeSegmentWithNext(at index: Int) {
        guard index >= 0 && index < segments.count - 1 else { return }
        let current = segments[index]
        let next = segments[index + 1]
        let mergedText = current.text.trimmingCharacters(in: .whitespaces) + " " + next.text.trimmingCharacters(in: .whitespaces)

        segments[index] = TranscriptionSegment(
            id: current.id,
            uuid: current.uuid,
            text: mergedText,
            startTime: current.startTime,
            endTime: next.endTime,
            speakerId: current.speakerId,
            isFavorite: current.isFavorite || next.isFavorite // Preserve favorite if either was favorited
        )
        segments.remove(at: index + 1)

        // Re-index remaining segments
        segments = segments.enumerated().map { idx, segment in
            TranscriptionSegment(
                id: idx,
                uuid: segment.uuid,
                text: segment.text,
                startTime: segment.startTime,
                endTime: segment.endTime,
                speakerId: segment.speakerId,
                isFavorite: segment.isFavorite
            )
        }
        recalculateFullText()
        markAsEdited()
    }

    /// Recalculate the full text from all segments
    private mutating func recalculateFullText() {
        text = segments.map { $0.text.trimmingCharacters(in: .whitespaces) }.joined(separator: " ")
    }

    /// Mark the result as edited
    private mutating func markAsEdited() {
        isEdited = true
        lastEditedAt = Date()
    }
}

/// Represents a segment of transcribed text with timing information
struct TranscriptionSegment: Identifiable, Codable, Equatable, Hashable {
    let id: Int
    let uuid: UUID
    var text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    var speakerId: String?
    var isFavorite: Bool

    init(id: Int, uuid: UUID = UUID(), text: String, startTime: TimeInterval, endTime: TimeInterval, speakerId: String? = nil, isFavorite: Bool = false) {
        self.id = id
        self.uuid = uuid
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.speakerId = speakerId
        self.isFavorite = isFavorite
    }

    var duration: TimeInterval {
        endTime - startTime
    }

    var formattedTimeRange: String {
        let start = formatTime(startTime)
        let end = formatTime(endTime)
        return "\(start) -> \(end)"
    }

    var formattedStartTime: String {
        formatTime(startTime)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d.%03d", minutes, seconds, milliseconds)
    }

    /// Create a copy with a speaker ID assigned
    func withSpeaker(_ speakerId: String?) -> TranscriptionSegment {
        TranscriptionSegment(id: id, uuid: uuid, text: text, startTime: startTime, endTime: endTime, speakerId: speakerId, isFavorite: isFavorite)
    }

    /// Create a copy with updated text
    func withText(_ newText: String) -> TranscriptionSegment {
        TranscriptionSegment(id: id, uuid: uuid, text: newText, startTime: startTime, endTime: endTime, speakerId: speakerId, isFavorite: isFavorite)
    }

    /// Create a copy with favorite status toggled
    func withFavoriteToggled() -> TranscriptionSegment {
        TranscriptionSegment(id: id, uuid: uuid, text: text, startTime: startTime, endTime: endTime, speakerId: speakerId, isFavorite: !isFavorite)
    }

    /// Create a copy with specific favorite status
    func withFavorite(_ favorite: Bool) -> TranscriptionSegment {
        TranscriptionSegment(id: id, uuid: uuid, text: text, startTime: startTime, endTime: endTime, speakerId: speakerId, isFavorite: favorite)
    }

    /// Create a translated copy with same timing but different text
    func withTranslation(_ translatedText: String) -> TranscriptionSegment {
        TranscriptionSegment(id: id, uuid: uuid, text: translatedText, startTime: startTime, endTime: endTime, speakerId: speakerId, isFavorite: isFavorite)
    }
}
