import Foundation
import SwiftUI
import Combine

/// View mode for displaying transcription content
enum HistoryDetailViewMode: String, CaseIterable {
    case transcript = "Transcript"
    case segments = "Segments"

    var icon: String {
        switch self {
        case .transcript: return "text.alignleft"
        case .segments: return "list.bullet"
        }
    }
}

/// ViewModel for the full-screen history detail view
@MainActor
final class HistoryDetailViewModel: ObservableObject {
    // MARK: - Published Properties

    /// The transcription item being viewed
    @Published var item: TranscriptionHistoryItem

    /// Current view mode (transcript vs segments)
    @Published var viewMode: HistoryDetailViewMode = .segments

    /// Font size for transcript display (12-24pt)
    @Published var fontSize: CGFloat = 14

    /// Whether to show only favorited segments
    @Published var showFavoritesOnly: Bool = false

    /// Whether to group consecutive segments from same speaker
    @Published var groupSegments: Bool = false

    /// Current segment index during playback
    @Published var currentSegmentIndex: Int?

    /// Speaker mapping for the item
    @Published var speakerMapping: SpeakerMapping

    /// Whether there are unsaved changes
    @Published var hasChanges: Bool = false

    /// Whether to show speaker manager sheet
    @Published var showSpeakerManager: Bool = false

    /// Whether to show delete confirmation
    @Published var showDeleteConfirmation: Bool = false

    /// Whether to show export menu
    @Published var showExportMenu: Bool = false

    /// Show copied feedback
    @Published var showCopied: Bool = false

    // MARK: - Dependencies

    private let historyService = TranscriptionHistoryService.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Callbacks

    var onSave: ((TranscriptionHistoryItem) -> Void)?
    var onDelete: (() -> Void)?
    var onDismiss: (() -> Void)?
    var onSaveSpeakerMapping: ((SpeakerMapping) -> Void)?

    // MARK: - Computed Properties

    /// Filtered segments based on favorites filter
    var displayedSegments: [TranscriptionSegment] {
        if showFavoritesOnly {
            return item.segments.filter { $0.isFavorite }
        }
        return item.segments
    }

    /// Full transcript text
    var transcriptText: String {
        item.text
    }

    /// Audio file URL if available
    var audioFileURL: URL? {
        switch item.source {
        case .file(_, let filePath):
            if let path = filePath {
                return URL(fileURLWithPath: path)
            }
            return nil
        case .dictation:
            // Dictation recordings might be stored in a specific location
            // For now, return nil - could be enhanced to look for cached audio
            return nil
        case .url(_, _, _):
            // URL downloads would need to be cached
            return nil
        case .meeting:
            // Meeting recordings are not typically saved to disk
            return nil
        }
    }

    /// Whether audio playback is available
    var canPlayAudio: Bool {
        audioFileURL != nil
    }

    // MARK: - Initialization

    init(item: TranscriptionHistoryItem) {
        self.item = item
        self.speakerMapping = item.speakerMapping ?? SpeakerMapping()
    }

    // MARK: - Segment Sync with Playback

    /// Find the segment index for the current playback time
    func currentSegmentIndex(for currentTime: TimeInterval) -> Int? {
        item.segments.firstIndex { segment in
            currentTime >= segment.startTime && currentTime < segment.endTime
        }
    }

    /// Update current segment index based on playback time
    func updateCurrentSegment(for currentTime: TimeInterval) {
        currentSegmentIndex = currentSegmentIndex(for: currentTime)
    }

    // MARK: - Segment Editing

    func updateSegment(_ segmentId: UUID, newText: String) {
        item.updateSegment(id: segmentId, newText: newText)
        hasChanges = true
        saveChanges()
    }

    func deleteSegment(_ segmentId: UUID) {
        item.deleteSegment(id: segmentId)
        hasChanges = true
        saveChanges()
    }

    func mergeSegment(_ segmentId: UUID) {
        item.mergeSegmentWithNext(id: segmentId)
        hasChanges = true
        saveChanges()
    }

    func toggleSegmentFavorite(_ segmentId: UUID) {
        item.toggleSegmentFavorite(id: segmentId)
        hasChanges = true
        saveChanges()
    }

    // MARK: - Actions

    func saveChanges() {
        historyService.update(item)
        onSave?(item)
    }

    func deleteItem() {
        historyService.delete(item)
        onDelete?()
    }

    func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.text, forType: .string)
        showCopied = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.showCopied = false
        }
    }

    func copyCleanText() {
        ExportService.copyCleanText(item.toTranscriptionResult())
        showCopied = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.showCopied = false
        }
    }

    func copyWithTimestamps() {
        ExportService.copyWithTimestamps(item.toTranscriptionResult())
        showCopied = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.showCopied = false
        }
    }

    func exportTranscription(format: ExportFormat) async {
        let result = item.toTranscriptionResult()
        _ = await ExportService.exportToFile(result, format: format)
    }

    func toggleFavorite() {
        item.isFavorite.toggle()
        hasChanges = true
        saveChanges()
    }

    func saveSpeakerMapping(_ newMapping: SpeakerMapping) {
        speakerMapping = newMapping
        item.speakerMapping = newMapping
        hasChanges = true
        saveChanges()
        onSaveSpeakerMapping?(newMapping)
    }

    func dismiss() {
        onDismiss?()
    }
}
