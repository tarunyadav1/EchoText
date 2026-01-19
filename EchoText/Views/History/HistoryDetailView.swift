import SwiftUI
import Combine

/// Full-screen detail view for viewing and editing a transcription with audio playback
struct HistoryDetailView: View {
    @StateObject private var viewModel: HistoryDetailViewModel
    @StateObject private var playbackService = AudioPlaybackService()
    @EnvironmentObject var appState: AppState

    @State private var scrollToSegmentId: UUID?
    private var cancellables = Set<AnyCancellable>()

    init(item: TranscriptionHistoryItem,
         onSave: @escaping (TranscriptionHistoryItem) -> Void,
         onDelete: @escaping () -> Void,
         onDismiss: @escaping () -> Void,
         onSaveSpeakerMapping: ((SpeakerMapping) -> Void)? = nil) {
        let vm = HistoryDetailViewModel(item: item)
        vm.onSave = onSave
        vm.onDelete = onDelete
        vm.onDismiss = onDismiss
        vm.onSaveSpeakerMapping = onSaveSpeakerMapping
        self._viewModel = StateObject(wrappedValue: vm)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top toolbar
            HistoryDetailToolbar(viewModel: viewModel)

            // Main content area
            HStack(spacing: 0) {
                // Left: Transcript/Segments content
                mainContent
                    .frame(minWidth: 400)

                // Subtle divider
                Rectangle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 1)

                // Right: Sidebar with controls
                HistoryDetailSidebar(viewModel: viewModel, playbackService: playbackService)
            }

            // Bottom: Audio player bar (if audio available)
            if viewModel.canPlayAudio || playbackService.isLoaded {
                AudioPlayerBar(playbackService: playbackService) { seekTime in
                    playbackService.seek(to: seekTime)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.8))
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            loadAudioIfAvailable()
        }
        .onDisappear {
            playbackService.stop()
        }
        .onChange(of: playbackService.currentTime) { _, newTime in
            viewModel.updateCurrentSegment(for: newTime)
            scrollToCurrentSegmentIfNeeded()
        }
        .alert("Delete Transcription?", isPresented: $viewModel.showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                viewModel.deleteItem()
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .sheet(isPresented: $viewModel.showSpeakerManager) {
            SpeakerManagerView(speakerMapping: $viewModel.speakerMapping) { newMapping in
                viewModel.saveSpeakerMapping(newMapping)
            }
        }
        .focusable()
        .onKeyPress(.escape) {
            viewModel.dismiss()
            return .handled
        }
        .onKeyPress(.space) {
            playbackService.togglePlayback()
            return .handled
        }
        .onKeyPress(KeyEquivalent("j")) {
            playbackService.skipBackward(5)
            return .handled
        }
        .onKeyPress(KeyEquivalent("l")) {
            playbackService.skipForward(5)
            return .handled
        }
        .onKeyPress(KeyEquivalent("[")) {
            playbackService.decreaseRate()
            return .handled
        }
        .onKeyPress(KeyEquivalent("]")) {
            playbackService.increaseRate()
            return .handled
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    switch viewModel.viewMode {
                    case .transcript:
                        transcriptView
                    case .segments:
                        segmentsView
                    }
                }
                .padding(24)
            }
            .onChange(of: scrollToSegmentId) { _, newId in
                if let id = newId {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - Transcript View

    private var transcriptView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(viewModel.transcriptText)
                .font(.system(size: viewModel.fontSize))
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .lineSpacing(viewModel.fontSize * 0.5)
                .textSelection(.enabled)
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Segments View

    private var segmentsView: some View {
        LazyVStack(spacing: 1) {
            ForEach(Array(viewModel.displayedSegments.enumerated()), id: \.element.uuid) { index, segment in
                HighlightableSegmentRow(
                    segment: segment,
                    speakerMapping: viewModel.speakerMapping,
                    isCurrentlyPlaying: viewModel.currentSegmentIndex == index,
                    fontSize: viewModel.fontSize,
                    canMerge: index < viewModel.displayedSegments.count - 1 && !viewModel.showFavoritesOnly,
                    compactMode: appState.settings.compactMode,
                    onEdit: { newText in
                        viewModel.updateSegment(segment.uuid, newText: newText)
                    },
                    onDelete: {
                        viewModel.deleteSegment(segment.uuid)
                    },
                    onMergeWithNext: {
                        viewModel.mergeSegment(segment.uuid)
                    },
                    onSeek: {
                        seekToSegment(segment)
                    },
                    onToggleFavorite: {
                        viewModel.toggleSegmentFavorite(segment.uuid)
                    }
                )
                .id(segment.uuid)
            }
        }
        .padding(8)
        .background(Color.primary.opacity(0.02), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Audio Functions

    private func loadAudioIfAvailable() {
        guard let audioURL = viewModel.audioFileURL else { return }

        Task {
            do {
                try await playbackService.load(url: audioURL)
            } catch {
                print("Failed to load audio: \(error)")
            }
        }
    }

    private func seekToSegment(_ segment: TranscriptionSegment) {
        playbackService.seek(to: segment.startTime)
        if !playbackService.isPlaying {
            playbackService.play()
        }
    }

    private func scrollToCurrentSegmentIfNeeded() {
        guard playbackService.isPlaying,
              let currentIndex = viewModel.currentSegmentIndex,
              currentIndex < viewModel.displayedSegments.count else { return }

        let segment = viewModel.displayedSegments[currentIndex]
        scrollToSegmentId = segment.uuid
    }
}

#Preview {
    HistoryDetailView(
        item: TranscriptionHistoryItem(
            id: UUID(),
            text: "This is a sample transcription text that demonstrates how the detail view looks. It includes multiple sentences to show how the text wraps and displays properly.",
            segments: [
                TranscriptionSegment(id: 0, text: "This is the first segment of the transcription.", startTime: 0, endTime: 3, speakerId: "speaker_0", isFavorite: true),
                TranscriptionSegment(id: 1, text: "Here is the second segment with different content.", startTime: 3, endTime: 6, speakerId: "speaker_1", isFavorite: false),
                TranscriptionSegment(id: 2, text: "And this is the third segment to show more content.", startTime: 6, endTime: 10, speakerId: "speaker_0", isFavorite: false)
            ],
            language: "en",
            duration: 10,
            processingTime: 2.3,
            modelUsed: "base",
            timestamp: Date(),
            source: .dictation,
            isFavorite: false,
            tags: [],
            speakerMapping: SpeakerMapping(speakers: [
                Speaker(id: "speaker_0", displayName: "John", colorIndex: 0),
                Speaker(id: "speaker_1", displayName: "Sarah", colorIndex: 1)
            ])
        ),
        onSave: { _ in },
        onDelete: { },
        onDismiss: { }
    )
    .environmentObject(AppState())
    .frame(width: 1000, height: 700)
}
