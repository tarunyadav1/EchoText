import SwiftUI

/// A segment row component that supports highlighting during audio playback
/// and click-to-seek functionality
struct HighlightableSegmentRow: View {
    let segment: TranscriptionSegment
    let speakerMapping: SpeakerMapping?
    let isCurrentlyPlaying: Bool
    let fontSize: CGFloat
    let compactMode: Bool
    var onEdit: ((String) -> Void)?
    var onDelete: (() -> Void)?
    var onMergeWithNext: (() -> Void)?
    var onSeek: (() -> Void)?
    var onToggleFavorite: (() -> Void)?
    let canMerge: Bool

    @State private var isEditing = false
    @State private var editedText: String = ""
    @State private var isHovered = false
    @State private var showDeleteConfirmation = false
    @FocusState private var isTextFieldFocused: Bool

    init(
        segment: TranscriptionSegment,
        speakerMapping: SpeakerMapping? = nil,
        isCurrentlyPlaying: Bool = false,
        fontSize: CGFloat = 14,
        canMerge: Bool = false,
        compactMode: Bool = false,
        onEdit: ((String) -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onMergeWithNext: (() -> Void)? = nil,
        onSeek: (() -> Void)? = nil,
        onToggleFavorite: (() -> Void)? = nil
    ) {
        self.segment = segment
        self.speakerMapping = speakerMapping
        self.isCurrentlyPlaying = isCurrentlyPlaying
        self.fontSize = fontSize
        self.canMerge = canMerge
        self.compactMode = compactMode
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onMergeWithNext = onMergeWithNext
        self.onSeek = onSeek
        self.onToggleFavorite = onToggleFavorite
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Timestamp with play indicator
            if !compactMode {
                VStack(alignment: .trailing, spacing: 2) {
                    // Play indicator for current segment
                    if isCurrentlyPlaying {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 9))
                            .foregroundColor(DesignSystem.Colors.accent)
                            .transition(.scale.combined(with: .opacity))
                    }

                    Text(segment.formattedStartTime)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(isCurrentlyPlaying ? DesignSystem.Colors.accent : DesignSystem.Colors.textTertiary)
                }
                .frame(width: 60, alignment: .trailing)
                .animation(.easeInOut(duration: 0.2), value: isCurrentlyPlaying)
            }

            // Speaker badge if available
            if let speakerId = segment.speakerId, let mapping = speakerMapping {
                SpeakerBadgeFromMapping(speakerId: speakerId, speakerMapping: mapping)
            }

            // Content area
            VStack(alignment: .leading, spacing: 6) {
                if isEditing {
                    editingView
                } else {
                    displayView
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Favorite star button (visible on hover or when favorited)
            if !isEditing && (isHovered || segment.isFavorite) {
                favoriteButton
            }

            // Action buttons (visible on hover)
            if !isEditing && isHovered {
                actionButtons
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(backgroundView)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !isEditing {
                onSeek?()
            }
        }
        .alert("Delete Segment", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete?()
            }
        } message: {
            Text("Are you sure you want to delete this segment? This action cannot be undone.")
        }
    }

    // MARK: - Display View

    private var displayView: some View {
        Text(segment.text.trimmingCharacters(in: .whitespacesAndNewlines))
            .font(.system(size: fontSize))
            .foregroundColor(DesignSystem.Colors.textPrimary)
            .textSelection(.enabled)
            .lineSpacing(4)
    }

    // MARK: - Editing View

    private var editingView: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $editedText)
                .font(.system(size: fontSize))
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .frame(minHeight: 60, maxHeight: 200)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(DesignSystem.Colors.accent.opacity(0.5), lineWidth: 1)
                )
                .focused($isTextFieldFocused)

            HStack(spacing: 8) {
                Button("Cancel") {
                    cancelEditing()
                }
                .buttonStyle(SegmentEditButtonStyle(style: .secondary))

                Button("Save") {
                    saveEditing()
                }
                .buttonStyle(SegmentEditButtonStyle(style: .primary))
                .disabled(editedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()

                Text("\(editedText.split(separator: " ").count) words")
                    .font(.system(size: 11))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
        }
    }

    // MARK: - Favorite Button

    private var favoriteButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                onToggleFavorite?()
            }
        } label: {
            Image(systemName: segment.isFavorite ? "star.fill" : "star")
                .font(.system(size: 11))
                .foregroundColor(segment.isFavorite ? DesignSystem.Colors.voiceSecondary : DesignSystem.Colors.textTertiary)
                .frame(width: 24, height: 24)
                .background(segment.isFavorite ? DesignSystem.Colors.voiceSecondary.opacity(0.15) : Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .help(segment.isFavorite ? "Remove from favorites" : "Add to favorites")
        .transition(.opacity.combined(with: .scale(scale: 0.8)))
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 3) {
            // Seek button
            Button {
                onSeek?()
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 9))
                    .foregroundColor(DesignSystem.Colors.accent)
                    .frame(width: 24, height: 24)
                    .background(DesignSystem.Colors.accentSubtle)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            .help("Play from here")

            // Edit button
            Button {
                startEditing()
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 10))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .frame(width: 24, height: 24)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            .help("Edit segment")

            // Merge button (if not the last segment)
            if canMerge {
                Button {
                    onMergeWithNext?()
                } label: {
                    Image(systemName: "arrow.down.forward.and.arrow.up.backward")
                        .font(.system(size: 9))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .frame(width: 24, height: 24)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help("Merge with next segment")
            }

            // Delete button
            Button {
                showDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 10))
                    .foregroundColor(DesignSystem.Colors.error)
                    .frame(width: 24, height: 24)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            .help("Delete segment")
        }
    }

    // MARK: - Background

    @ViewBuilder
    private var backgroundView: some View {
        if isEditing {
            Color.primary.opacity(0.06)
        } else if isCurrentlyPlaying {
            // Highlighted background for currently playing segment
            DesignSystem.Colors.accent.opacity(0.12)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(DesignSystem.Colors.accent.opacity(0.5), lineWidth: 1.5)
                )
        } else if segment.isFavorite {
            DesignSystem.Colors.voiceSecondary.opacity(0.08)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(DesignSystem.Colors.voiceSecondary.opacity(0.15), lineWidth: 1)
                )
        } else if isHovered {
            Color.primary.opacity(0.04)
        } else {
            Color.clear
        }
    }

    // MARK: - Editing Methods

    private func startEditing() {
        editedText = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
        withAnimation(.easeInOut(duration: 0.2)) {
            isEditing = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isTextFieldFocused = true
        }
    }

    private func cancelEditing() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isEditing = false
        }
        editedText = ""
    }

    private func saveEditing() {
        let trimmedText = editedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        onEdit?(trimmedText)
        withAnimation(.easeInOut(duration: 0.2)) {
            isEditing = false
        }
        editedText = ""
    }
}

#Preview {
    VStack(spacing: 16) {
        HighlightableSegmentRow(
            segment: TranscriptionSegment(
                id: 0,
                text: "This is a sample transcription segment that can be edited or deleted.",
                startTime: 0.0,
                endTime: 5.5,
                isFavorite: false
            ),
            isCurrentlyPlaying: false,
            fontSize: 14,
            canMerge: true,
            compactMode: false
        )

        HighlightableSegmentRow(
            segment: TranscriptionSegment(
                id: 1,
                text: "This segment is currently playing and should be highlighted.",
                startTime: 5.5,
                endTime: 10.0,
                isFavorite: false
            ),
            isCurrentlyPlaying: true,
            fontSize: 14,
            canMerge: true,
            compactMode: false
        )

        HighlightableSegmentRow(
            segment: TranscriptionSegment(
                id: 2,
                text: "This segment is favorited.",
                startTime: 10.0,
                endTime: 15.0,
                isFavorite: true
            ),
            isCurrentlyPlaying: false,
            fontSize: 16,
            canMerge: false,
            compactMode: false
        )
    }
    .padding()
    .frame(width: 600)
}
