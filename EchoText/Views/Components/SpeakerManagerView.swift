import SwiftUI

/// Sheet for managing and renaming speakers in a transcription
struct SpeakerManagerView: View {
    @Binding var speakerMapping: SpeakerMapping
    let onSave: (SpeakerMapping) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var localMapping: SpeakerMapping

    init(speakerMapping: Binding<SpeakerMapping>, onSave: @escaping (SpeakerMapping) -> Void) {
        self._speakerMapping = speakerMapping
        self.onSave = onSave
        self._localMapping = State(initialValue: speakerMapping.wrappedValue)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Content
            ScrollView {
                VStack(spacing: 16) {
                    // Instructions
                    instructionsCard

                    // Speaker list
                    speakerList
                }
                .padding(20)
            }

            Divider()

            // Footer
            footer
        }
        .frame(width: 440, height: 420)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Edit Speakers")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text("\(localMapping.count) speaker\(localMapping.count == 1 ? "" : "s") detected")
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
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
        .padding(.vertical, 14)
    }

    // MARK: - Instructions Card

    private var instructionsCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 16))
                .foregroundColor(DesignSystem.Colors.accent)

            VStack(alignment: .leading, spacing: 4) {
                Text("Customize speaker names")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text("Replace generic labels with actual names to make your transcript easier to read and export.")
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(DesignSystem.Colors.accentMuted)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
    }

    // MARK: - Speaker List

    private var speakerList: some View {
        VStack(spacing: 12) {
            ForEach(localMapping.speakers) { speaker in
                SpeakerEditRow(
                    speaker: speaker,
                    onNameChange: { name in
                        localMapping.updateDisplayName(name, for: speaker.id)
                    },
                    onColorChange: { colorIndex in
                        localMapping.updateColorIndex(colorIndex, for: speaker.id)
                    }
                )
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            Button("Reset to Default") {
                // Reset all names to defaults
                for speaker in localMapping.speakers {
                    localMapping.updateDisplayName(Speaker.defaultName(for: speaker.id), for: speaker.id)
                }
            }
            .buttonStyle(LiquidGlassButtonStyle(style: .ghost))

            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(LiquidGlassButtonStyle(style: .secondary))

            Button("Save Changes") {
                speakerMapping = localMapping
                onSave(localMapping)
                dismiss()
            }
            .buttonStyle(LiquidGlassButtonStyle(style: .primary))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

/// Individual speaker row in the manager
struct SpeakerEditRow: View {
    let speaker: Speaker
    let onNameChange: (String) -> Void
    let onColorChange: (Int) -> Void

    @State private var name: String
    @FocusState private var isNameFocused: Bool

    init(speaker: Speaker, onNameChange: @escaping (String) -> Void, onColorChange: @escaping (Int) -> Void) {
        self.speaker = speaker
        self.onNameChange = onNameChange
        self.onColorChange = onColorChange
        self._name = State(initialValue: speaker.displayName)
    }

    var body: some View {
        HStack(spacing: 14) {
            // Color picker
            colorPicker

            // Name field
            VStack(alignment: .leading, spacing: 4) {
                Text("Name")
                    .font(.system(size: 10))
                    .foregroundColor(DesignSystem.Colors.textTertiary)

                TextField("Speaker name", text: $name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .medium))
                    .focused($isNameFocused)
                    .onChange(of: name) { newValue in
                        onNameChange(newValue)
                    }
            }

            Spacer()

            // Preview badge
            SpeakerBadge(
                speaker: Speaker(id: speaker.id, displayName: name, colorIndex: speaker.colorIndex),
                isCompact: true
            )
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
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
                .frame(width: 36, height: 36)
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
        }
    }
}

#Preview {
    let mapping = SpeakerMapping(speakers: [
        Speaker(id: "speaker_0", displayName: "Speaker 1", colorIndex: 0),
        Speaker(id: "speaker_1", displayName: "Speaker 2", colorIndex: 1)
    ])

    return SpeakerManagerView(
        speakerMapping: .constant(mapping),
        onSave: { _ in }
    )
}
