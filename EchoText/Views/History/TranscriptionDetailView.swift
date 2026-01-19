import SwiftUI
import AppKit

/// Detail view for viewing and editing a transcription
struct TranscriptionDetailView: View {
    @State private var item: TranscriptionHistoryItem
    let onSave: (TranscriptionHistoryItem) -> Void
    let onDelete: () -> Void
    let onSaveSpeakerMapping: ((SpeakerMapping) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @State private var editedText: String
    @State private var isEditing = false
    @State private var showExportMenu = false
    @State private var showDeleteConfirmation = false
    @State private var showCopied = false
    @State private var selectedExportFormat: ExportFormat = .txt
    @State private var showSpeakerManager = false
    @State private var speakerMapping: SpeakerMapping
    @State private var hasChanges = false

    private let historyService = TranscriptionHistoryService.shared

    init(
        item: TranscriptionHistoryItem,
        onSave: @escaping (TranscriptionHistoryItem) -> Void,
        onDelete: @escaping () -> Void,
        onSaveSpeakerMapping: ((SpeakerMapping) -> Void)? = nil
    ) {
        self._item = State(initialValue: item)
        self.onSave = onSave
        self.onDelete = onDelete
        self.onSaveSpeakerMapping = onSaveSpeakerMapping
        self._editedText = State(initialValue: item.text)
        self._speakerMapping = State(initialValue: item.speakerMapping ?? SpeakerMapping())
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Metadata
                    metadataSection

                    Divider()

                    // Transcription text
                    transcriptionSection

                    // Segments (if available)
                    if !item.segments.isEmpty {
                        Divider()
                        segmentsSection
                    }
                }
                .padding(24)
            }

            Divider()

            // Footer
            footer
        }
        .frame(width: 600, height: 500)
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("Delete Transcription?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete()
                dismiss()
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .sheet(isPresented: $showSpeakerManager) {
            SpeakerManagerView(speakerMapping: $speakerMapping) { newMapping in
                onSaveSpeakerMapping?(newMapping)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: item.source.icon)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Text(item.source.displayName)
                        .font(.system(size: 14, weight: .semibold))
                }

                Text(item.formattedTimestamp)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Metadata Section

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 24) {
                metadataItem(
                    icon: "textformat.abc",
                    label: "Words",
                    value: "\(item.wordCount)"
                )

                metadataItem(
                    icon: "clock",
                    label: "Duration",
                    value: item.formattedDuration
                )

                metadataItem(
                    icon: "cpu",
                    label: "Model",
                    value: item.modelUsed
                )

                if let language = item.language {
                    metadataItem(
                        icon: "globe",
                        label: "Language",
                        value: language.uppercased()
                    )
                }

                // Favorited segments indicator
                if item.hasFavoritedSegments {
                    metadataItem(
                        icon: "star.fill",
                        label: "Starred",
                        value: "\(item.favoritedSegmentsCount)"
                    )
                }

                Spacer()
            }

            // Speaker legend (if diarization exists)
            if !speakerMapping.isEmpty {
                HStack(spacing: 12) {
                    SpeakerLegend(speakerMapping: speakerMapping)

                    Spacer()

                    Button {
                        showSpeakerManager = true
                    } label: {
                        Label("Edit Speakers", systemImage: "pencil")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(DesignSystem.Colors.accent)
                }
                .padding(.top, 4)
            }
        }
    }

    private func metadataItem(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(icon == "star.fill" ? DesignSystem.Colors.voiceSecondary : .secondary)

                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.system(size: 13, weight: .medium))
        }
    }

    // MARK: - Transcription Section

    private var transcriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Transcription")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                if isEditing {
                    Button("Cancel") {
                        editedText = item.text
                        isEditing = false
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                    Button("Save") {
                        item.text = editedText
                        hasChanges = true
                        saveChanges()
                        isEditing = false
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.accentColor)
                } else {
                    Button {
                        isEditing = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
            }

            if isEditing {
                TextEditor(text: $editedText)
                    .font(.system(size: 14))
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                    .frame(minHeight: 150)
            } else {
                Text(item.text)
                    .font(.system(size: 14))
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Segments Section

    private var segmentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Text("Segments")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)

                    Text("(\(item.segments.count))")
                        .font(.system(size: 12))
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))

                    if item.isEdited {
                        Text("Edited")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DesignSystem.Colors.accent.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    if item.hasFavoritedSegments {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                            Text("\(item.favoritedSegmentsCount)")
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.voiceSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(DesignSystem.Colors.voiceSecondary.opacity(0.15))
                        .clipShape(Capsule())
                    }
                }

                Spacer()

                if !speakerMapping.isEmpty {
                    Button {
                        showSpeakerManager = true
                    } label: {
                        Label("Edit Speakers", systemImage: "person.2")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(DesignSystem.Colors.accent)
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(item.segments.enumerated()), id: \.element.uuid) { index, segment in
                    EditableSegmentRow(
                        segment: segment,
                        speakerMapping: speakerMapping,
                        isCurrentSegment: false,
                        canMerge: index < item.segments.count - 1,
                        compactMode: appState.settings.compactMode,
                        onEdit: { newText in
                            updateSegment(segment.uuid, newText: newText)
                        },
                        onDelete: {
                            deleteSegment(segment.uuid)
                        },
                        onMergeWithNext: {
                            mergeSegment(segment.uuid)
                        },
                        onToggleFavorite: {
                            toggleSegmentFavorite(segment.uuid)
                        }
                    )

                    if index < item.segments.count - 1 {
                        Divider()
                            .padding(.horizontal, 12)
                    }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Segment Editing Methods

    private func updateSegment(_ segmentId: UUID, newText: String) {
        item.updateSegment(id: segmentId, newText: newText)
        editedText = item.text
        hasChanges = true
        saveChanges()
    }

    private func deleteSegment(_ segmentId: UUID) {
        item.deleteSegment(id: segmentId)
        editedText = item.text
        hasChanges = true
        saveChanges()
    }

    private func mergeSegment(_ segmentId: UUID) {
        item.mergeSegmentWithNext(id: segmentId)
        editedText = item.text
        hasChanges = true
        saveChanges()
    }

    private func toggleSegmentFavorite(_ segmentId: UUID) {
        item.toggleSegmentFavorite(id: segmentId)
        hasChanges = true
        saveChanges()
    }

    private func saveChanges() {
        historyService.update(item)
        onSave(item)
    }

    private func segmentTextColor(for segment: TranscriptionSegment) -> Color {
        if let speakerId = segment.speakerId, !speakerMapping.isEmpty {
            return DesignSystem.Colors.textPrimary
        }
        return DesignSystem.Colors.textPrimary
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            // Delete button
            Button {
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundColor(.red)

            Spacer()

            // Copy button
            Menu {
                Button {
                    ExportService.copyCleanText(item.toTranscriptionResult())
                    showCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showCopied = false
                    }
                } label: {
                    Label("Clean Text", systemImage: "text.alignleft")
                }

                Button {
                    ExportService.copyWithTimestamps(item.toTranscriptionResult())
                    showCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showCopied = false
                    }
                } label: {
                    Label("With Timestamps", systemImage: "clock")
                }
            } label: {
                Label(showCopied ? "Copied!" : "Copy", systemImage: showCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 12))
            }
            .menuStyle(.borderlessButton)
            .frame(width: 80)
            .foregroundColor(showCopied ? .green : .secondary)

            // Export menu
            Menu {
                ForEach(ExportFormat.allCases) { format in
                    Button {
                        Task {
                            await exportTranscription(format: format)
                        }
                    } label: {
                        Label(format.displayName, systemImage: "doc")
                    }
                }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
                    .font(.system(size: 12))
            }
            .menuStyle(.borderlessButton)
            .frame(width: 80)

            // Done button
            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func exportTranscription(format: ExportFormat) async {
        let result = item.toTranscriptionResult()
        _ = await ExportService.exportToFile(result, format: format)
    }
}

#Preview {
    TranscriptionDetailView(
        item: TranscriptionHistoryItem(
            id: UUID(),
            text: "This is a sample transcription text that demonstrates how the detail view looks with some content. It includes multiple sentences to show how the text wraps and displays.",
            segments: [
                TranscriptionSegment(id: 0, text: "This is a sample", startTime: 0, endTime: 2, speakerId: "speaker_0", isFavorite: true),
                TranscriptionSegment(id: 1, text: "transcription text", startTime: 2, endTime: 4, speakerId: "speaker_1", isFavorite: false)
            ],
            language: "en",
            duration: 15.5,
            processingTime: 2.3,
            modelUsed: "base",
            timestamp: Date(),
            source: .dictation,
            isFavorite: false,
            tags: [],
            speakerMapping: SpeakerMapping(speakers: [
                Speaker(id: "speaker_0", displayName: "John", colorIndex: 0),
                Speaker(id: "speaker_1", displayName: "Sarah", colorIndex: 1)
            ]),
            isEdited: false,
            lastEditedAt: nil
        ),
        onSave: { _ in },
        onDelete: {},
        onSaveSpeakerMapping: { _ in }
    )
    .environmentObject(AppState())
}
