import SwiftUI
import UniformTypeIdentifiers

/// Tab for file-based transcription with Voice Memos drag-and-drop support and video playback
struct FileTranscriptionTab: View {
    @ObservedObject var viewModel: FileTranscriptionViewModel
    @EnvironmentObject var appState: AppState
    @FocusState private var isFocused: Bool
    @State private var showClearQueueConfirmation: Bool = false

    // Voice Memos drop handler for custom handling
    private let voiceMemosHandler = VoiceMemosDropHandler()

    // Video player service for video files
    @StateObject private var videoPlayerService = VideoPlayerService()

    var body: some View {
        ZStack {
            if viewModel.queuedFiles.isEmpty {
                dropZoneView
            } else if viewModel.selectedFile != nil {
                // Split view: file list + transcript/video
                HStack(spacing: 0) {
                    // Sidebar with file list
                    fileListSidebar
                        .frame(width: 260)

                    Divider()

                    // Main content: video player or transcript + audio player
                    if isSelectedFileVideo {
                        videoTranscriptView
                    } else {
                        transcriptView
                    }
                }
            } else {
                // Just the file list
                VStack(spacing: 0) {
                    fileListView
                    bottomToolbar
                }
            }
        }
        .background(Color.clear)
        .onDrop(of: supportedDropTypes, isTargeted: $viewModel.isDragging) { providers in
            handleFileDrop(providers: providers)
        }
        .focused($isFocused)
        .onKeyPress(.space) {
            handlePlaybackToggle()
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "kK")) { _ in
            handlePlaybackToggle()
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "jJ")) { _ in
            handleSkipBackward(5)
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "lL")) { _ in
            handleSkipForward(5)
        }
        .onKeyPress(.leftArrow) {
            handleSkipBackward(1)
        }
        .onKeyPress(.rightArrow) {
            handleSkipForward(1)
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "[")) { _ in
            handleDecreaseRate()
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "]")) { _ in
            handleIncreaseRate()
        }
        .onKeyPress(.escape) {
            if viewModel.selectedFileId != nil {
                viewModel.deselectFile()
                videoPlayerService.stop()
                return .handled
            }
            return .ignored
        }
        .onChange(of: viewModel.selectedFileId) { _, newId in
            // When file selection changes, load appropriate player
            if let newId = newId,
               let file = viewModel.queuedFiles.first(where: { $0.id == newId }),
               file.status == .completed {
                loadPlayerForFile(file)
            } else {
                // Stop video player when deselecting
                videoPlayerService.stop()
            }
        }
    }

    // MARK: - Computed Properties

    /// Check if the currently selected file is a video
    private var isSelectedFileVideo: Bool {
        guard let file = viewModel.selectedFile else { return false }
        return VideoPlayerService.isVideoFile(file.url)
    }

    // MARK: - Playback Handlers

    private func handlePlaybackToggle() -> KeyPress.Result {
        if isSelectedFileVideo && videoPlayerService.isLoaded {
            videoPlayerService.togglePlayback()
            return .handled
        } else if viewModel.playbackService.isLoaded {
            viewModel.playbackService.togglePlayback()
            return .handled
        }
        return .ignored
    }

    private func handleSkipBackward(_ seconds: TimeInterval) -> KeyPress.Result {
        if isSelectedFileVideo && videoPlayerService.isLoaded {
            videoPlayerService.skipBackward(seconds)
            return .handled
        } else if viewModel.playbackService.isLoaded {
            viewModel.playbackService.skipBackward(seconds)
            return .handled
        }
        return .ignored
    }

    private func handleSkipForward(_ seconds: TimeInterval) -> KeyPress.Result {
        if isSelectedFileVideo && videoPlayerService.isLoaded {
            videoPlayerService.skipForward(seconds)
            return .handled
        } else if viewModel.playbackService.isLoaded {
            viewModel.playbackService.skipForward(seconds)
            return .handled
        }
        return .ignored
    }

    private func handleDecreaseRate() -> KeyPress.Result {
        if isSelectedFileVideo && videoPlayerService.isLoaded {
            videoPlayerService.decreaseRate()
            return .handled
        } else if viewModel.playbackService.isLoaded {
            viewModel.playbackService.decreaseRate()
            return .handled
        }
        return .ignored
    }

    private func handleIncreaseRate() -> KeyPress.Result {
        if isSelectedFileVideo && videoPlayerService.isLoaded {
            videoPlayerService.increaseRate()
            return .handled
        } else if viewModel.playbackService.isLoaded {
            viewModel.playbackService.increaseRate()
            return .handled
        }
        return .ignored
    }

    /// Load the appropriate player for the selected file
    private func loadPlayerForFile(_ file: QueuedFile) {
        if VideoPlayerService.isVideoFile(file.url) {
            // Stop audio playback and load video
            viewModel.playbackService.stop()
            Task {
                try? await videoPlayerService.load(url: file.url)
            }
        } else {
            // Stop video playback and load audio
            videoPlayerService.stop()
            Task {
                try? await viewModel.playbackService.load(url: file.url)
            }
        }
    }

    // MARK: - Drop Types

    /// All supported drop types including Voice Memos file promises
    private var supportedDropTypes: [UTType] {
        [
            .fileURL,
            .audio,
            .mpeg4Audio,
            .mp3,
            .wav,
            .aiff,
            .movie
        ]
    }

    // MARK: - Drop Handling

    /// Handle file drops including Voice Memos file promises
    private func handleFileDrop(providers: [NSItemProvider]) -> Bool {
        NSLog("[FileTranscriptionTab] Handling drop with %d providers", providers.count)

        // Check if this might be from Voice Memos (uses file promises)
        if voiceMemosHandler.containsVoiceMemos(providers) {
            NSLog("[FileTranscriptionTab] Detected Voice Memos content")

            voiceMemosHandler.handleFilePromises(from: providers) { urls in
                let validURLs = urls.filter { viewModel.isSupported($0) }
                if !validURLs.isEmpty {
                    NSLog("[FileTranscriptionTab] Adding %d Voice Memo files", validURLs.count)
                    viewModel.addFiles(validURLs)

                    // Auto-start transcription for Voice Memos
                    if appState.settings.autoStartTranscription {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            if viewModel.canStart {
                                viewModel.startProcessing()
                            }
                        }
                    }
                }
            }

            return true
        }

        // Standard file drop handling
        return viewModel.handleDrop(providers: providers)
    }

    // MARK: - Drop Zone

    private var dropZoneView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Voice Memos enabled drop zone
            VoiceMemosDropZone(
                onDrop: { urls in
                    let validURLs = urls.filter { viewModel.isSupported($0) }
                    if !validURLs.isEmpty {
                        viewModel.addFiles(validURLs)

                        // Auto-start transcription
                        if appState.settings.autoStartTranscription {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                if viewModel.canStart {
                                    viewModel.startProcessing()
                                }
                            }
                        }
                    }
                },
                onChooseFiles: openFilePicker
            )
            .scaleEffect(viewModel.isDragging ? 1.02 : 1.0)
            .animation(.spring(response: 0.3), value: viewModel.isDragging)

            // Tip for Voice Memos
            voiceMemosTip

            Spacer()
        }
        .padding(.vertical, 20)
    }

    /// Helpful tip about Voice Memos integration
    private var voiceMemosTip: some View {
        HStack(spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 12))
                .foregroundColor(.yellow)

            Text("Tip: Drag voice memos directly from the Voice Memos app")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.yellow.opacity(0.1))
        )
        .opacity(0.8)
    }

    // MARK: - File List (Full View)

    private var fileListView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Transcription Queue")
                    .font(.system(size: 18, weight: .bold, design: .rounded))

                Spacer()

                if viewModel.isProcessing {
                    ProgressView(value: viewModel.overallProgress)
                        .frame(width: 100)
                        .tint(.accentColor)
                }

                Text("\(viewModel.completedCount)/\(viewModel.queuedFiles.count) done")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.secondary.opacity(0.1)))
            }
            .padding(24)

            List {
                ForEach(viewModel.queuedFiles) { file in
                    FileRowView(
                        file: file,
                        isSelected: viewModel.selectedFileId == file.id,
                        onSelect: {
                            if file.status == .completed {
                                viewModel.selectFile(file)
                            }
                        },
                        onRetry: {
                            viewModel.retryFile(file)
                        },
                        onMoveUp: {
                            viewModel.moveUp(file)
                        },
                        onMoveDown: {
                            viewModel.moveDown(file)
                        },
                        onRemove: {
                            viewModel.removeFile(file)
                        }
                    )
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    // MARK: - File List Sidebar (Split View)

    private var fileListSidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Files")
                    .font(.system(size: 14, weight: .bold, design: .rounded))

                Spacer()

                Text("\(viewModel.completedCount)/\(viewModel.queuedFiles.count)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            List {
                ForEach(viewModel.queuedFiles) { file in
                    CompactFileRow(
                        file: file,
                        isSelected: viewModel.selectedFileId == file.id,
                        onSelect: {
                            if file.status == .completed {
                                viewModel.selectFile(file)
                            }
                        }
                    )
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            Divider()

            // Sidebar toolbar with compact drop zone
            VStack(spacing: 8) {
                // Compact drop zone for adding more files
                CompactDropZone(
                    supportedTypes: FileTranscriptionViewModel.supportedTypes,
                    onDrop: { urls in
                        viewModel.addFiles(urls)
                    }
                )

                // Control buttons
                HStack(spacing: 8) {
                    Button {
                        openFilePicker()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(GlassButtonStyle())

                    if viewModel.isProcessing {
                        Button {
                            viewModel.cancelProcessing()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(GlassButtonStyle())
                    } else {
                        Button {
                            viewModel.startProcessing()
                        } label: {
                            Image(systemName: "play.fill")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(GlassButtonStyle())
                        .disabled(viewModel.pendingCount == 0)
                    }

                    Spacer()

                    Button {
                        viewModel.deselectFile()
                        videoPlayerService.stop()
                    } label: {
                        Image(systemName: "sidebar.right")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(GlassButtonStyle())
                    .help("Close transcript (Esc)")
                }
            }
            .padding(12)
        }
        .background(DesignSystem.Colors.glassUltraLight)
    }

    // MARK: - Video Transcript View

    private var videoTranscriptView: some View {
        VStack(spacing: 0) {
            if let file = viewModel.selectedFile, let result = file.result {
                // Header
                transcriptHeader(file: file, result: result, isVideo: true)

                Divider()

                // Video player with synced subtitles
                VideoPlayerView(
                    videoService: videoPlayerService,
                    segments: result.segments,
                    onSegmentTap: { segment in
                        videoPlayerService.seek(to: segment.startTime)
                        if !videoPlayerService.isPlaying {
                            videoPlayerService.play()
                        }
                    }
                )
            } else {
                emptyStateView
            }
        }
    }

    // MARK: - Transcript View (Audio)

    private var transcriptView: some View {
        VStack(spacing: 0) {
            if let file = viewModel.selectedFile, let result = file.result {
                // Header
                transcriptHeader(file: file, result: result, isVideo: false)

                Divider()

                // Multi-language subtitle container with translation support
                MultiLanguageSubtitleContainer(
                    result: result,
                    currentSegmentIndex: viewModel.currentSegmentIndex,
                    isPlaying: viewModel.playbackService.isPlaying,
                    compactMode: appState.settings.compactMode,
                    onSegmentTap: { segment in
                        viewModel.seekToSegment(segment)
                    }
                )

                // Audio player bar
                if viewModel.playbackService.isLoaded {
                    AudioPlayerBar(playbackService: viewModel.playbackService)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
            } else {
                emptyStateView
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Select a completed file to view transcript")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func transcriptHeader(file: QueuedFile, result: TranscriptionResult, isVideo: Bool) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(file.fileName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .lineLimit(1)

                    // Video badge
                    if isVideo {
                        Label("Video", systemImage: "film")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DesignSystem.Colors.accentSubtle)
                            .clipShape(Capsule())
                    }

                    // Voice Memo badge if applicable
                    if VoiceMemosIntegration.shared.isVoiceMemoURL(file.url) {
                        HStack(spacing: 4) {
                            Image(systemName: "waveform")
                                .font(.system(size: 9))
                            Text("Voice Memo")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundColor(DesignSystem.Colors.voicePrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(DesignSystem.Colors.voicePrimary.opacity(0.15))
                        )
                    }
                }

                HStack(spacing: 12) {
                    Label(AudioPlaybackService.formatTime(result.duration), systemImage: "clock")
                    Label("\(result.segments.count) segments", systemImage: "text.alignleft")
                    if let language = result.language {
                        Label(language.uppercased(), systemImage: "globe")
                    }
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                // Copy Menu
                Menu {
                    Button {
                        viewModel.copyCleanText(file)
                    } label: {
                        Label("Clean Text", systemImage: "text.alignleft")
                    }

                    Button {
                        viewModel.copyWithTimestamps(file)
                    } label: {
                        Label("With Timestamps", systemImage: "clock")
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy")
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8))
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .menuStyle(.borderlessButton)

                // Export Menu
                Menu {
                    ForEach(ExportFormat.allCases) { format in
                        Button(format.displayName) {
                            Task {
                                await viewModel.export(file)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export")
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8))
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .menuStyle(.borderlessButton)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        VStack(spacing: 12) {
            // Status bar (when processing)
            if viewModel.isProcessing || viewModel.isPaused {
                processingStatusBar
            }

            // Main toolbar
            HStack(spacing: 12) {
                // Left: Add files
                Button {
                    openFilePicker()
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(GlassButtonStyle())

                // Queue actions menu
                Menu {
                    Button {
                        showClearQueueConfirmation = true
                    } label: {
                        Label("Clear All", systemImage: "trash")
                    }
                    .disabled(viewModel.queuedFiles.isEmpty)
                    .confirmationDialog(
                        "Clear All Files",
                        isPresented: $showClearQueueConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Clear All", role: .destructive) {
                            viewModel.clearQueue()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will remove all files from the queue. Any transcriptions in progress will be cancelled.")
                    }

                    Divider()

                    Button {
                        viewModel.removeCompleted()
                    } label: {
                        Label("Remove Completed", systemImage: "checkmark.circle")
                    }
                    .disabled(!viewModel.hasCompletedFiles)

                    Button {
                        viewModel.removeFailed()
                    } label: {
                        Label("Remove Failed", systemImage: "xmark.circle")
                    }
                    .disabled(!viewModel.hasFailedFiles)

                    if viewModel.hasFailedFiles {
                        Divider()

                        Button {
                            viewModel.retryAllFailed()
                        } label: {
                            Label("Retry All Failed", systemImage: "arrow.clockwise")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 13, weight: .medium))
                }
                .menuStyle(.borderlessButton)
                .frame(width: 32)
                .glassBackground(cornerRadius: 8)

                // Batch settings button
                Button {
                    viewModel.showBatchSettings.toggle()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(GlassButtonStyle())
                .popover(isPresented: $viewModel.showBatchSettings) {
                    batchSettingsPopover
                }

                Spacer()

                // Queue stats
                if !viewModel.queuedFiles.isEmpty {
                    HStack(spacing: 8) {
                        if viewModel.completedCount > 0 {
                            Label("\(viewModel.completedCount)", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                        if viewModel.failedCount > 0 {
                            Label("\(viewModel.failedCount)", systemImage: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                        if viewModel.pendingCount > 0 {
                            Label("\(viewModel.pendingCount)", systemImage: "clock.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                    .font(.system(size: 11, weight: .medium))
                }

                // Export
                if viewModel.canExport {
                    Menu {
                        ForEach(ExportFormat.allCases) { format in
                            Button {
                                viewModel.selectedExportFormat = format
                                Task {
                                    await viewModel.exportAll()
                                }
                            } label: {
                                Text(format.displayName)
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export All")
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8))
                        }
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .menuStyle(.borderlessButton)
                }

                // Control buttons
                processingControls
            }
        }
        .padding(16)
        .glassBackground(cornerRadius: 20, opacity: 0.1)
        .padding(16)
    }

    private var processingStatusBar: some View {
        HStack(spacing: 12) {
            // Status icon
            if viewModel.isPaused {
                Image(systemName: "pause.circle.fill")
                    .foregroundColor(.orange)
            } else {
                ProgressView()
                    .scaleEffect(0.7)
            }

            // Status text
            Text(viewModel.statusText)
                .font(.system(size: 12, weight: .medium))

            // Progress bar
            ProgressView(value: viewModel.overallProgress)
                .frame(maxWidth: 200)
                .tint(viewModel.isPaused ? .orange : .accentColor)

            // Progress percentage
            Text("\(Int(viewModel.overallProgress * 100))%")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)

            Spacer()

            // Time info
            if let elapsed = viewModel.formattedElapsedTime {
                Text("Elapsed: \(elapsed)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            if let remaining = viewModel.formattedEstimatedTime {
                Text("~\(remaining) left")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(DesignSystem.Colors.glassLight)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var processingControls: some View {
        HStack(spacing: 8) {
            if viewModel.isProcessing {
                // Pause button
                Button {
                    viewModel.pauseProcessing()
                } label: {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(GlassButtonStyle())
                .disabled(!viewModel.canPause)

                // Cancel button
                Button {
                    viewModel.cancelProcessing()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(GlassButtonStyle())

            } else if viewModel.isPaused {
                // Resume button
                Button {
                    viewModel.resumeProcessing()
                } label: {
                    Label("Resume", systemImage: "play.fill")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(PrimaryGradientButtonStyle())

                // Cancel button
                Button {
                    viewModel.cancelProcessing()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(GlassButtonStyle())

            } else {
                // Start button
                Button {
                    viewModel.startProcessing()
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .font(.system(size: 13, weight: .bold))
                }
                .buttonStyle(PrimaryGradientButtonStyle())
                .disabled(!viewModel.canStart)
            }
        }
    }

    private var batchSettingsPopover: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Batch Settings")
                .font(.system(size: 14, weight: .bold))

            // Processing mode
            VStack(alignment: .leading, spacing: 8) {
                Text("Processing Mode")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                Picker("", selection: $viewModel.processingMode) {
                    ForEach(BatchProcessingMode.allCases) { mode in
                        HStack {
                            Image(systemName: mode.icon)
                            Text(mode.rawValue)
                        }
                        .tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(viewModel.processingMode.description)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            // Concurrent jobs (only for parallel)
            if viewModel.processingMode == .parallel {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Concurrent Files")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)

                        Spacer()

                        Text("\(viewModel.maxConcurrentJobs)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                    }

                    Slider(value: Binding(
                        get: { Double(viewModel.maxConcurrentJobs) },
                        set: { viewModel.maxConcurrentJobs = Int($0) }
                    ), in: 1...4, step: 1)
                    .tint(.accentColor)

                    Text("Higher values use more memory")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Auto-retry toggle
            Toggle(isOn: $viewModel.autoRetryFailed) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Auto-retry Failed")
                        .font(.system(size: 12, weight: .medium))
                    Text("Automatically retry failed transcriptions once")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.switch)
        }
        .padding(16)
        .frame(width: 280)
    }

    // MARK: - File Picker

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = FileTranscriptionViewModel.supportedTypes

        // Add Voice Memos directory as a quick access location
        if let voiceMemosDir = VoiceMemosIntegration.shared.getVoiceMemosDirectory() {
            panel.directoryURL = voiceMemosDir
        }

        if panel.runModal() == .OK {
            viewModel.addFiles(panel.urls)
        }
    }
}

// MARK: - File Row View

struct FileRowView: View {
    let file: QueuedFile
    var isSelected: Bool = false
    var onSelect: (() -> Void)?
    var onRetry: (() -> Void)?
    var onMoveUp: (() -> Void)?
    var onMoveDown: (() -> Void)?
    let onRemove: () -> Void

    @State private var isHovered = false

    private var isVideoFile: Bool {
        VideoPlayerService.isVideoFile(file.url)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Reorder handle (only for pending files)
            if file.status == .pending && isHovered {
                VStack(spacing: 2) {
                    Button {
                        onMoveUp?()
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .buttonStyle(.plain)

                    Button {
                        onMoveDown?()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .buttonStyle(.plain)
                }
                .foregroundColor(.secondary)
                .frame(width: 16)
            } else {
                Color.clear.frame(width: 16)
            }

            statusIcon
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(file.fileName)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .lineLimit(1)

                    // Video badge
                    if isVideoFile {
                        Image(systemName: "film")
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.Colors.accent)
                    }

                    // Platform badge for remote sources
                    if file.isRemote, let platform = file.platform {
                        PlatformBadge(platform: platform)
                    }

                    // Voice Memo badge
                    if VoiceMemosIntegration.shared.isVoiceMemoURL(file.url) {
                        HStack(spacing: 3) {
                            Image(systemName: "waveform")
                                .font(.system(size: 8))
                        }
                        .foregroundColor(DesignSystem.Colors.voicePrimary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(DesignSystem.Colors.voicePrimary.opacity(0.15))
                        )
                    }
                }

                HStack(spacing: 12) {
                    Text(file.fileSize)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)

                    if let error = file.error {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                            .lineLimit(1)
                    }

                    if file.status == .completed {
                        Text("Click to view")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.accentColor)
                    }

                    if file.status == .downloading, let downloadProgress = file.downloadProgress {
                        Text("Downloading \(Int(downloadProgress * 100))%")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.blue)
                    }

                    if let duration = file.processingDuration {
                        Text("(\(formatDuration(duration)))")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Progress indicators
            if file.status == .downloading, let downloadProgress = file.downloadProgress {
                VStack(spacing: 2) {
                    ProgressView(value: downloadProgress)
                        .frame(width: 80)
                        .tint(.blue)
                    Text("Download")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.secondary)
                }
            } else if file.status == .processing {
                ProgressView(value: file.progress)
                    .frame(width: 80)
                    .tint(.accentColor)
            }

            // Action buttons
            HStack(spacing: 4) {
                if file.status == .failed {
                    Button {
                        onRetry?()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.orange)
                            .padding(6)
                            .background(Circle().fill(Color.orange.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                    .help("Retry")
                }

                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(6)
                        .background(Circle().fill(Color.secondary.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? DesignSystem.Colors.accentSubtle : Color.clear)
        )
        .glassBackground(cornerRadius: 12, opacity: 0.05)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            onSelect?()
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        ZStack {
            switch file.status {
            case .pending:
                Image(systemName: "clock.fill")
                    .foregroundColor(.secondary)
            case .downloading:
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.blue)
            case .processing:
                ProgressView()
                    .scaleEffect(0.6)
            case .paused:
                Image(systemName: "pause.circle.fill")
                    .foregroundColor(.orange)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .failed:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? ""
    }
}

// MARK: - Compact File Row (Sidebar)

struct CompactFileRow: View {
    let file: QueuedFile
    let isSelected: Bool
    let onSelect: () -> Void

    private var isVideoFile: Bool {
        VideoPlayerService.isVideoFile(file.url)
    }

    var body: some View {
        HStack(spacing: 8) {
            statusIcon
                .frame(width: 16, height: 16)

            // Video indicator
            if isVideoFile {
                Image(systemName: "film")
                    .font(.system(size: 9))
                    .foregroundColor(DesignSystem.Colors.accent)
            }

            // Platform badge for remote sources (compact)
            if file.isRemote, let platform = file.platform {
                PlatformBadge(platform: platform, compact: true)
            }

            Text(file.fileName)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .lineLimit(1)
                .foregroundColor(isSelected ? DesignSystem.Colors.accent : .primary)

            Spacer()

            // Download progress indicator
            if file.status == .downloading, let progress = file.downloadProgress {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? DesignSystem.Colors.accentSubtle : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch file.status {
        case .pending:
            Image(systemName: "clock")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        case .downloading:
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.blue)
        case .processing:
            ProgressView()
                .scaleEffect(0.4)
        case .paused:
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.orange)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.green)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.red)
        }
    }
}

// MARK: - Segment Row

struct TranscriptSegmentRow: View {
    let segment: TranscriptionSegment
    let index: Int
    let isCurrentSegment: Bool
    let isPlaying: Bool
    let compactMode: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    init(
        segment: TranscriptionSegment,
        index: Int,
        isCurrentSegment: Bool,
        isPlaying: Bool,
        compactMode: Bool = false,
        onTap: @escaping () -> Void
    ) {
        self.segment = segment
        self.index = index
        self.isCurrentSegment = isCurrentSegment
        self.isPlaying = isPlaying
        self.compactMode = compactMode
        self.onTap = onTap
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timestamp (hidden in compact mode)
            if !compactMode {
                Text(formatTime(segment.startTime))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(isCurrentSegment ? DesignSystem.Colors.accent : .secondary)
                    .frame(width: 50, alignment: .trailing)
            }

            // Playing indicator
            if isPlaying {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 10))
                    .foregroundColor(DesignSystem.Colors.accent)
                    .frame(width: 16)
            } else {
                Color.clear
                    .frame(width: 16)
            }

            // Text
            Text(segment.text)
                .font(.system(size: 14))
                .foregroundColor(isCurrentSegment ? .primary : .secondary)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isCurrentSegment ? DesignSystem.Colors.accent.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            onTap()
        }
    }

    private var backgroundColor: Color {
        if isCurrentSegment {
            return DesignSystem.Colors.accentSubtle
        } else if isHovered {
            return DesignSystem.Colors.surfaceHover
        }
        return Color.clear
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Link Transcription Tab

/// Tab for URL-based (YouTube, etc.) transcription
struct LinkTranscriptionTab: View {
    @ObservedObject var viewModel: FileTranscriptionViewModel
    @EnvironmentObject var appState: AppState
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            if viewModel.queuedLinks.isEmpty {
                urlDropZoneView
            } else if viewModel.selectedFile != nil {
                // Split view: link list + transcript
                HStack(spacing: 0) {
                    fileListSidebar
                        .frame(width: 260)

                    Divider()

                    transcriptView
                }
            } else {
                // Just the link list
                VStack(spacing: 0) {
                    fileListView
                    bottomToolbar
                }
            }
        }
        .background(Color.clear)
        .focused($isFocused)
        .onKeyPress(.escape) {
            if viewModel.selectedFileId != nil {
                viewModel.deselectFile()
                return .handled
            }
            return .ignored
        }
    }

    // MARK: - URL Drop Zone

    private var urlDropZoneView: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 80, height: 80)

                    Image(systemName: "link")
                        .font(.system(size: 32))
                        .foregroundColor(.accentColor)
                }

                VStack(spacing: 8) {
                    Text("Transcribe from URL")
                        .font(.system(size: 24, weight: .bold, design: .rounded))

                    Text("Paste a YouTube link to start")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                URLInputSection(
                    urlInput: $viewModel.urlInput,
                    isValidating: $viewModel.isValidatingURL,
                    previewMetadata: $viewModel.urlPreviewMetadata,
                    validationError: $viewModel.urlValidationError,
                    onAdd: {
                        viewModel.addURLFromPreview()
                    },
                    onValidate: {
                        viewModel.validateURL()
                    }
                )
                .frame(maxWidth: 500)
                .padding(.horizontal, 20)
            }

            // Platform support icons
            HStack(spacing: 24) {
                PlatformIcon(name: "youtube", icon: "play.rectangle.fill", color: .red)
            }
            .opacity(0.6)

            Spacer()
        }
    }

    // MARK: - Link List

    private var fileListView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Link Library")
                    .font(.system(size: 18, weight: .bold, design: .rounded))

                Spacer()

                if viewModel.isProcessing {
                    ProgressView(value: viewModel.overallProgress)
                        .frame(width: 100)
                        .tint(.accentColor)
                }

                Text("\(viewModel.completedCount)/\(viewModel.queuedFiles.count) processed")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.secondary.opacity(0.1)))
            }
            .padding(24)

            List {
                ForEach(viewModel.queuedFiles) { file in
                    FileRowView(
                        file: file,
                        isSelected: viewModel.selectedFileId == file.id,
                        onSelect: {
                            if file.status == .completed {
                                viewModel.selectFile(file)
                            }
                        },
                        onRemove: {
                            viewModel.removeFile(file)
                        }
                    )
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    // MARK: - Sidebar

    private var fileListSidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Links")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(16)

            Divider()

            List {
                ForEach(viewModel.queuedFiles) { file in
                    CompactFileRow(
                        file: file,
                        isSelected: viewModel.selectedFileId == file.id,
                        onSelect: {
                            if file.status == .completed {
                                viewModel.selectFile(file)
                            }
                        }
                    )
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            Divider()

            HStack {
                Button {
                    viewModel.deselectFile()
                } label: {
                    Image(systemName: "sidebar.right")
                }
                .buttonStyle(GlassButtonStyle())

                Spacer()

                if viewModel.isProcessing {
                    Button { viewModel.cancelProcessing() } label: { Image(systemName: "xmark") }
                        .buttonStyle(GlassButtonStyle())
                } else {
                    Button { viewModel.startProcessing() } label: { Image(systemName: "play.fill") }
                        .buttonStyle(GlassButtonStyle())
                        .disabled(viewModel.pendingCount == 0)
                }
            }
            .padding(12)
        }
        .background(DesignSystem.Colors.glassUltraLight)
    }

    // MARK: - Transcript View

    private var transcriptView: some View {
        VStack(spacing: 0) {
            if let file = viewModel.selectedFile, let result = file.result {
                transcriptHeader(file: file, result: result)
                Divider()

                // Multi-language subtitle container with translation support
                MultiLanguageSubtitleContainer(
                    result: result,
                    currentSegmentIndex: viewModel.currentSegmentIndex,
                    isPlaying: viewModel.playbackService.isPlaying,
                    compactMode: appState.settings.compactMode,
                    onSegmentTap: { segment in
                        viewModel.seekToSegment(segment)
                    }
                )

                if viewModel.playbackService.isLoaded {
                    AudioPlayerBar(playbackService: viewModel.playbackService)
                        .padding(12)
                }
            }
        }
    }

    private func transcriptHeader(file: QueuedFile, result: TranscriptionResult) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(file.fileName)
                    .font(.system(size: 16, weight: .bold))
                HStack(spacing: 12) {
                    Label(AudioPlaybackService.formatTime(result.duration), systemImage: "clock")
                    Label("\(result.segments.count) segments", systemImage: "text.alignleft")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                // Copy Menu
                Menu {
                    Button {
                        viewModel.copyCleanText(file)
                    } label: {
                        Label("Clean Text", systemImage: "text.alignleft")
                    }

                    Button {
                        viewModel.copyWithTimestamps(file)
                    } label: {
                        Label("With Timestamps", systemImage: "clock")
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy")
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8))
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .menuStyle(.borderlessButton)

                // Fixed Export Button
                Menu {
                    ForEach(ExportFormat.allCases) { format in
                        Button(format.displayName) {
                            Task { await viewModel.export(file) }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export")
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8))
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .menuStyle(.borderlessButton)
            }
        }
        .padding(16)
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack {
            Button {
                viewModel.clearQueue()
            } label: {
                Label("Clear All", systemImage: "trash")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(GlassButtonStyle())

            Spacer()

            if viewModel.isProcessing {
                Button {
                    viewModel.cancelProcessing()
                } label: {
                    Label("Cancel", systemImage: "xmark")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(GlassButtonStyle())
            } else {
                Button {
                    viewModel.startProcessing()
                } label: {
                    Label("Start Processing", systemImage: "play.fill")
                        .font(.system(size: 13, weight: .bold))
                }
                .buttonStyle(PrimaryGradientButtonStyle())
                .disabled(viewModel.pendingCount == 0)
            }
        }
        .padding(16)
        .glassBackground(cornerRadius: 20, opacity: 0.1)
        .padding(16)
    }
}

struct PlatformIcon: View {
    let name: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            Text(name.capitalized)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}

// Extension to help LinkTranscriptionTab
extension FileTranscriptionViewModel {
    var queuedLinks: [QueuedFile] {
        queuedFiles.filter { $0.isRemote }
    }
}

// MARK: - Preview
#Preview {
    FileTranscriptionTab(viewModel: FileTranscriptionViewModel(appState: AppState()))
        .environmentObject(AppState())
        .frame(width: 800, height: 600)
}
