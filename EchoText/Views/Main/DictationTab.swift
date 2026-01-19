import SwiftUI

/// Liquid Glass dictation interface
struct DictationTab: View {
    @ObservedObject var viewModel: DictationViewModel
    @FocusState private var isTextFieldFocused: Bool
    @State private var showClearConfirmation: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding(.horizontal, 40)
                .padding(.top, 32)

            // Main Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 40) {
                    // Recording Control
                    recordingControl
                        .padding(.top, 48)

                    // Transcription Area
                    transcriptionArea
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 32)
            }

            // Bottom Toolbar
            bottomToolbar
        }
        .background(Color.clear)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Voice Dictation")
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text("Press the button or use your hotkey to start")
                    .font(.system(size: 14))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }

            Spacer()

            // Hotkey badge with glass effect
            HStack(spacing: 4) {
                Text("⌃")
                    .font(.system(size: 13, weight: .semibold))
                Text("Space")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
            }
            .foregroundColor(DesignSystem.Colors.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(DesignSystem.Colors.accentSubtle)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(DesignSystem.Colors.accent.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Recording Control

    private var recordingControl: some View {
        VStack(spacing: 24) {
            // Record Button with glass rings
            ZStack {
                // Pulse rings when recording
                if viewModel.isRecording {
                    ForEach(0..<2, id: \.self) { i in
                        Circle()
                            .stroke(DesignSystem.Colors.recordingActive.opacity(0.2 - Double(i) * 0.08), lineWidth: 2)
                            .frame(width: 120 + CGFloat(i) * 30, height: 120 + CGFloat(i) * 30)
                            .scaleEffect(1.0 + CGFloat(viewModel.audioLevel) * 0.1)
                            .animation(.easeOut(duration: 0.1), value: viewModel.audioLevel)
                    }
                }

                // Main button
                Button {
                    Task { await viewModel.toggleRecording() }
                } label: {
                    ZStack {
                        // Glass background
                        Circle()
                            .fill(buttonBackground)
                            .frame(width: 96, height: 96)
                            .shadow(color: buttonShadow, radius: 12, y: 4)

                        // Border
                        Circle()
                            .stroke(buttonBorder, lineWidth: 2)
                            .frame(width: 96, height: 96)

                        if viewModel.isProcessing {
                            ProgressView()
                                .scaleEffect(1.3)
                                .tint(.white)
                        } else {
                            Image(systemName: buttonIcon)
                                .font(.system(size: 36, weight: .medium))
                                .foregroundColor(buttonIconColor)
                        }
                    }
                }
                .buttonStyle(.plain)
                .glassEffect(
                    viewModel.isRecording 
                        ? .regular.tint(DesignSystem.Colors.recordingActive).interactive()
                        : .regular.interactive(),
                    in: .circle
                )
                .scaleEffect(viewModel.isRecording ? 1.04 : 1.0)
                .animation(DesignSystem.Animations.spring, value: viewModel.isRecording)
            }
            .frame(height: 160)

            // Status
            VStack(spacing: 8) {
                Text(statusText)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                if viewModel.isRecording {
                    Text(viewModel.formattedDuration)
                        .font(.system(size: 28, weight: .semibold, design: .monospaced))
                        .foregroundColor(DesignSystem.Colors.recordingActive)
                } else if viewModel.isProcessing {
                    Text("Transcribing...")
                        .font(.system(size: 14))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                } else {
                    Text("Click to start")
                        .font(.system(size: 14))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
            }
        }
    }

    private var statusText: String {
        switch viewModel.recordingState {
        case .idle: return "Ready"
        case .recording: return "Listening..."
        case .processing: return "Processing"
        }
    }

    private var buttonBackground: Color {
        switch viewModel.recordingState {
        case .idle: return Color.clear
        case .recording: return DesignSystem.Colors.recordingActive
        case .processing: return Color.clear
        }
    }

    private var buttonShadow: Color {
        switch viewModel.recordingState {
        case .idle: return DesignSystem.Colors.accent.opacity(0.2)
        case .recording: return DesignSystem.Colors.recordingActive.opacity(0.3)
        case .processing: return DesignSystem.Colors.processingActive.opacity(0.2)
        }
    }

    private var buttonBorder: Color {
        switch viewModel.recordingState {
        case .idle: return DesignSystem.Colors.accent
        case .recording: return Color.clear
        case .processing: return DesignSystem.Colors.processingActive
        }
    }

    private var buttonIcon: String {
        switch viewModel.recordingState {
        case .idle: return "mic.fill"
        case .recording: return "stop.fill"
        case .processing: return "waveform"
        }
    }

    private var buttonIconColor: Color {
        switch viewModel.recordingState {
        case .idle: return DesignSystem.Colors.accent
        case .recording: return .white
        case .processing: return DesignSystem.Colors.processingActive
        }
    }

    // MARK: - Transcription Area

    private var transcriptionArea: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header row
            HStack {
                Text("Transcription")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Spacer()

                if viewModel.hasTranscription {
                    Text("\(viewModel.wordCount) words")
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.Colors.textTertiary)

                    Menu {
                        Button {
                            viewModel.copyCleanText()
                        } label: {
                            Label("Clean Text", systemImage: "text.alignleft")
                        }

                        Button {
                            viewModel.copyWithTimestamps()
                        } label: {
                            Label("With Timestamps", systemImage: "clock")
                        }
                    } label: {
                        Image(systemName: viewModel.showCopyConfirmation ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 13))
                            .foregroundColor(viewModel.showCopyConfirmation ? .green : DesignSystem.Colors.textPrimary)
                    }
                    .buttonStyle(WisprIconButtonStyle(size: 30))
                }
            }

            // Text area with glass effect
            ZStack(alignment: .topLeading) {
                TextEditor(text: $viewModel.transcriptionText)
                    .font(.system(size: 14))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(16)
                    .focused($isTextFieldFocused)

                if viewModel.transcriptionText.isEmpty && !isTextFieldFocused {
                    Text("Your transcribed text will appear here...")
                        .font(.system(size: 14))
                        .foregroundColor(DesignSystem.Colors.textMuted)
                        .padding(.top, 24)
                        .padding(.leading, 20)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: 200)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
            .shadow(color: DesignSystem.Shadows.subtle, radius: 8, y: 2)
        }
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack(spacing: 12) {
            Button {
                Task { await viewModel.insertText() }
            } label: {
                Label("Insert at Cursor", systemImage: "text.insert")
            }
            .buttonStyle(LiquidGlassButtonStyle(style: .primary))
            .disabled(!viewModel.hasTranscription)

            Spacer()

            Menu {
                ForEach(ExportFormat.allCases) { format in
                    Button(format.displayName) {
                        Task { await viewModel.export(format: format) }
                    }
                }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(LiquidGlassButtonStyle(style: .secondary))
            .disabled(!viewModel.hasTranscription)

            Button {
                showClearConfirmation = true
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(WisprIconButtonStyle(size: 36))
            .disabled(!viewModel.hasTranscription)
            .confirmationDialog(
                "Clear Transcription",
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear", role: .destructive) {
                    viewModel.clearHistory()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will clear the current transcription. This action cannot be undone.")
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
}

#Preview {
    DictationTab(viewModel: DictationViewModel(appState: AppState()))
        .frame(width: 700, height: 600)
}
