import Foundation

/// Service for removing filler words, silence markers, and filtering transcription segments
final class FillerWordService {

    // MARK: - Singleton
    static let shared = FillerWordService()

    private init() {}

    // MARK: - Silence and Blank Patterns

    /// Common silence/blank patterns that Whisper may output
    static let silencePatterns: Set<String> = [
        "[SILENCE]",
        "[BLANK_AUDIO]",
        "[BLANK]",
        "[INAUDIBLE]",
        "[MUSIC]",
        "[APPLAUSE]",
        "[LAUGHTER]",
        "[NOISE]",
        "[BACKGROUND_NOISE]",
        "[STATIC]",
        "[COUGHING]",
        "[BREATHING]",
        "[PAUSE]",
        "[NO_SPEECH]",
        "(silence)",
        "(inaudible)",
        "(music)",
        "(applause)",
        "(laughter)",
        "...",
        "*silence*",
        "*inaudible*",
        "*music*",
    ]

    /// Regex patterns for matching silence/blank markers (case insensitive)
    private static let silenceRegexPatterns: [String] = [
        #"^\s*\[.*?(SILENCE|BLANK|INAUDIBLE|MUSIC|APPLAUSE|LAUGHTER|NOISE|STATIC|COUGHING|BREATHING|PAUSE|NO_SPEECH).*?\]\s*$"#,
        #"^\s*\(.*?(silence|inaudible|music|applause|laughter).*?\)\s*$"#,
        #"^\s*\*.*?(silence|inaudible|music).*?\*\s*$"#,
        #"^\s*\.{3,}\s*$"#,  // Just ellipsis
        #"^\s*\[.*?\]\s*$"#, // Any bracketed marker with only brackets
    ]

    // MARK: - Filler Word Patterns

    /// Common English filler words and speech disfluencies
    private let fillerWords: Set<String> = [
        // Hesitation sounds
        "um", "uh", "umm", "uhh", "er", "err", "ah", "ahh", "eh",
        "hmm", "hm", "mm", "mmm", "mhm", "uh-huh", "uh huh",

        // Thinking fillers
        "like", "you know", "i mean", "right", "okay", "so",
        "well", "actually", "basically", "literally", "honestly",
        "seriously", "obviously", "clearly", "essentially",

        // Repetition starters
        "i i", "the the", "a a", "to to", "and and", "but but",
        "that that", "it it", "is is", "was was", "we we", "they they",

        // False starts (common patterns)
        "sort of", "kind of", "kinda", "sorta",

        // Verbal tics
        "you see", "i guess", "i suppose", "i think",
    ]

    /// Patterns that should only be removed when standalone (not part of meaningful sentences)
    private let conditionalFillers: Set<String> = [
        "like", "so", "right", "okay", "well", "actually",
        "basically", "literally", "honestly", "seriously",
        "obviously", "clearly", "essentially"
    ]

    /// Pure filler sounds that should always be removed
    private let alwaysRemoveFillers: Set<String> = [
        "um", "uh", "umm", "uhh", "er", "err", "ah", "ahh", "eh",
        "hmm", "hm", "mm", "mmm", "mhm", "uh-huh", "uh huh"
    ]

    // MARK: - Segment Filtering

    /// Filter segments based on settings
    /// - Parameters:
    ///   - segments: The original transcription segments
    ///   - filterSilence: Whether to filter out silence markers
    ///   - filterFillers: Whether to filter out segments that are only filler words
    ///   - customPatterns: Custom regex patterns to filter
    /// - Returns: Filtered array of segments
    func filterSegments(
        _ segments: [TranscriptionSegment],
        filterSilence: Bool = false,
        filterFillers: Bool = false,
        customPatterns: [String] = []
    ) -> [TranscriptionSegment] {
        guard filterSilence || filterFillers || !customPatterns.isEmpty else {
            return segments
        }

        return segments.filter { segment in
            let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)

            // Skip empty segments
            if text.isEmpty {
                return false
            }

            // Filter silence markers
            if filterSilence && isSilenceMarker(text) {
                return false
            }

            // Filter filler-only segments
            if filterFillers && isFillerOnlySegment(text) {
                return false
            }

            // Filter by custom patterns
            if !customPatterns.isEmpty && matchesCustomPatterns(text, patterns: customPatterns) {
                return false
            }

            return true
        }
    }

    /// Check if text is a silence/blank marker
    /// - Parameter text: The segment text to check
    /// - Returns: True if the text matches a known silence pattern
    func isSilenceMarker(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let uppercased = trimmed.uppercased()

        // Check exact matches first
        if Self.silencePatterns.contains(trimmed) || Self.silencePatterns.contains(uppercased) {
            return true
        }

        // Check case-insensitive patterns in the silence set
        for pattern in Self.silencePatterns {
            if trimmed.caseInsensitiveCompare(pattern) == .orderedSame {
                return true
            }
        }

        // Check regex patterns
        for pattern in Self.silenceRegexPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(trimmed.startIndex..., in: trimmed)
                if regex.firstMatch(in: trimmed, options: [], range: range) != nil {
                    return true
                }
            }
        }

        return false
    }

    /// Check if a segment contains only filler words
    /// - Parameter text: The segment text to check
    /// - Returns: True if the segment is only filler content
    func isFillerOnlySegment(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Remove punctuation for comparison
        let cleanedText = trimmed.components(separatedBy: CharacterSet.punctuationCharacters).joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)

        // Check if it's just a single filler word
        if alwaysRemoveFillers.contains(cleanedText) {
            return true
        }

        // Check if all words in the segment are fillers
        let words = cleanedText.split(separator: " ").map { String($0).lowercased() }
        if words.isEmpty {
            return true
        }

        // If all words are filler words, filter the segment
        let nonFillerWords = words.filter { word in
            !alwaysRemoveFillers.contains(word) && word.count > 1
        }

        return nonFillerWords.isEmpty
    }

    /// Check if text matches any custom filter patterns
    /// - Parameters:
    ///   - text: The text to check
    ///   - patterns: Array of regex patterns
    /// - Returns: True if any pattern matches
    func matchesCustomPatterns(_ text: String, patterns: [String]) -> Bool {
        for pattern in patterns {
            guard !pattern.isEmpty else { continue }

            // Try as regex first
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(text.startIndex..., in: text)
                if regex.firstMatch(in: text, options: [], range: range) != nil {
                    return true
                }
            } else {
                // Fall back to simple string containment
                if text.localizedCaseInsensitiveContains(pattern) {
                    return true
                }
            }
        }
        return false
    }

    // MARK: - Text Filler Removal (Original Methods)

    /// Remove filler words from text
    /// - Parameter text: The transcribed text
    /// - Returns: Text with filler words removed
    func removeFillers(from text: String) -> String {
        var result = text

        // First pass: Remove pure filler sounds (always remove these)
        result = removePureFillers(from: result)

        // Second pass: Remove conditional fillers when they appear as standalone
        result = removeConditionalFillers(from: result)

        // Third pass: Remove repeated words (stuttering)
        result = removeRepeatedWords(from: result)

        // Clean up extra whitespace and punctuation issues
        result = cleanupText(result)

        return result
    }

    /// Remove filler words from a transcription segment
    /// - Parameter segment: The transcription segment
    /// - Returns: Segment with cleaned text
    func removeFillers(from segment: TranscriptionSegment) -> TranscriptionSegment {
        let cleanedText = removeFillers(from: segment.text)
        return TranscriptionSegment(
            id: segment.id,
            uuid: segment.uuid,
            text: cleanedText,
            startTime: segment.startTime,
            endTime: segment.endTime,
            speakerId: segment.speakerId,
            isFavorite: segment.isFavorite
        )
    }

    // MARK: - Private Methods

    /// Remove pure filler sounds like "um", "uh", etc.
    private func removePureFillers(from text: String) -> String {
        var result = text

        for filler in alwaysRemoveFillers {
            // Match filler words at word boundaries (case insensitive)
            // Handle various punctuation around the filler
            let patterns = [
                // Filler at start of sentence or after punctuation
                "(?i)(?<=^|[.!?]\\s)\\b\(NSRegularExpression.escapedPattern(for: filler))\\b[,.]?\\s*",
                // Filler in middle of sentence (with comma)
                "(?i)\\b\(NSRegularExpression.escapedPattern(for: filler))\\b,?\\s+",
                // Standalone filler
                "(?i)\\s+\\b\(NSRegularExpression.escapedPattern(for: filler))\\b\\s+"
            ]

            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                    result = regex.stringByReplacingMatches(
                        in: result,
                        options: [],
                        range: NSRange(result.startIndex..., in: result),
                        withTemplate: " "
                    )
                }
            }
        }

        return result
    }

    /// Remove conditional fillers when they appear as standalone or at sentence boundaries
    private func removeConditionalFillers(from text: String) -> String {
        var result = text

        for filler in conditionalFillers {
            // Only remove when:
            // 1. At the very start of a sentence/text
            // 2. After a comma (as a verbal tic)
            // 3. Before a comma followed by more text

            let patterns = [
                // "Like," at start of sentence
                "(?i)(?<=^|[.!?]\\s)\\b\(NSRegularExpression.escapedPattern(for: filler))\\b,\\s+",
                // ", like," in middle (verbal tic pattern)
                "(?i),\\s*\\b\(NSRegularExpression.escapedPattern(for: filler))\\b,\\s*",
                // "So," at start
                "(?i)^\\b\(NSRegularExpression.escapedPattern(for: filler))\\b,\\s+"
            ]

            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                    let replacement = pattern.contains("^") ? "" : " "
                    result = regex.stringByReplacingMatches(
                        in: result,
                        options: [],
                        range: NSRange(result.startIndex..., in: result),
                        withTemplate: replacement
                    )
                }
            }
        }

        return result
    }

    /// Remove repeated words (stuttering patterns)
    private func removeRepeatedWords(from text: String) -> String {
        var result = text

        // Pattern to match repeated words: "I I", "the the", etc.
        // Matches word repeated 2+ times with optional comma/space between
        let pattern = "(?i)\\b(\\w+)\\b(?:[,\\s]+\\1\\b)+"

        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "$1"
            )
        }

        return result
    }

    /// Clean up extra whitespace and fix punctuation issues
    private func cleanupText(_ text: String) -> String {
        var result = text

        // Replace multiple spaces with single space
        if let regex = try? NSRegularExpression(pattern: "\\s{2,}", options: []) {
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: " "
            )
        }

        // Fix double punctuation (e.g., ",," -> ",")
        if let regex = try? NSRegularExpression(pattern: "([,.]){2,}", options: []) {
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "$1"
            )
        }

        // Remove space before punctuation
        if let regex = try? NSRegularExpression(pattern: "\\s+([,.])", options: []) {
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "$1"
            )
        }

        // Ensure space after punctuation (except at end)
        if let regex = try? NSRegularExpression(pattern: "([,.])(?=[A-Za-z])", options: []) {
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "$1 "
            )
        }

        // Capitalize first letter after period
        if let regex = try? NSRegularExpression(pattern: "([.!?])\\s+([a-z])", options: []) {
            let matches = regex.matches(in: result, options: [], range: NSRange(result.startIndex..., in: result))

            // Process matches in reverse order to maintain correct indices
            for match in matches.reversed() {
                if let range = Range(match.range(at: 2), in: result) {
                    let char = result[range].uppercased()
                    result.replaceSubrange(range, with: char)
                }
            }
        }

        // Trim leading/trailing whitespace
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        // Capitalize first letter of text
        if let first = result.first, first.isLowercase {
            result = result.prefix(1).uppercased() + result.dropFirst()
        }

        return result
    }
}

// MARK: - Statistics Extension

extension FillerWordService {
    /// Count filler words in text (for analytics)
    func countFillers(in text: String) -> Int {
        var count = 0
        let lowercased = text.lowercased()
        let words = lowercased.components(separatedBy: .whitespacesAndNewlines)

        for word in words {
            let cleaned = word.trimmingCharacters(in: .punctuationCharacters)
            if alwaysRemoveFillers.contains(cleaned) {
                count += 1
            }
        }

        return count
    }

    /// Count silence markers in segments
    func countSilenceMarkers(in segments: [TranscriptionSegment]) -> Int {
        return segments.filter { isSilenceMarker($0.text) }.count
    }

    /// Get statistics about filler word removal
    func getRemovalStats(original: String, cleaned: String) -> FillerRemovalStats {
        let originalWords = original.split(separator: " ").count
        let cleanedWords = cleaned.split(separator: " ").count
        let removedCount = originalWords - cleanedWords
        let fillerCount = countFillers(in: original)

        return FillerRemovalStats(
            originalWordCount: originalWords,
            cleanedWordCount: cleanedWords,
            fillersRemoved: fillerCount,
            totalWordsRemoved: removedCount
        )
    }

    /// Get filtering statistics for segments
    func getFilteringStats(
        original: [TranscriptionSegment],
        filtered: [TranscriptionSegment]
    ) -> SegmentFilteringStats {
        let silenceCount = countSilenceMarkers(in: original)
        let fillerOnlyCount = original.filter { isFillerOnlySegment($0.text) }.count

        return SegmentFilteringStats(
            originalSegmentCount: original.count,
            filteredSegmentCount: filtered.count,
            silenceMarkersRemoved: silenceCount,
            fillerSegmentsRemoved: fillerOnlyCount
        )
    }
}

/// Statistics about filler word removal
struct FillerRemovalStats {
    let originalWordCount: Int
    let cleanedWordCount: Int
    let fillersRemoved: Int
    let totalWordsRemoved: Int

    var percentageRemoved: Double {
        guard originalWordCount > 0 else { return 0 }
        return Double(totalWordsRemoved) / Double(originalWordCount) * 100
    }
}

/// Statistics about segment filtering
struct SegmentFilteringStats {
    let originalSegmentCount: Int
    let filteredSegmentCount: Int
    let silenceMarkersRemoved: Int
    let fillerSegmentsRemoved: Int

    var totalSegmentsRemoved: Int {
        originalSegmentCount - filteredSegmentCount
    }

    var percentageRemoved: Double {
        guard originalSegmentCount > 0 else { return 0 }
        return Double(totalSegmentsRemoved) / Double(originalSegmentCount) * 100
    }
}

// MARK: - TranscriptionResult Extension for Filtered Display

extension TranscriptionResult {
    /// Get filtered segments based on settings
    /// - Parameters:
    ///   - filterSilence: Whether to filter out silence markers
    ///   - filterFillers: Whether to filter out filler-only segments
    ///   - customPatterns: Custom regex patterns to filter
    /// - Returns: Filtered array of segments (original data is preserved)
    func filteredSegments(
        filterSilence: Bool = false,
        filterFillers: Bool = false,
        customPatterns: [String] = []
    ) -> [TranscriptionSegment] {
        return FillerWordService.shared.filterSegments(
            segments,
            filterSilence: filterSilence,
            filterFillers: filterFillers,
            customPatterns: customPatterns
        )
    }

    /// Get filtered text (combined from filtered segments)
    /// - Parameters:
    ///   - filterSilence: Whether to filter out silence markers
    ///   - filterFillers: Whether to filter out filler-only segments
    ///   - customPatterns: Custom regex patterns to filter
    /// - Returns: Combined text from filtered segments
    func filteredText(
        filterSilence: Bool = false,
        filterFillers: Bool = false,
        customPatterns: [String] = []
    ) -> String {
        let filtered = filteredSegments(
            filterSilence: filterSilence,
            filterFillers: filterFillers,
            customPatterns: customPatterns
        )
        return filtered.map { $0.text.trimmingCharacters(in: .whitespaces) }.joined(separator: " ")
    }

    /// Check if result has any silence markers
    var hasSilenceMarkers: Bool {
        segments.contains { FillerWordService.shared.isSilenceMarker($0.text) }
    }

    /// Count of silence markers in the result
    var silenceMarkerCount: Int {
        FillerWordService.shared.countSilenceMarkers(in: segments)
    }
}
