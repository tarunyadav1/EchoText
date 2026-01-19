import Foundation
import AppKit
import UniformTypeIdentifiers
import PDFKit

/// Export options for configuring timestamp offset and other export parameters
struct ExportOptions {
    /// Timestamp offset in seconds (can be negative)
    var timestampOffset: TimeInterval = 0.0

    /// Whether timestamp offset is enabled
    var offsetEnabled: Bool = false

    /// Default export options with no modifications
    static let `default` = ExportOptions()

    /// Create options from app settings
    static func fromSettings(_ settings: AppSettings) -> ExportOptions {
        ExportOptions(
            timestampOffset: settings.timestampOffset,
            offsetEnabled: settings.alwaysApplyTimestampOffset && settings.timestampOffsetEnabled
        )
    }

    /// The effective offset to apply (0 if not enabled)
    var effectiveOffset: TimeInterval {
        offsetEnabled ? timestampOffset : 0.0
    }
}

/// Service responsible for exporting transcriptions to various formats
final class ExportService {
    // MARK: - Timestamp Offset Helper

    /// Apply timestamp offset to a time value, clamping to prevent negative timestamps
    /// - Parameters:
    ///   - time: The original time in seconds
    ///   - offset: The offset to apply (can be negative)
    /// - Returns: The adjusted time, clamped to a minimum of 0
    static func applyTimestampOffset(_ time: TimeInterval, offset: TimeInterval) -> TimeInterval {
        return max(0, time + offset)
    }

    // MARK: - Export Methods

    /// Export transcription to the specified format as Data
    /// Note: For .echotext format, use exportToEchoText() instead as it requires the media URL
    static func export(_ result: TranscriptionResult, format: ExportFormat, options: ExportOptions = .default) -> Data? {
        switch format {
        case .txt:
            return exportToTXT(result, options: options).data(using: .utf8)
        case .srt:
            return exportToSRT(result, options: options).data(using: .utf8)
        case .vtt:
            return exportToVTT(result, options: options).data(using: .utf8)
        case .md:
            return exportToMarkdown(result, options: options).data(using: .utf8)
        case .pdf:
            return exportToPDF(result, options: options)
        case .docx:
            return exportToDOCX(result, options: options)
        case .csv:
            return exportToCSV(result, options: options).data(using: .utf8)
        case .html:
            return exportToHTML(result, options: options).data(using: .utf8)
        case .json:
            return exportToJSON(result, options: options).data(using: .utf8)
        case .echotext:
            // .echotext requires media file, return nil for data-only export
            return nil
        }
    }

    /// Export and save to file with save panel
    @MainActor
    static func exportToFile(_ result: TranscriptionResult, format: ExportFormat, mediaURL: URL? = nil, options: ExportOptions = .default) async -> URL? {
        // Handle .echotext format specially
        if format == .echotext {
            return await exportToEchoTextFile(result, mediaURL: mediaURL)
        }

        guard let data = export(result, format: format, options: options) else { return nil }

        let savePanel = NSSavePanel()

        // Map ExportFormat to UTType
        let contentType: UTType
        switch format {
        case .txt, .srt, .vtt: contentType = .plainText
        case .md: contentType = UTType(tag: "md", tagClass: .filenameExtension, conformingTo: .plainText) ?? .plainText
        case .pdf: contentType = .pdf
        case .docx: contentType = UTType("org.openxmlformats.wordprocessingml.document") ?? .data
        case .csv: contentType = .commaSeparatedText
        case .html: contentType = .html
        case .json: contentType = .json
        case .echotext: contentType = UTType(filenameExtension: EchoTextDocument.fileExtension) ?? .data
        }

        savePanel.allowedContentTypes = [contentType]
        savePanel.nameFieldStringValue = "transcription.\(format.fileExtension)"
        savePanel.title = "Export Transcription"
        savePanel.message = "Choose where to save the transcription"

        guard savePanel.runModal() == .OK, let url = savePanel.url else {
            return nil
        }

        do {
            try data.write(to: url)
            return url
        } catch {
            print("Failed to save file: \(error)")
            return nil
        }
    }

    /// Export transcription to EchoText bundle format
    /// - Parameters:
    ///   - result: The transcription result
    ///   - mediaURL: URL to the original media file
    /// - Returns: URL where the document was saved, or nil if cancelled/failed
    @MainActor
    static func exportToEchoTextFile(_ result: TranscriptionResult, mediaURL: URL?) async -> URL? {
        guard let mediaURL = mediaURL else {
            print("Cannot export to .echotext without media URL")
            return nil
        }

        do {
            let document = try EchoTextDocument.create(from: result, mediaURL: mediaURL)
            return try await EchoTextDocumentService.shared.save(document)
        } catch {
            if (error as? CocoaError)?.code == .userCancelled {
                return nil
            }
            print("Failed to export .echotext: \(error)")
            return nil
        }
    }

    /// Export transcription to EchoText bundle at a specific URL
    /// - Parameters:
    ///   - result: The transcription result
    ///   - mediaURL: URL to the original media file
    ///   - destinationURL: Where to save the .echotext file
    static func exportToEchoText(_ result: TranscriptionResult, mediaURL: URL, destinationURL: URL) async throws {
        let document = try EchoTextDocument.create(from: result, mediaURL: mediaURL)
        _ = try await EchoTextDocumentService.shared.save(document, to: destinationURL)
    }

    /// Copy transcription to clipboard
    @MainActor
    static func copyToClipboard(_ result: TranscriptionResult, format: ExportFormat = .txt, options: ExportOptions = .default) {
        if let data = export(result, format: format, options: options), let content = String(data: data, encoding: .utf8) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(content, forType: .string)
        }
    }

    /// Copy clean text (no timestamps, no speakers)
    @MainActor
    static func copyCleanText(_ result: TranscriptionResult) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(result.text, forType: .string)
    }

    /// Copy with timestamps and speakers
    @MainActor
    static func copyWithTimestamps(_ result: TranscriptionResult, options: ExportOptions = .default) {
        let content = exportToTXT(result, includeTimestamps: true, options: options)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
    }

    // MARK: - Format Implementations

    private static func exportToTXT(_ result: TranscriptionResult, includeTimestamps: Bool = false, options: ExportOptions = .default) -> String {
        let offset = options.effectiveOffset

        // If no speaker diarization, return text
        guard let speakerMapping = result.speakerMapping, !speakerMapping.isEmpty else {
            if includeTimestamps {
                var output = ""
                for segment in result.segments {
                    let adjustedTime = applyTimestampOffset(segment.startTime, offset: offset)
                    output += "[\(formatDuration(adjustedTime))] \(segment.text.trimmingCharacters(in: .whitespacesAndNewlines))\n"
                }
                return output.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return result.text
        }

        // Group consecutive segments by speaker for cleaner output
        var output = ""
        var currentSpeakerId: String?

        for segment in result.segments {
            let speakerId = segment.speakerId

            if speakerId != currentSpeakerId {
                if let speakerId = speakerId {
                    let speakerName = speakerMapping.displayName(for: speakerId)
                    if !output.isEmpty {
                        output += "\n\n"
                    }
                    if includeTimestamps {
                        let adjustedTime = applyTimestampOffset(segment.startTime, offset: offset)
                        output += "[\(formatDuration(adjustedTime))] [\(speakerName)]:\n"
                    } else {
                        output += "[\(speakerName)]:\n"
                    }
                    currentSpeakerId = speakerId
                } else {
                    currentSpeakerId = nil
                }
            }

            output += segment.text.trimmingCharacters(in: .whitespacesAndNewlines) + " "
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func exportToSRT(_ result: TranscriptionResult, options: ExportOptions = .default) -> String {
        var srt = ""
        let speakerMapping = result.speakerMapping
        let offset = options.effectiveOffset

        for (index, segment) in result.segments.enumerated() {
            let adjustedStart = applyTimestampOffset(segment.startTime, offset: offset)
            let adjustedEnd = applyTimestampOffset(segment.endTime, offset: offset)

            srt += "\(index + 1)\n"
            srt += "\(formatSRTTime(adjustedStart)) --> \(formatSRTTime(adjustedEnd))\n"

            // Add speaker label if diarization exists
            if let speakerId = segment.speakerId, let mapping = speakerMapping, !mapping.isEmpty {
                let speakerName = mapping.displayName(for: speakerId)
                srt += "[\(speakerName)]: "
            }

            srt += "\(segment.text.trimmingCharacters(in: .whitespacesAndNewlines))\n\n"
        }

        return srt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func exportToVTT(_ result: TranscriptionResult, options: ExportOptions = .default) -> String {
        var vtt = "WEBVTT\n\n"
        let speakerMapping = result.speakerMapping
        let offset = options.effectiveOffset

        for segment in result.segments {
            let adjustedStart = applyTimestampOffset(segment.startTime, offset: offset)
            let adjustedEnd = applyTimestampOffset(segment.endTime, offset: offset)

            vtt += "\(formatVTTTime(adjustedStart)) --> \(formatVTTTime(adjustedEnd))\n"

            // Use WebVTT voice tag if diarization exists
            if let speakerId = segment.speakerId, let mapping = speakerMapping, !mapping.isEmpty {
                let speakerName = mapping.displayName(for: speakerId)
                vtt += "<v \(speakerName)>\(segment.text.trimmingCharacters(in: .whitespacesAndNewlines))\n\n"
            } else {
                vtt += "\(segment.text.trimmingCharacters(in: .whitespacesAndNewlines))\n\n"
            }
        }

        return vtt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func exportToMarkdown(_ result: TranscriptionResult, options: ExportOptions = .default) -> String {
        var md = "# Transcription\n\n"
        let speakerMapping = result.speakerMapping
        let offset = options.effectiveOffset

        // Metadata
        md += "**Date:** \(formatDate(result.timestamp))\n"
        md += "**Duration:** \(formatDuration(result.duration))\n"
        if let language = result.language {
            md += "**Language:** \(language)\n"
        }
        md += "**Model:** \(result.modelUsed)\n"

        // Timestamp offset info
        if options.offsetEnabled && offset != 0 {
            let sign = offset >= 0 ? "+" : ""
            md += "**Timestamp Offset:** \(sign)\(formatDuration(abs(offset)))\n"
        }

        // Speaker legend
        if let mapping = speakerMapping, !mapping.isEmpty {
            md += "**Speakers:** \(mapping.speakers.map { $0.displayName }.joined(separator: ", "))\n"
        }

        md += "\n---\n\n"

        // Content with speaker labels
        md += "## Content\n\n"

        if let mapping = speakerMapping, !mapping.isEmpty {
            // Format with speaker labels
            var currentSpeakerId: String?

            for segment in result.segments {
                let speakerId = segment.speakerId

                if speakerId != currentSpeakerId {
                    if let speakerId = speakerId {
                        let speakerName = mapping.displayName(for: speakerId)
                        if !md.hasSuffix("## Content\n\n") {
                            md += "\n\n"
                        }
                        md += "**\(speakerName):** "
                        currentSpeakerId = speakerId
                    } else {
                        currentSpeakerId = nil
                    }
                }

                md += segment.text.trimmingCharacters(in: .whitespacesAndNewlines) + " "
            }
            md += "\n\n"
        } else {
            md += result.text
            md += "\n\n"
        }

        // Segments (if available)
        if !result.segments.isEmpty {
            md += "---\n\n"
            md += "## Segments\n\n"

            for segment in result.segments {
                let adjustedTime = applyTimestampOffset(segment.startTime, offset: offset)
                var line = "- **[\(formatDuration(adjustedTime))]**"

                // Add speaker label if diarization exists
                if let speakerId = segment.speakerId, let mapping = speakerMapping, !mapping.isEmpty {
                    let speakerName = mapping.displayName(for: speakerId)
                    line += " _\(speakerName)_:"
                }

                line += " \(segment.text.trimmingCharacters(in: .whitespacesAndNewlines))\n"
                md += line
            }
        }

        return md
    }

    private static func createRichTranscription(_ result: TranscriptionResult, options: ExportOptions = .default) -> NSAttributedString {
        let attrString = NSMutableAttributedString()
        let speakerMapping = result.speakerMapping
        let offset = options.effectiveOffset

        // Title
        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 24)
        ]
        attrString.append(NSAttributedString(string: "Transcription\n\n", attributes: titleAttr))

        // Metadata
        let metaAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        attrString.append(NSAttributedString(string: "Date: \(formatDate(result.timestamp))\n", attributes: metaAttr))
        attrString.append(NSAttributedString(string: "Duration: \(formatDuration(result.duration))\n", attributes: metaAttr))

        // Timestamp offset info
        if options.offsetEnabled && offset != 0 {
            let sign = offset >= 0 ? "+" : ""
            attrString.append(NSAttributedString(string: "Timestamp Offset: \(sign)\(formatDuration(abs(offset)))\n", attributes: metaAttr))
        }

        attrString.append(NSAttributedString(string: "\n", attributes: metaAttr))

        // Content
        if let mapping = speakerMapping, !mapping.isEmpty {
            var currentSpeakerId: String?
            for segment in result.segments {
                if segment.speakerId != currentSpeakerId {
                    if let speakerId = segment.speakerId {
                        let speakerName = mapping.displayName(for: speakerId)
                        attrString.append(NSAttributedString(string: "\n\(speakerName):\n", attributes: [.font: NSFont.boldSystemFont(ofSize: 14)]))
                        currentSpeakerId = speakerId
                    }
                }
                attrString.append(NSAttributedString(string: segment.text.trimmingCharacters(in: .whitespacesAndNewlines) + " ", attributes: [.font: NSFont.systemFont(ofSize: 13)]))
            }
        } else {
            attrString.append(NSAttributedString(string: result.text, attributes: [.font: NSFont.systemFont(ofSize: 13)]))
        }

        return attrString
    }

    private static func exportToPDF(_ result: TranscriptionResult, options: ExportOptions = .default) -> Data? {
        let attrString = createRichTranscription(result, options: options)

        // Create a temporary text view to render the attributed string
        let width: CGFloat = 500
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: width, height: 1000))
        textView.textStorage?.setAttributedString(attrString)

        // Size to fit the content
        if let layoutManager = textView.layoutManager, let textContainer = textView.textContainer {
            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            textView.frame = NSRect(x: 0, y: 0, width: width, height: usedRect.height + 40)
        }

        return textView.dataWithPDF(inside: textView.bounds)
    }

    private static func exportToDOCX(_ result: TranscriptionResult, options: ExportOptions = .default) -> Data? {
        let attrString = createRichTranscription(result, options: options)
        do {
            let data = try attrString.data(from: NSMakeRange(0, attrString.length),
                                         documentAttributes: [.documentType: NSAttributedString.DocumentType.officeOpenXML])
            return data
        } catch {
            print("Failed to export DOCX: \(error)")
            return nil
        }
    }

    private static func exportToCSV(_ result: TranscriptionResult, options: ExportOptions = .default) -> String {
        var csv = "Start Time,End Time,Speaker,Text\n"
        let mapping = result.speakerMapping
        let offset = options.effectiveOffset

        for segment in result.segments {
            let adjustedStart = applyTimestampOffset(segment.startTime, offset: offset)
            let adjustedEnd = applyTimestampOffset(segment.endTime, offset: offset)
            let startTimestamp = formatDuration(adjustedStart)
            let endTimestamp = formatDuration(adjustedEnd)
            let speaker = mapping?.displayName(for: segment.speakerId ?? "unknown") ?? "Unknown"
            // Escape quotes in text
            let escapedText = segment.text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "\"\"")
            csv += "\(startTimestamp),\(endTimestamp),\"\(speaker)\",\"\(escapedText)\"\n"
        }
        return csv
    }

    private static func exportToHTML(_ result: TranscriptionResult, options: ExportOptions = .default) -> String {
        let mapping = result.speakerMapping
        let offset = options.effectiveOffset
        var content = ""

        if let mapping = mapping, !mapping.isEmpty {
            var currentSpeakerId: String?
            for segment in result.segments {
                if segment.speakerId != currentSpeakerId {
                    if let speakerId = segment.speakerId {
                        let speakerName = mapping.displayName(for: speakerId)
                        content += "<h3 class='speaker'>\(speakerName)</h3>"
                        currentSpeakerId = speakerId
                    }
                }
                let adjustedTime = applyTimestampOffset(segment.startTime, offset: offset)
                content += "<p class='segment' data-time='\(adjustedTime)'>\(segment.text.trimmingCharacters(in: .whitespacesAndNewlines))</p>"
            }
        } else {
            content = "<p>\(result.text)</p>"
        }

        // Timestamp offset note
        var offsetNote = ""
        if options.offsetEnabled && offset != 0 {
            let sign = offset >= 0 ? "+" : ""
            offsetNote = "<p class='offset-note'>Timestamp Offset: \(sign)\(formatDuration(abs(offset)))</p>"
        }

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>Transcription - \(formatDate(result.timestamp))</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; line-height: 1.6; max-width: 800px; margin: 40px auto; padding: 20px; color: #333; }
                h1 { border-bottom: 2px solid #eee; padding-bottom: 10px; }
                .metadata { color: #666; font-size: 0.9em; margin-bottom: 30px; }
                .offset-note { color: #007AFF; font-size: 0.85em; font-style: italic; }
                .speaker { margin-top: 30px; color: #007AFF; font-size: 1.1em; }
                .segment { margin-bottom: 10px; }
                @media (prefers-color-scheme: dark) {
                    body { background: #1a1a1a; color: #eee; }
                    .metadata { color: #aaa; }
                    .speaker { color: #0A84FF; }
                    .offset-note { color: #0A84FF; }
                }
            </style>
        </head>
        <body>
            <h1>Transcription</h1>
            <div class="metadata">
                <p>Date: \(formatDate(result.timestamp))</p>
                <p>Duration: \(formatDuration(result.duration))</p>
                \(offsetNote)
            </div>
            <div class="content">
                \(content)
            </div>
        </body>
        </html>
        """
    }

    private static func exportToJSON(_ result: TranscriptionResult, options: ExportOptions = .default) -> String {
        let offset = options.effectiveOffset

        // If no offset, just encode the result directly
        if !options.offsetEnabled || offset == 0 {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601

            do {
                let data = try encoder.encode(result)
                return String(data: data, encoding: .utf8) ?? "{}"
            } catch {
                print("Failed to export JSON: \(error)")
                return "{}"
            }
        }

        // Create adjusted segments for JSON export
        var adjustedSegments: [[String: Any]] = []
        for segment in result.segments {
            let adjustedStart = applyTimestampOffset(segment.startTime, offset: offset)
            let adjustedEnd = applyTimestampOffset(segment.endTime, offset: offset)

            var segmentDict: [String: Any] = [
                "id": segment.id,
                "text": segment.text,
                "startTime": adjustedStart,
                "endTime": adjustedEnd,
                "isFavorite": segment.isFavorite
            ]
            if let speakerId = segment.speakerId {
                segmentDict["speakerId"] = speakerId
            }
            adjustedSegments.append(segmentDict)
        }

        var jsonDict: [String: Any] = [
            "id": result.id.uuidString,
            "text": result.text,
            "segments": adjustedSegments,
            "duration": result.duration,
            "processingTime": result.processingTime,
            "modelUsed": result.modelUsed,
            "timestamp": ISO8601DateFormatter().string(from: result.timestamp),
            "isEdited": result.isEdited,
            "timestampOffset": offset
        ]

        if let language = result.language {
            jsonDict["language"] = language
        }
        if let lastEditedAt = result.lastEditedAt {
            jsonDict["lastEditedAt"] = ISO8601DateFormatter().string(from: lastEditedAt)
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: jsonDict, options: [.prettyPrinted, .sortedKeys])
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            print("Failed to export JSON with offset: \(error)")
            return "{}"
        }
    }

    // MARK: - Time Formatting

    private static func formatSRTTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)

        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, seconds, milliseconds)
    }

    private static func formatVTTTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)

        return String(format: "%02d:%02d:%02d.%03d", hours, minutes, seconds, milliseconds)
    }

    static func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return String(format: "0:%02d", seconds)
        }
    }

    /// Format duration with milliseconds for precise timestamp display
    static func formatDurationWithMilliseconds(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        let milliseconds = Int((duration.truncatingRemainder(dividingBy: 1)) * 1000)

        if hours > 0 {
            return String(format: "%02d:%02d:%02d.%03d", hours, minutes, seconds, milliseconds)
        } else {
            return String(format: "%02d:%02d.%03d", minutes, seconds, milliseconds)
        }
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Batch Export
extension ExportService {
    /// Export multiple transcriptions to a directory
    @MainActor
    static func exportBatch(_ results: [TranscriptionResult], format: ExportFormat, options: ExportOptions = .default) async -> URL? {
        // .echotext batch export is not supported through this method
        guard format != .echotext else {
            print("Use EchoTextDocumentService.saveBatch for .echotext batch export")
            return nil
        }

        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true
        openPanel.title = "Choose Export Directory"
        openPanel.message = "Select a folder to save all transcriptions"

        guard openPanel.runModal() == .OK, let directory = openPanel.url else {
            return nil
        }

        for (index, result) in results.enumerated() {
            guard let data = export(result, format: format, options: options) else { continue }
            let filename = "transcription_\(index + 1).\(format.fileExtension)"
            let fileURL = directory.appendingPathComponent(filename)

            try? data.write(to: fileURL)
        }

        return directory
    }

    /// Export multiple transcriptions with their media as EchoText bundles
    @MainActor
    static func exportBatchAsEchoText(_ items: [(result: TranscriptionResult, mediaURL: URL)]) async -> URL? {
        var documents: [EchoTextDocument] = []

        for (result, mediaURL) in items {
            do {
                let document = try EchoTextDocument.create(from: result, mediaURL: mediaURL)
                documents.append(document)
            } catch {
                print("Failed to create document for batch export: \(error)")
            }
        }

        guard !documents.isEmpty else { return nil }

        do {
            return try await EchoTextDocumentService.shared.saveBatch(documents)
        } catch {
            print("Failed to save batch: \(error)")
            return nil
        }
    }
}

// MARK: - Timestamp Offset Parsing Utilities
extension ExportService {
    /// Parse a timestamp offset string in various formats
    /// Supported formats:
    /// - Seconds: "5", "-5", "+5", "5.5"
    /// - MM:SS: "1:30", "-1:30", "+01:30"
    /// - HH:MM:SS: "1:30:00", "-01:30:00"
    /// - HH:MM:SS.mmm: "00:01:30.500"
    /// - Returns: TimeInterval in seconds, or nil if parsing failed
    static func parseTimestampOffset(_ input: String) -> TimeInterval? {
        var trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // Determine sign
        var isNegative = false
        if trimmed.hasPrefix("-") {
            isNegative = true
            trimmed = String(trimmed.dropFirst())
        } else if trimmed.hasPrefix("+") {
            trimmed = String(trimmed.dropFirst())
        }

        // Try parsing as simple number (seconds)
        if let seconds = Double(trimmed) {
            return isNegative ? -seconds : seconds
        }

        // Try parsing as timestamp format
        let components = trimmed.split(separator: ":")
        var totalSeconds: TimeInterval = 0

        switch components.count {
        case 2:
            // MM:SS or MM:SS.mmm
            guard let minutes = Int(components[0]) else { return nil }
            let secondsPart = String(components[1])
            guard let seconds = Double(secondsPart) else { return nil }
            totalSeconds = TimeInterval(minutes * 60) + seconds

        case 3:
            // HH:MM:SS or HH:MM:SS.mmm
            guard let hours = Int(components[0]),
                  let minutes = Int(components[1]) else { return nil }
            let secondsPart = String(components[2])
            guard let seconds = Double(secondsPart) else { return nil }
            totalSeconds = TimeInterval(hours * 3600 + minutes * 60) + seconds

        default:
            return nil
        }

        return isNegative ? -totalSeconds : totalSeconds
    }

    /// Format a timestamp offset for display
    /// - Parameter offset: The offset in seconds
    /// - Returns: Formatted string like "+00:05.000" or "-01:30.500"
    static func formatTimestampOffset(_ offset: TimeInterval) -> String {
        let sign = offset >= 0 ? "+" : "-"
        let absOffset = abs(offset)

        let hours = Int(absOffset) / 3600
        let minutes = (Int(absOffset) % 3600) / 60
        let seconds = Int(absOffset) % 60
        let milliseconds = Int((absOffset.truncatingRemainder(dividingBy: 1)) * 1000)

        if hours > 0 {
            return String(format: "%@%02d:%02d:%02d.%03d", sign, hours, minutes, seconds, milliseconds)
        } else {
            return String(format: "%@%02d:%02d.%03d", sign, minutes, seconds, milliseconds)
        }
    }
}
