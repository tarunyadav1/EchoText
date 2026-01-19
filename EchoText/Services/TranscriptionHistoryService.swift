import Foundation

// MARK: - Search Types

/// Search result with relevance scoring and match ranges
struct SearchResult {
    let item: TranscriptionHistoryItem
    let relevanceScore: Int
    let matchRanges: [Range<String.Index>]
}

/// Helper extension for checking range overlap
extension Range where Bound == String.Index {
    func overlaps(_ other: Range<String.Index>) -> Bool {
        return lowerBound < other.upperBound && other.lowerBound < upperBound
    }
}

/// Service responsible for persisting and managing transcription history
final class TranscriptionHistoryService {
    // MARK: - Singleton
    static let shared = TranscriptionHistoryService()

    // MARK: - Properties
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var historyDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("EchoText/History", isDirectory: true)

        // Ensure directory exists
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        return dir
    }

    private var indexFile: URL {
        historyDirectory.appendingPathComponent("index.json")
    }

    // MARK: - Initialization
    private init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Public Methods

    /// Load all transcription history from disk
    func loadHistory() -> [TranscriptionHistoryItem] {
        guard fileManager.fileExists(atPath: indexFile.path),
              let data = try? Data(contentsOf: indexFile),
              let items = try? decoder.decode([TranscriptionHistoryItem].self, from: data) else {
            return []
        }

        return items.sorted { $0.timestamp > $1.timestamp }
    }

    /// Save a new transcription to history
    func save(_ result: TranscriptionResult, source: TranscriptionSource) {
        var history = loadHistory()

        let item = TranscriptionHistoryItem(
            id: result.id,
            text: result.text,
            segments: result.segments,
            language: result.language,
            duration: result.duration,
            processingTime: result.processingTime,
            modelUsed: result.modelUsed,
            timestamp: result.timestamp,
            source: source,
            isFavorite: false,
            tags: [],
            speakerMapping: result.speakerMapping
        )

        // Insert at beginning (newest first)
        history.insert(item, at: 0)

        // Save updated index
        saveIndex(history)
    }

    /// Update speaker mapping for a history item
    func updateSpeakerMapping(_ mapping: SpeakerMapping, for itemId: UUID) {
        var history = loadHistory()

        if let index = history.firstIndex(where: { $0.id == itemId }) {
            history[index].speakerMapping = mapping
            saveIndex(history)
        }
    }

    /// Update an existing history item
    func update(_ item: TranscriptionHistoryItem) {
        var history = loadHistory()

        if let index = history.firstIndex(where: { $0.id == item.id }) {
            history[index] = item
            saveIndex(history)
        }
    }

    /// Delete a transcription from history
    func delete(_ item: TranscriptionHistoryItem) {
        var history = loadHistory()
        history.removeAll { $0.id == item.id }
        saveIndex(history)
    }

    /// Delete multiple transcriptions
    func delete(_ items: [TranscriptionHistoryItem]) {
        var history = loadHistory()
        let idsToDelete = Set(items.map { $0.id })
        history.removeAll { idsToDelete.contains($0.id) }
        saveIndex(history)
    }

    /// Clear all history
    func clearAll() {
        saveIndex([])
    }

    /// Search history by text content
    func search(query: String) -> [TranscriptionHistoryItem] {
        let history = loadHistory()
        let lowercasedQuery = query.lowercased()

        return history.filter { item in
            item.text.lowercased().contains(lowercasedQuery) ||
            item.tags.contains { $0.lowercased().contains(lowercasedQuery) } ||
            (item.source.fileName?.lowercased().contains(lowercasedQuery) ?? false)
        }
    }

    /// Advanced search with relevance scoring and date filtering
    func advancedSearch(
        query: String,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) -> [SearchResult] {
        var history = loadHistory()

        // Apply date filtering first
        if let start = startDate {
            history = history.filter { $0.timestamp >= start }
        }
        if let end = endDate {
            // Include the entire end day
            let calendar = Calendar.current
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end)) ?? end
            history = history.filter { $0.timestamp < endOfDay }
        }

        // If no query, return all items with zero score
        guard !query.isEmpty else {
            return history.map { SearchResult(item: $0, relevanceScore: 0, matchRanges: []) }
        }

        let lowercasedQuery = query.lowercased()
        let queryWords = lowercasedQuery.split(separator: " ").map(String.init)

        var results: [SearchResult] = []

        for item in history {
            let lowercasedText = item.text.lowercased()
            var score = 0
            var matchRanges: [Range<String.Index>] = []

            // Exact phrase match: +100
            if lowercasedText.contains(lowercasedQuery) {
                score += 100
                // Find all occurrences of the exact phrase
                var searchRange = lowercasedText.startIndex..<lowercasedText.endIndex
                while let range = lowercasedText.range(of: lowercasedQuery, range: searchRange) {
                    // Convert to original text index
                    let startOffset = lowercasedText.distance(from: lowercasedText.startIndex, to: range.lowerBound)
                    let endOffset = lowercasedText.distance(from: lowercasedText.startIndex, to: range.upperBound)
                    if let originalStart = item.text.index(item.text.startIndex, offsetBy: startOffset, limitedBy: item.text.endIndex),
                       let originalEnd = item.text.index(item.text.startIndex, offsetBy: endOffset, limitedBy: item.text.endIndex) {
                        matchRanges.append(originalStart..<originalEnd)
                    }
                    searchRange = range.upperBound..<lowercasedText.endIndex
                }
            }

            // Word boundary matches: +10 per word
            for word in queryWords {
                let wordPattern = "\\b\(NSRegularExpression.escapedPattern(for: word))\\b"
                if let regex = try? NSRegularExpression(pattern: wordPattern, options: .caseInsensitive) {
                    let nsRange = NSRange(lowercasedText.startIndex..., in: lowercasedText)
                    let matches = regex.matches(in: lowercasedText, range: nsRange)
                    score += matches.count * 10

                    // Add match ranges for individual words (if not already covered by exact phrase)
                    for match in matches {
                        if let range = Range(match.range, in: item.text) {
                            if !matchRanges.contains(where: { $0.overlaps(range) }) {
                                matchRanges.append(range)
                            }
                        }
                    }
                }
            }

            // Partial match: +1 per occurrence
            for word in queryWords {
                var searchRange = lowercasedText.startIndex..<lowercasedText.endIndex
                while let range = lowercasedText.range(of: word, range: searchRange) {
                    score += 1
                    searchRange = range.upperBound..<lowercasedText.endIndex
                }
            }

            // File name match: +50
            if let fileName = item.source.fileName?.lowercased(), fileName.contains(lowercasedQuery) {
                score += 50
            }

            // Tag match: +25 per matching tag
            for tag in item.tags {
                if tag.lowercased().contains(lowercasedQuery) {
                    score += 25
                }
            }

            // Only include items with matches
            if score > 0 {
                results.append(SearchResult(item: item, relevanceScore: score, matchRanges: matchRanges))
            }
        }

        // Sort by relevance score (highest first), then by timestamp (newest first)
        return results.sorted { lhs, rhs in
            if lhs.relevanceScore != rhs.relevanceScore {
                return lhs.relevanceScore > rhs.relevanceScore
            }
            return lhs.item.timestamp > rhs.item.timestamp
        }
    }

    /// Get history items filtered by date range
    func getHistory(from startDate: Date, to endDate: Date) -> [TranscriptionHistoryItem] {
        loadHistory().filter { item in
            item.timestamp >= startDate && item.timestamp <= endDate
        }
    }

    /// Get history items grouped by date
    func getHistoryGroupedByDate() -> [(date: Date, items: [TranscriptionHistoryItem])] {
        let history = loadHistory()
        let calendar = Calendar.current

        let grouped = Dictionary(grouping: history) { item in
            calendar.startOfDay(for: item.timestamp)
        }

        return grouped
            .map { (date: $0.key, items: $0.value) }
            .sorted { $0.date > $1.date }
    }

    /// Get favorite items
    func getFavorites() -> [TranscriptionHistoryItem] {
        loadHistory().filter { $0.isFavorite }
    }

    /// Toggle favorite status
    func toggleFavorite(_ item: TranscriptionHistoryItem) {
        var updatedItem = item
        updatedItem.isFavorite.toggle()
        update(updatedItem)
    }

    /// Update a segment within a history item
    func updateSegment(in itemId: UUID, segmentId: UUID, newText: String) {
        var history = loadHistory()

        if let index = history.firstIndex(where: { $0.id == itemId }) {
            history[index].updateSegment(id: segmentId, newText: newText)
            saveIndex(history)
        }
    }

    /// Delete a segment from a history item
    func deleteSegment(in itemId: UUID, segmentId: UUID) {
        var history = loadHistory()

        if let index = history.firstIndex(where: { $0.id == itemId }) {
            history[index].deleteSegment(id: segmentId)
            saveIndex(history)
        }
    }

    /// Merge a segment with the next in a history item
    func mergeSegmentWithNext(in itemId: UUID, segmentId: UUID) {
        var history = loadHistory()

        if let index = history.firstIndex(where: { $0.id == itemId }) {
            history[index].mergeSegmentWithNext(id: segmentId)
            saveIndex(history)
        }
    }

    /// Toggle favorite status for a segment within a history item
    func toggleSegmentFavorite(in itemId: UUID, segmentId: UUID) {
        var history = loadHistory()

        if let index = history.firstIndex(where: { $0.id == itemId }) {
            history[index].toggleSegmentFavorite(id: segmentId)
            saveIndex(history)
        }
    }

    /// Set favorite status for a segment within a history item
    func setSegmentFavorite(in itemId: UUID, segmentId: UUID, isFavorite: Bool) {
        var history = loadHistory()

        if let index = history.firstIndex(where: { $0.id == itemId }) {
            history[index].setSegmentFavorite(id: segmentId, isFavorite: isFavorite)
            saveIndex(history)
        }
    }

    /// Get all favorited segments across all transcriptions
    func getAllFavoritedSegments() -> [FavoritedSegmentInfo] {
        let history = loadHistory()
        var favoritedSegments: [FavoritedSegmentInfo] = []

        for item in history {
            for segment in item.segments where segment.isFavorite {
                favoritedSegments.append(FavoritedSegmentInfo(
                    segment: segment,
                    transcriptionId: item.id,
                    transcriptionTimestamp: item.timestamp,
                    transcriptionSource: item.source,
                    speakerMapping: item.speakerMapping
                ))
            }
        }

        // Sort by transcription timestamp (newest first), then by segment start time
        return favoritedSegments.sorted { lhs, rhs in
            if lhs.transcriptionTimestamp != rhs.transcriptionTimestamp {
                return lhs.transcriptionTimestamp > rhs.transcriptionTimestamp
            }
            return lhs.segment.startTime < rhs.segment.startTime
        }
    }

    /// Get items that have favorited segments
    func getItemsWithFavoritedSegments() -> [TranscriptionHistoryItem] {
        loadHistory().filter { $0.hasFavoritedSegments }
    }

    /// Get count of all favorited segments across all transcriptions
    func getFavoritedSegmentsCount() -> Int {
        loadHistory().reduce(0) { count, item in
            count + item.segments.filter { $0.isFavorite }.count
        }
    }

    /// Add tag to item
    func addTag(_ tag: String, to item: TranscriptionHistoryItem) {
        var updatedItem = item
        if !updatedItem.tags.contains(tag) {
            updatedItem.tags.append(tag)
            update(updatedItem)
        }
    }

    /// Remove tag from item
    func removeTag(_ tag: String, from item: TranscriptionHistoryItem) {
        var updatedItem = item
        updatedItem.tags.removeAll { $0 == tag }
        update(updatedItem)
    }

    /// Get total statistics
    func getStatistics() -> HistoryStatistics {
        let history = loadHistory()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today)!

        let todayItems = history.filter { calendar.isDate($0.timestamp, inSameDayAs: today) }
        let weekItems = history.filter { $0.timestamp >= weekAgo }

        return HistoryStatistics(
            totalTranscriptions: history.count,
            totalWords: history.reduce(0) { $0 + $1.wordCount },
            totalDuration: history.reduce(0) { $0 + $1.duration },
            transcriptionsToday: todayItems.count,
            wordsToday: todayItems.reduce(0) { $0 + $1.wordCount },
            transcriptionsThisWeek: weekItems.count,
            wordsThisWeek: weekItems.reduce(0) { $0 + $1.wordCount }
        )
    }

    // MARK: - Private Methods

    private func saveIndex(_ history: [TranscriptionHistoryItem]) {
        guard let data = try? encoder.encode(history) else { return }
        try? data.write(to: indexFile, options: .atomic)
    }
}

// MARK: - Supporting Types

/// Source of a transcription (dictation, file, URL, or meeting)
enum TranscriptionSource: Codable, Equatable {
    case dictation
    case file(fileName: String, filePath: String?)
    case url(urlString: String, platform: String?, videoTitle: String)
    case meeting(audioSource: String)

    var displayName: String {
        switch self {
        case .dictation:
            return "Voice Dictation"
        case .file(let fileName, _):
            return fileName
        case .url(_, _, let videoTitle):
            return videoTitle
        case .meeting(let audioSource):
            return "Meeting: \(audioSource)"
        }
    }

    var fileName: String? {
        switch self {
        case .dictation:
            return nil
        case .file(let fileName, _):
            return fileName
        case .url(_, _, let videoTitle):
            return videoTitle
        case .meeting(let audioSource):
            return audioSource
        }
    }

    var icon: String {
        switch self {
        case .dictation:
            return "mic.fill"
        case .file:
            return "doc.fill"
        case .url(_, let platform, _):
            // Return platform-specific icon
            switch platform?.lowercased() {
            case "youtube":
                return "play.rectangle.fill"
            case "vimeo":
                return "v.circle.fill"
            case "twitter", "x":
                return "bubble.left.fill"
            case "tiktok":
                return "music.note"
            default:
                return "link"
            }
        case .meeting:
            return "person.2.fill"
        }
    }

    /// Platform name for URL sources
    var platform: String? {
        switch self {
        case .url(_, let platform, _):
            return platform
        default:
            return nil
        }
    }

    /// Original URL string for URL sources
    var urlString: String? {
        switch self {
        case .url(let urlString, _, _):
            return urlString
        default:
            return nil
        }
    }

    /// Whether this is a URL source
    var isURL: Bool {
        if case .url = self { return true }
        return false
    }
}

/// Extended transcription item with history metadata
struct TranscriptionHistoryItem: Identifiable, Codable {
    let id: UUID
    var text: String
    var segments: [TranscriptionSegment]
    let language: String?
    let duration: TimeInterval
    let processingTime: TimeInterval
    let modelUsed: String
    let timestamp: Date
    let source: TranscriptionSource
    var isFavorite: Bool
    var tags: [String]
    var speakerMapping: SpeakerMapping?
    var isEdited: Bool = false
    var lastEditedAt: Date?

    /// Check if this item has speaker diarization
    var hasSpeakerDiarization: Bool {
        speakerMapping != nil && !(speakerMapping?.isEmpty ?? true) && segments.contains { $0.speakerId != nil }
    }

    /// Get all favorited segments in this item
    var favoritedSegments: [TranscriptionSegment] {
        segments.filter { $0.isFavorite }
    }

    /// Check if any segments are favorited
    var hasFavoritedSegments: Bool {
        segments.contains { $0.isFavorite }
    }

    /// Count of favorited segments
    var favoritedSegmentsCount: Int {
        segments.filter { $0.isFavorite }.count
    }

    var wordCount: Int {
        text.split(separator: " ").count
    }

    var preview: String {
        let maxLength = 150
        if text.count <= maxLength {
            return text
        }
        return String(text.prefix(maxLength)) + "..."
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return String(format: "0:%02d", seconds)
        }
    }

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }

    var relativeTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }

    /// Convert to basic TranscriptionResult for export
    func toTranscriptionResult() -> TranscriptionResult {
        TranscriptionResult(
            id: id,
            text: text,
            segments: segments,
            language: language,
            duration: duration,
            processingTime: processingTime,
            modelUsed: modelUsed,
            timestamp: timestamp,
            speakerMapping: speakerMapping,
            isEdited: isEdited,
            lastEditedAt: lastEditedAt
        )
    }

    // MARK: - Segment Editing

    /// Update a segment's text by UUID
    mutating func updateSegment(id segmentId: UUID, newText: String) {
        guard let index = segments.firstIndex(where: { $0.uuid == segmentId }) else { return }
        segments[index] = segments[index].withText(newText)
        recalculateText()
        markAsEdited()
    }

    /// Delete a segment by UUID
    mutating func deleteSegment(id segmentId: UUID) {
        segments.removeAll { $0.uuid == segmentId }
        // Re-index segments
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
        recalculateText()
        markAsEdited()
    }

    /// Merge a segment with the next one
    mutating func mergeSegmentWithNext(id segmentId: UUID) {
        guard let index = segments.firstIndex(where: { $0.uuid == segmentId }),
              index < segments.count - 1 else { return }

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

        // Re-index segments
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
        recalculateText()
        markAsEdited()
    }

    /// Toggle favorite status for a segment by UUID
    mutating func toggleSegmentFavorite(id segmentId: UUID) {
        guard let index = segments.firstIndex(where: { $0.uuid == segmentId }) else { return }
        segments[index] = segments[index].withFavoriteToggled()
        markAsEdited()
    }

    /// Set favorite status for a segment by UUID
    mutating func setSegmentFavorite(id segmentId: UUID, isFavorite: Bool) {
        guard let index = segments.firstIndex(where: { $0.uuid == segmentId }) else { return }
        segments[index] = segments[index].withFavorite(isFavorite)
        markAsEdited()
    }

    private mutating func recalculateText() {
        text = segments.map { $0.text.trimmingCharacters(in: .whitespaces) }.joined(separator: " ")
    }

    private mutating func markAsEdited() {
        isEdited = true
        lastEditedAt = Date()
    }
}

/// Information about a favorited segment including its parent transcription context
struct FavoritedSegmentInfo: Identifiable {
    var id: UUID { segment.uuid }
    let segment: TranscriptionSegment
    let transcriptionId: UUID
    let transcriptionTimestamp: Date
    let transcriptionSource: TranscriptionSource
    let speakerMapping: SpeakerMapping?

    /// Formatted timestamp of the parent transcription
    var formattedTranscriptionTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: transcriptionTimestamp)
    }

    /// Relative timestamp of the parent transcription
    var relativeTranscriptionTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: transcriptionTimestamp, relativeTo: Date())
    }
}

/// Statistics about transcription history
struct HistoryStatistics {
    let totalTranscriptions: Int
    let totalWords: Int
    let totalDuration: TimeInterval
    let transcriptionsToday: Int
    let wordsToday: Int
    let transcriptionsThisWeek: Int
    let wordsThisWeek: Int

    var formattedTotalDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
