import Foundation
import AppKit

/// Service responsible for exporting transcriptions to various formats
final class ExportService {
    // MARK: - Export Methods

    /// Export transcription to the specified format
    static func export(_ result: TranscriptionResult, format: ExportFormat) -> String {
        switch format {
        case .txt:
            return exportToTXT(result)
        case .srt:
            return exportToSRT(result)
        case .vtt:
            return exportToVTT(result)
        case .md:
            return exportToMarkdown(result)
        }
    }

    /// Export and save to file with save panel
    @MainActor
    static func exportToFile(_ result: TranscriptionResult, format: ExportFormat) async -> URL? {
        let content = export(result, format: format)

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "transcription.\(format.fileExtension)"
        savePanel.title = "Export Transcription"
        savePanel.message = "Choose where to save the transcription"

        guard savePanel.runModal() == .OK, let url = savePanel.url else {
            return nil
        }

        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            print("Failed to save file: \(error)")
            return nil
        }
    }

    /// Copy transcription to clipboard
    @MainActor
    static func copyToClipboard(_ result: TranscriptionResult, format: ExportFormat = .txt) {
        let content = export(result, format: format)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
    }

    // MARK: - Format Implementations

    private static func exportToTXT(_ result: TranscriptionResult) -> String {
        return result.text
    }

    private static func exportToSRT(_ result: TranscriptionResult) -> String {
        var srt = ""

        for (index, segment) in result.segments.enumerated() {
            srt += "\(index + 1)\n"
            srt += "\(formatSRTTime(segment.startTime)) --> \(formatSRTTime(segment.endTime))\n"
            srt += "\(segment.text.trimmingCharacters(in: .whitespacesAndNewlines))\n\n"
        }

        return srt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func exportToVTT(_ result: TranscriptionResult) -> String {
        var vtt = "WEBVTT\n\n"

        for segment in result.segments {
            vtt += "\(formatVTTTime(segment.startTime)) --> \(formatVTTTime(segment.endTime))\n"
            vtt += "\(segment.text.trimmingCharacters(in: .whitespacesAndNewlines))\n\n"
        }

        return vtt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func exportToMarkdown(_ result: TranscriptionResult) -> String {
        var md = "# Transcription\n\n"

        // Metadata
        md += "**Date:** \(formatDate(result.timestamp))\n"
        md += "**Duration:** \(formatDuration(result.duration))\n"
        if let language = result.language {
            md += "**Language:** \(language)\n"
        }
        md += "**Model:** \(result.modelUsed)\n\n"

        md += "---\n\n"

        // Content
        md += "## Content\n\n"
        md += result.text
        md += "\n\n"

        // Segments (if available)
        if !result.segments.isEmpty {
            md += "---\n\n"
            md += "## Segments\n\n"

            for segment in result.segments {
                md += "- **[\(formatDuration(segment.startTime))]** \(segment.text.trimmingCharacters(in: .whitespacesAndNewlines))\n"
            }
        }

        return md
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

    private static func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60

        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return String(format: "0:%02d", seconds)
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
    static func exportBatch(_ results: [TranscriptionResult], format: ExportFormat) async -> URL? {
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
            let content = export(result, format: format)
            let filename = "transcription_\(index + 1).\(format.fileExtension)"
            let fileURL = directory.appendingPathComponent(filename)

            try? content.write(to: fileURL, atomically: true, encoding: .utf8)
        }

        return directory
    }
}
