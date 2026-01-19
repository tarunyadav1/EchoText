import SwiftUI

/// A component for editing timestamp offsets with preview
struct TimestampOffsetEditor: View {
    @Binding var offset: TimeInterval
    @Binding var isEnabled: Bool

    /// Optional sample timestamp for preview (defaults to 1:30)
    var sampleTimestamp: TimeInterval = 90.0

    /// Called when the offset changes
    var onOffsetChange: ((TimeInterval) -> Void)?

    @State private var offsetInput: String = ""
    @State private var isEditing: Bool = false
    @FocusState private var isInputFocused: Bool

    init(
        offset: Binding<TimeInterval>,
        isEnabled: Binding<Bool>,
        sampleTimestamp: TimeInterval = 90.0,
        onOffsetChange: ((TimeInterval) -> Void)? = nil
    ) {
        self._offset = offset
        self._isEnabled = isEnabled
        self.sampleTimestamp = sampleTimestamp
        self.onOffsetChange = onOffsetChange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Enable toggle
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Adjust Timestamps")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Text("Shift all timestamps by a fixed amount")
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                Spacer()

                Toggle("", isOn: $isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            if isEnabled {
                // Offset input
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        // Quick offset buttons
                        HStack(spacing: 6) {
                            QuickOffsetButton(label: "-5s", offset: $offset, delta: -5)
                            QuickOffsetButton(label: "-1s", offset: $offset, delta: -1)
                            QuickOffsetButton(label: "+1s", offset: $offset, delta: 1)
                            QuickOffsetButton(label: "+5s", offset: $offset, delta: 5)
                        }

                        Spacer()

                        // Manual input field
                        HStack(spacing: 8) {
                            TextField("0:00.000", text: $offsetInput)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .frame(width: 100)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.primary.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .focused($isInputFocused)
                                .onSubmit {
                                    applyInputOffset()
                                }
                                .onChange(of: isInputFocused) { _, focused in
                                    if !focused {
                                        applyInputOffset()
                                    }
                                }

                            Button {
                                offset = 0
                            } label: {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .help("Reset to zero")
                        }
                    }

                    // Preview
                    timestampPreview
                }
                .padding(12)
                .background(Color.primary.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .onAppear {
            updateInputFromOffset()
        }
        .onChange(of: offset) { _, newValue in
            if !isInputFocused {
                updateInputFromOffset()
            }
            onOffsetChange?(newValue)
        }
    }

    // MARK: - Preview

    private var timestampPreview: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.system(size: 12))
                .foregroundColor(DesignSystem.Colors.textTertiary)

            HStack(spacing: 8) {
                Text(ExportService.formatDurationWithMilliseconds(sampleTimestamp))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                Image(systemName: "arrow.right")
                    .font(.system(size: 10))
                    .foregroundColor(DesignSystem.Colors.textTertiary)

                Text(ExportService.formatDurationWithMilliseconds(adjustedSampleTimestamp))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(offset != 0 ? DesignSystem.Colors.accent : DesignSystem.Colors.textSecondary)
            }

            Spacer()

            // Offset indicator
            if offset != 0 {
                Text(ExportService.formatTimestampOffset(offset))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(offset > 0 ? .green : .orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        (offset > 0 ? Color.green : Color.orange).opacity(0.1)
                    )
                    .clipShape(Capsule())
            }
        }
        .padding(.top, 4)
    }

    private var adjustedSampleTimestamp: TimeInterval {
        ExportService.applyTimestampOffset(sampleTimestamp, offset: offset)
    }

    // MARK: - Helpers

    private func updateInputFromOffset() {
        offsetInput = ExportService.formatTimestampOffset(offset)
    }

    private func applyInputOffset() {
        if let parsed = ExportService.parseTimestampOffset(offsetInput) {
            offset = parsed
        }
        updateInputFromOffset()
    }
}

/// Quick offset adjustment button
private struct QuickOffsetButton: View {
    let label: String
    @Binding var offset: TimeInterval
    let delta: TimeInterval

    var body: some View {
        Button {
            offset += delta
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(DesignSystem.Colors.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(DesignSystem.Colors.accentSubtle)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Compact Version

/// A more compact version of the timestamp offset editor for inline use
struct CompactTimestampOffsetEditor: View {
    @Binding var offset: TimeInterval
    @Binding var isEnabled: Bool

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: $isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()

            if isEnabled {
                HStack(spacing: 6) {
                    Button {
                        offset -= 1
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                    Text(ExportService.formatTimestampOffset(offset))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .frame(minWidth: 80)
                        .foregroundColor(offset != 0 ? DesignSystem.Colors.accent : DesignSystem.Colors.textSecondary)

                    Button {
                        offset += 1
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                    Button {
                        offset = 0
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                    .help("Reset to zero")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }
}

// MARK: - Export Options Panel

/// A panel showing export options including timestamp offset
struct ExportOptionsPanel: View {
    @Binding var options: ExportOptions
    @Binding var selectedFormat: ExportFormat

    /// Sample timestamp for preview (use first segment time if available)
    var sampleTimestamp: TimeInterval = 90.0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Format selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Export Format")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                Picker("", selection: $selectedFormat) {
                    ForEach(ExportFormat.allCases) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.menu)
            }

            Divider()

            // Timestamp offset (only for formats that use timestamps)
            if selectedFormat.supportsTimestamps {
                TimestampOffsetEditor(
                    offset: $options.timestampOffset,
                    isEnabled: $options.offsetEnabled,
                    sampleTimestamp: sampleTimestamp
                )
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.Colors.textTertiary)

                    Text("Timestamp offset is not applicable for \(selectedFormat.displayName) format")
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .frame(width: 340)
    }
}

// MARK: - ExportFormat Extension

extension ExportFormat {
    /// Whether this format supports timestamp offset
    var supportsTimestamps: Bool {
        switch self {
        case .srt, .vtt, .csv, .json, .md, .html:
            return true
        case .txt, .pdf, .docx, .echotext:
            return false
        }
    }
}

// MARK: - Preview

#Preview("Timestamp Offset Editor") {
    struct PreviewWrapper: View {
        @State private var offset: TimeInterval = 5.0
        @State private var isEnabled: Bool = true

        var body: some View {
            VStack(spacing: 40) {
                TimestampOffsetEditor(
                    offset: $offset,
                    isEnabled: $isEnabled
                )
                .frame(width: 400)

                Divider()

                CompactTimestampOffsetEditor(
                    offset: $offset,
                    isEnabled: $isEnabled
                )
            }
            .padding(40)
        }
    }

    return PreviewWrapper()
}

#Preview("Export Options Panel") {
    struct PreviewWrapper: View {
        @State private var options = ExportOptions()
        @State private var format: ExportFormat = .srt

        var body: some View {
            ExportOptionsPanel(
                options: $options,
                selectedFormat: $format
            )
        }
    }

    return PreviewWrapper()
}
