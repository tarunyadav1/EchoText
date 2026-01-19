import SwiftUI

/// Main view for meeting transcription feature
struct MeetingTranscriptionView: View {
    @StateObject private var viewModel: MeetingTranscriptionViewModel

    init(whisperService: WhisperService, parakeetService: ParakeetService? = nil, diarizationService: SpeakerDiarizationService? = nil) {
        _viewModel = StateObject(wrappedValue: MeetingTranscriptionViewModel(whisperService: whisperService, parakeetService: parakeetService, diarizationService: diarizationService))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with controls
            headerView

            Divider()

            // Main content area
            if viewModel.state == .idle && viewModel.transcribedSegments.isEmpty {
                emptyStateView
            } else {
                transcriptionView
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .task {
            await viewModel.refreshSources()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { viewModel.showError = false }
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Audio source picker (compact)
                Menu {
                    ForEach(viewModel.availableSources) { source in
                        Button {
                            viewModel.selectSource(source)
                        } label: {
                            HStack {
                                if viewModel.isMeetingApp(source) {
                                    Image(systemName: "video.fill")
                                }
                                Text(source.name)
                                if viewModel.selectedSource?.id == source.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "speaker.wave.2.fill")
                        Text(viewModel.selectedSource?.name ?? "Select Source")
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Spacer()

                // Recording controls
                recordingControls
            }

            // Status bar
            if viewModel.state != .idle {
                statusBar
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private var recordingControls: some View {
        HStack(spacing: 12) {
            switch viewModel.state {
            case .idle:
                Button {
                    Task { await viewModel.startRecording() }
                } label: {
                    Label("Start Recording", systemImage: "record.circle")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .tint(DesignSystem.Colors.voicePrimary)
                .disabled(viewModel.selectedSource == nil || !viewModel.isModelLoaded)

            case .starting:
                ProgressView()
                    .controlSize(.small)
                Text("Starting...")
                    .foregroundStyle(.secondary)

            case .recording:
                // Pause button
                Button {
                    viewModel.pauseRecording()
                } label: {
                    Image(systemName: "pause.fill")
                }
                .buttonStyle(.bordered)

                // Stop button
                Button {
                    Task { await viewModel.stopRecording() }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .tint(DesignSystem.Colors.accent)

            case .paused:
                // Resume button
                Button {
                    viewModel.resumeRecording()
                } label: {
                    Label("Resume", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(DesignSystem.Colors.voicePrimary)

                // Stop button
                Button {
                    Task { await viewModel.stopRecording() }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)

            case .processing, .stopping:
                ProgressView()
                    .controlSize(.small)
                Text("Processing...")
                    .foregroundStyle(.secondary)

            case .error:
                Button {
                    Task { await viewModel.startRecording() }
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var statusBar: some View {
        HStack(spacing: 20) {
            // Recording indicator
            if viewModel.state == .recording {
                HStack(spacing: 6) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                        .modifier(PulseAnimation())

                    Text("Recording")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.red)
                }
            } else if viewModel.state == .paused {
                HStack(spacing: 6) {
                    Image(systemName: "pause.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)

                    Text("Paused")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                }
            }

            // Duration
            HStack(spacing: 4) {
                Image(systemName: "clock")
                Text(viewModel.formattedDuration)
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            // Audio level
            if viewModel.state == .recording {
                AudioLevelIndicator(level: viewModel.audioLevel)
            }

            // Processing indicator
            if viewModel.processingChunks > 0 {
                HStack(spacing: 4) {
                    ProgressView()
                        .controlSize(.mini)
                    Text("\(viewModel.processingChunks) chunk\(viewModel.processingChunks == 1 ? "" : "s") processing")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Estimated delay
            if viewModel.estimatedDelay > 0 {
                Text("~\(Int(viewModel.estimatedDelay))s delay")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "waveform.and.mic")
                .font(.system(size: 64))
                .foregroundStyle(DesignSystem.Colors.accent.opacity(0.5))

            VStack(spacing: 8) {
                Text("Meeting Transcription")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Record and transcribe meetings, calls, and any system audio in near real-time.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }

            // Quick tips
            VStack(alignment: .leading, spacing: 12) {
                tipRow(icon: "speaker.wave.2.fill", text: "Select an audio source above")
                tipRow(icon: "video.fill", text: "Meeting apps are auto-detected")
                tipRow(icon: "clock", text: "Transcription appears with ~15-30s delay")
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if !viewModel.isModelLoaded {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Please load a transcription model first")
                        .font(.callout)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(DesignSystem.Colors.accent)
            Text(text)
                .font(.callout)
        }
    }

    // MARK: - Transcription View

    private var transcriptionView: some View {
        VStack(spacing: 0) {
            // Live text preview
            if !viewModel.liveText.isEmpty && viewModel.state == .recording {
                liveTextView
            }

            // Transcribed segments
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.transcribedSegments) { segment in
                            SegmentRow(segment: segment)
                                .id(segment.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.transcribedSegments.count) { _, _ in
                    if let lastSegment = viewModel.transcribedSegments.last {
                        withAnimation {
                            proxy.scrollTo(lastSegment.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Bottom toolbar
            if !viewModel.transcribedSegments.isEmpty {
                bottomToolbar
            }
        }
    }

    private var liveTextView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "text.bubble")
                Text("Live Preview")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
            }
            .foregroundStyle(.secondary)

            Text(viewModel.liveText.suffix(200))
                .font(.body)
                .foregroundStyle(.primary.opacity(0.8))
                .lineLimit(3)
        }
        .padding()
        .background(DesignSystem.Colors.accent.opacity(0.05))
        .overlay(
            Rectangle()
                .fill(DesignSystem.Colors.accent)
                .frame(width: 3),
            alignment: .leading
        )
    }

    private var bottomToolbar: some View {
        HStack {
            // Word count
            Text("\(viewModel.wordCount) words")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            // Export button
            Menu {
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
                    Label("Copy to Clipboard", systemImage: "doc.on.doc")
                }

                Divider()

                ForEach(ExportFormat.allCases) { format in
                    Button {
                        viewModel.exportAs(format)
                    } label: {
                        Label(format.displayName, systemImage: "doc")
                    }
                }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Segment Row

private struct SegmentRow: View {
    let segment: MeetingSegment

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timestamp
            Text(segment.formattedTimeRange)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.tertiary)
                .frame(width: 80, alignment: .leading)

            // Speaker label if available
            if let speaker = segment.speakerId {
                Text(speaker)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(DesignSystem.Colors.voicePrimary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(DesignSystem.Colors.voicePrimary.opacity(0.1))
                    .clipShape(Capsule())
            }

            // Text
            Text(segment.text)
                .font(.body)
                .textSelection(.enabled)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Audio Level Indicator

private struct AudioLevelIndicator: View {
    let level: Float
    private let barCount = 5

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(barColor(for: index))
                    .frame(width: 3, height: barHeight(for: index))
            }
        }
        .frame(height: 16)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let threshold = Float(index) / Float(barCount)
        return level > threshold ? 16 : 6
    }

    private func barColor(for index: Int) -> Color {
        let threshold = Float(index) / Float(barCount)
        if level > threshold {
            if index < 2 {
                return .green
            } else if index < 4 {
                return .yellow
            } else {
                return .red
            }
        }
        return .gray.opacity(0.3)
    }
}

// MARK: - Pulse Animation

private struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.5 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear {
                isPulsing = true
            }
    }
}

#Preview {
    MeetingTranscriptionView(whisperService: WhisperService())
}
