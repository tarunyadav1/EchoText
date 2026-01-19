import SwiftUI

/// A row component for displaying and editing a transcription segment
struct EditableSegmentRow: View {
    let segment: TranscriptionSegment
    let speakerMapping: SpeakerMapping?
    let isCurrentSegment: Bool
    let compactMode: Bool
    var onEdit: ((String) -> Void)?
    var onDelete: (() -> Void)?
    var onMergeWithNext: (() -> Void)?
    var onTap: (() -> Void)?
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
        isCurrentSegment: Bool = false,
        canMerge: Bool = false,
        compactMode: Bool = false,
        onEdit: ((String) -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onMergeWithNext: (() -> Void)? = nil,
        onTap: (() -> Void)? = nil,
        onToggleFavorite: (() -> Void)? = nil
    ) {
        self.segment = segment
        self.speakerMapping = speakerMapping
        self.isCurrentSegment = isCurrentSegment
        self.canMerge = canMerge
        self.compactMode = compactMode
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onMergeWithNext = onMergeWithNext
        self.onTap = onTap
        self.onToggleFavorite = onToggleFavorite
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timestamp (hidden in compact mode)
            if !compactMode {
                Text(segment.formattedStartTime)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                    .frame(width: 70, alignment: .trailing)
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

            // Action buttons (visible on hover or when editing)
            if !isEditing && (isHovered || isCurrentSegment) {
                actionButtons
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
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
                onTap?()
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
            .font(.system(size: 14))
            .foregroundColor(DesignSystem.Colors.textPrimary)
            .textSelection(.enabled)
            .lineSpacing(4)
    }

    // MARK: - Editing View

    private var editingView: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $editedText)
                .font(.system(size: 14))
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
                .font(.system(size: 12))
                .foregroundColor(segment.isFavorite ? DesignSystem.Colors.voiceSecondary : DesignSystem.Colors.textSecondary)
                .frame(width: 28, height: 28)
                .background(segment.isFavorite ? DesignSystem.Colors.voiceSecondary.opacity(0.15) : Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help(segment.isFavorite ? "Remove from favorites" : "Add to favorites")
        .transition(.opacity.combined(with: .scale(scale: 0.8)))
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 4) {
            // Edit button
            Button {
                startEditing()
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("Edit segment")

            // Merge button (if not the last segment)
            if canMerge {
                Button {
                    onMergeWithNext?()
                } label: {
                    Image(systemName: "arrow.down.forward.and.arrow.up.backward")
                        .font(.system(size: 11))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Merge with next segment")
            }

            // Delete button
            Button {
                showDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.Colors.error)
                    .frame(width: 28, height: 28)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("Delete segment")
        }
    }

    // MARK: - Background

    @ViewBuilder
    private var backgroundView: some View {
        if isEditing {
            Color(nsColor: .controlBackgroundColor)
        } else if isCurrentSegment {
            DesignSystem.Colors.accentSubtle
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(DesignSystem.Colors.accent.opacity(0.3), lineWidth: 1)
                )
        } else if segment.isFavorite {
            DesignSystem.Colors.voiceSecondary.opacity(0.08)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(DesignSystem.Colors.voiceSecondary.opacity(0.2), lineWidth: 1)
                )
        } else if isHovered {
            Color(nsColor: .controlBackgroundColor).opacity(0.5)
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

// MARK: - Button Styles

struct SegmentEditButtonStyle: ButtonStyle {
    enum Style {
        case primary
        case secondary
    }

    let style: Style

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(style == .primary ? .white : DesignSystem.Colors.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                style == .primary
                    ? DesignSystem.Colors.accent
                    : Color(nsColor: .controlBackgroundColor)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

// MARK: - Compact Segment Row (for file transcription)

struct CompactEditableSegmentRow: View {
    let segment: TranscriptionSegment
    let isCurrentSegment: Bool
    let isPlaying: Bool
    let compactMode: Bool
    var onEdit: ((String) -> Void)?
    var onDelete: (() -> Void)?
    var onTap: (() -> Void)?
    var onToggleFavorite: (() -> Void)?

    @State private var isEditing = false
    @State private var editedText: String = ""
    @State private var isHovered = false
    @State private var showDeleteConfirmation = false

    init(
        segment: TranscriptionSegment,
        isCurrentSegment: Bool = false,
        isPlaying: Bool = false,
        compactMode: Bool = false,
        onEdit: ((String) -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onTap: (() -> Void)? = nil,
        onToggleFavorite: (() -> Void)? = nil
    ) {
        self.segment = segment
        self.isCurrentSegment = isCurrentSegment
        self.isPlaying = isPlaying
        self.compactMode = compactMode
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onTap = onTap
        self.onToggleFavorite = onToggleFavorite
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timestamp (hidden in compact mode)
            if !compactMode {
                Text(formatTime(segment.startTime))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                    .frame(width: 50, alignment: .trailing)
            }

            // Playing indicator
            if isPlaying && isCurrentSegment {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.Colors.accent)
                    .frame(width: 16)
            } else {
                Color.clear.frame(width: 16)
            }

            // Text content or editing
            if isEditing {
                editingView
            } else {
                Text(segment.text)
                    .font(.system(size: 14))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }

            // Favorite button (visible on hover or when favorited)
            if !isEditing && (isHovered || segment.isFavorite) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        onToggleFavorite?()
                    }
                } label: {
                    Image(systemName: segment.isFavorite ? "star.fill" : "star")
                        .font(.system(size: 11))
                        .foregroundColor(segment.isFavorite ? DesignSystem.Colors.voiceSecondary : DesignSystem.Colors.textSecondary)
                }
                .buttonStyle(.plain)
                .help(segment.isFavorite ? "Remove from favorites" : "Add to favorites")
            }

            // Action buttons on hover
            if !isEditing && isHovered {
                HStack(spacing: 4) {
                    Button {
                        startEditing()
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 11))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)

                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(DesignSystem.Colors.error)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(backgroundView)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !isEditing {
                onTap?()
            }
        }
        .alert("Delete Segment", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete?()
            }
        } message: {
            Text("Are you sure you want to delete this segment?")
        }
    }

    private var editingView: some View {
        HStack(spacing: 8) {
            TextField("Edit text...", text: $editedText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .lineLimit(1...5)

            Button("Save") {
                saveEditing()
            }
            .buttonStyle(SegmentEditButtonStyle(style: .primary))
            .disabled(editedText.isEmpty)

            Button("Cancel") {
                cancelEditing()
            }
            .buttonStyle(SegmentEditButtonStyle(style: .secondary))
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        if isEditing {
            Color(nsColor: .controlBackgroundColor)
        } else if isCurrentSegment {
            DesignSystem.Colors.accentSubtle
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(DesignSystem.Colors.accent.opacity(0.3), lineWidth: 1)
                )
        } else if segment.isFavorite {
            DesignSystem.Colors.voiceSecondary.opacity(0.08)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(DesignSystem.Colors.voiceSecondary.opacity(0.2), lineWidth: 1)
                )
        } else if isHovered {
            Color(nsColor: .controlBackgroundColor).opacity(0.3)
        } else {
            Color.clear
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func startEditing() {
        editedText = segment.text
        isEditing = true
    }

    private func cancelEditing() {
        isEditing = false
        editedText = ""
    }

    private func saveEditing() {
        let trimmedText = editedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        onEdit?(trimmedText)
        isEditing = false
        editedText = ""
    }
}

#Preview {
    VStack(spacing: 16) {
        EditableSegmentRow(
            segment: TranscriptionSegment(
                id: 0,
                text: "This is a sample transcription segment that can be edited or deleted.",
                startTime: 0.0,
                endTime: 5.5,
                isFavorite: false
            ),
            isCurrentSegment: false,
            canMerge: true,
            compactMode: false,
            onEdit: { _ in },
            onDelete: { },
            onMergeWithNext: { },
            onToggleFavorite: { }
        )

        EditableSegmentRow(
            segment: TranscriptionSegment(
                id: 1,
                text: "This segment is in compact mode (no timestamp).",
                startTime: 5.5,
                endTime: 10.0,
                isFavorite: false
            ),
            isCurrentSegment: true,
            canMerge: false,
            compactMode: true,
            onEdit: { _ in },
            onDelete: { },
            onToggleFavorite: { }
        )

        EditableSegmentRow(
            segment: TranscriptionSegment(
                id: 2,
                text: "This segment is favorited but not currently playing.",
                startTime: 10.0,
                endTime: 15.0,
                isFavorite: true
            ),
            isCurrentSegment: false,
            canMerge: true,
            compactMode: false,
            onEdit: { _ in },
            onDelete: { },
            onMergeWithNext: { },
            onToggleFavorite: { }
        )
    }
    .padding()
    .frame(width: 600)
}
