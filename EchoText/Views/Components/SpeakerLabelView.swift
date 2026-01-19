import SwiftUI

/// Compact colored badge showing speaker name
struct SpeakerBadge: View {
    let speaker: Speaker
    let isCompact: Bool

    init(speaker: Speaker, isCompact: Bool = false) {
        self.speaker = speaker
        self.isCompact = isCompact
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(DesignSystem.Colors.speakerColor(at: speaker.colorIndex))
                .frame(width: isCompact ? 6 : 8, height: isCompact ? 6 : 8)

            Text(speaker.displayName)
                .font(.system(size: isCompact ? 10 : 11, weight: .medium))
                .foregroundColor(DesignSystem.Colors.speakerColor(at: speaker.colorIndex))
        }
        .padding(.horizontal, isCompact ? 6 : 8)
        .padding(.vertical, isCompact ? 3 : 4)
        .background(DesignSystem.Colors.speakerColorBackground(at: speaker.colorIndex))
        .clipShape(Capsule())
    }
}

/// Speaker badge for use with speaker ID and mapping
struct SpeakerBadgeFromMapping: View {
    let speakerId: String
    let speakerMapping: SpeakerMapping
    let isCompact: Bool

    init(speakerId: String, speakerMapping: SpeakerMapping, isCompact: Bool = false) {
        self.speakerId = speakerId
        self.speakerMapping = speakerMapping
        self.isCompact = isCompact
    }

    var body: some View {
        let displayName = speakerMapping.displayName(for: speakerId)
        let colorIndex = speakerMapping.colorIndex(for: speakerId)

        HStack(spacing: 4) {
            Circle()
                .fill(DesignSystem.Colors.speakerColor(at: colorIndex))
                .frame(width: isCompact ? 6 : 8, height: isCompact ? 6 : 8)

            Text(displayName)
                .font(.system(size: isCompact ? 10 : 11, weight: .medium))
                .foregroundColor(DesignSystem.Colors.speakerColor(at: colorIndex))
        }
        .padding(.horizontal, isCompact ? 6 : 8)
        .padding(.vertical, isCompact ? 3 : 4)
        .background(DesignSystem.Colors.speakerColorBackground(at: colorIndex))
        .clipShape(Capsule())
    }
}

/// Editable speaker label with color indicator
struct SpeakerLabelView: View {
    let speaker: Speaker
    let onNameChange: (String) -> Void
    let onColorChange: (Int) -> Void

    @State private var isEditing = false
    @State private var editedName: String

    init(speaker: Speaker, onNameChange: @escaping (String) -> Void, onColorChange: @escaping (Int) -> Void) {
        self.speaker = speaker
        self.onNameChange = onNameChange
        self.onColorChange = onColorChange
        self._editedName = State(initialValue: speaker.displayName)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Color picker
            colorPicker

            // Name field
            VStack(alignment: .leading, spacing: 2) {
                Text("Speaker Name")
                    .font(.system(size: 10))
                    .foregroundColor(DesignSystem.Colors.textTertiary)

                if isEditing {
                    TextField("Speaker name", text: $editedName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .onSubmit {
                            onNameChange(editedName)
                            isEditing = false
                        }
                } else {
                    HStack {
                        Text(speaker.displayName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.textPrimary)

                        Spacer()

                        Button {
                            isEditing = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 11))
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(12)
        .background(DesignSystem.Colors.surfaceHover)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
    }

    private var colorPicker: some View {
        Menu {
            ForEach(0..<10, id: \.self) { index in
                Button {
                    onColorChange(index)
                } label: {
                    HStack {
                        Circle()
                            .fill(DesignSystem.Colors.speakerColor(at: index))
                            .frame(width: 12, height: 12)
                        Text("Color \(index + 1)")
                        if index == speaker.colorIndex {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Circle()
                .fill(DesignSystem.Colors.speakerColor(at: speaker.colorIndex))
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                )
        }
    }
}

/// Inline speaker indicator for segment display
struct SpeakerIndicator: View {
    let colorIndex: Int

    var body: some View {
        Circle()
            .fill(DesignSystem.Colors.speakerColor(at: colorIndex))
            .frame(width: 8, height: 8)
    }
}

/// Speaker color legend for transcription overview
struct SpeakerLegend: View {
    let speakerMapping: SpeakerMapping

    var body: some View {
        if !speakerMapping.isEmpty {
            HStack(spacing: 16) {
                ForEach(speakerMapping.speakers) { speaker in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(DesignSystem.Colors.speakerColor(at: speaker.colorIndex))
                            .frame(width: 8, height: 8)

                        Text(speaker.displayName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
            }
        }
    }
}

#Preview("Speaker Badge") {
    VStack(spacing: 16) {
        SpeakerBadge(speaker: Speaker(id: "speaker_0", displayName: "John", colorIndex: 0))
        SpeakerBadge(speaker: Speaker(id: "speaker_1", displayName: "Sarah", colorIndex: 1))
        SpeakerBadge(speaker: Speaker(id: "speaker_2", colorIndex: 2), isCompact: true)
    }
    .padding()
}

#Preview("Speaker Label View") {
    SpeakerLabelView(
        speaker: Speaker(id: "speaker_0", displayName: "Speaker 1", colorIndex: 0),
        onNameChange: { _ in },
        onColorChange: { _ in }
    )
    .frame(width: 300)
    .padding()
}

#Preview("Speaker Legend") {
    let mapping = SpeakerMapping(speakers: [
        Speaker(id: "speaker_0", displayName: "John", colorIndex: 0),
        Speaker(id: "speaker_1", displayName: "Sarah", colorIndex: 1)
    ])
    return SpeakerLegend(speakerMapping: mapping)
        .padding()
}
