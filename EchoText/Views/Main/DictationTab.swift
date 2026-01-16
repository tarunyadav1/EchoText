import SwiftUI

/// Tab for quick voice dictation
struct DictationTab: View {
    @ObservedObject var viewModel: DictationViewModel
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Main content area
            VStack(spacing: 24) {
                // Recording indicator area
                recordingArea

                // Transcription text area
                transcriptionArea
            }
            .padding(24)

            Divider()

            // Bottom toolbar
            bottomToolbar
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Recording Area

    private var recordingArea: some View {
        VStack(spacing: 16) {
            // State indicator
            ZStack {
                // Background circle
                Circle()
                    .fill(recordingBackgroundColor)
                    .frame(width: 120, height: 120)

                // Animated ring for recording
                if viewModel.isRecording {
                    Circle()
                        .stroke(Color.red.opacity(0.5), lineWidth: 4)
                        .frame(width: 120, height: 120)
                        .scaleEffect(1.0 + CGFloat(viewModel.audioLevel) * 0.3)
                        .animation(.easeOut(duration: 0.1), value: viewModel.audioLevel)
                }

                // Icon
                Image(systemName: recordingIconName)
                    .font(.system(size: 48, weight: .medium))
                    .foregroundColor(recordingIconColor)
            }
            .onTapGesture {
                Task {
                    await viewModel.toggleRecording()
                }
            }
            .disabled(viewModel.isProcessing)

            // Status text
            Text(viewModel.recordingState.displayText)
                .font(.headline)
                .foregroundColor(.secondary)

            // Duration (when recording)
            if viewModel.isRecording {
                Text(viewModel.formattedDuration)
                    .font(.system(.title2, design: .monospaced))
                    .foregroundColor(.primary)
            }
        }
    }

    private var recordingBackgroundColor: Color {
        switch viewModel.recordingState {
        case .idle:
            return Color(NSColor.controlBackgroundColor)
        case .recording:
            return Color.red.opacity(0.1)
        case .processing:
            return Color.orange.opacity(0.1)
        }
    }

    private var recordingIconName: String {
        switch viewModel.recordingState {
        case .idle:
            return "mic.fill"
        case .recording:
            return "stop.fill"
        case .processing:
            return "waveform"
        }
    }

    private var recordingIconColor: Color {
        switch viewModel.recordingState {
        case .idle:
            return .accentColor
        case .recording:
            return .red
        case .processing:
            return .orange
        }
    }

    // MARK: - Transcription Area

    private var transcriptionArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Transcription")
                    .font(.headline)

                Spacer()

                if viewModel.hasTranscription {
                    Text("\(viewModel.wordCount) words")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            TextEditor(text: $viewModel.transcriptionText)
                .font(.body)
                .scrollContentBackground(.hidden)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
                .frame(minHeight: 150)
                .focused($isTextFieldFocused)
                .onChange(of: viewModel.transcriptionText) { _ in
                    viewModel.isEditing = isTextFieldFocused
                }

            // Placeholder when empty
            if viewModel.transcriptionText.isEmpty && !isTextFieldFocused {
                Text("Your transcribed text will appear here...")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.top, -140)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack(spacing: 16) {
            // Copy button
            Button {
                viewModel.copyToClipboard()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .disabled(!viewModel.hasTranscription)

            // Insert button
            Button {
                Task {
                    await viewModel.insertText()
                }
            } label: {
                Label("Insert", systemImage: "text.insert")
            }
            .disabled(!viewModel.hasTranscription)

            Spacer()

            // Export menu
            Menu {
                ForEach(ExportFormat.allCases) { format in
                    Button(format.displayName) {
                        Task {
                            await viewModel.export(format: format)
                        }
                    }
                }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .disabled(!viewModel.hasTranscription)

            // Clear button
            Button {
                viewModel.clearHistory()
            } label: {
                Label("Clear", systemImage: "trash")
            }
            .disabled(!viewModel.hasTranscription)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - Preview
#Preview {
    DictationTab(viewModel: DictationViewModel(appState: AppState()))
        .frame(width: 600, height: 500)
}
