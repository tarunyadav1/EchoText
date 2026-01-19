import SwiftUI
import UniformTypeIdentifiers

/// Main view for batch transcription feature
struct BatchTranscriptionView: View {
    @ObservedObject var viewModel: BatchTranscriptionViewModel
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            if viewModel.isEmpty {
                emptyStateView
            } else if viewModel.selectedFile != nil {
                // Split view: queue list + transcript details
                HStack(spacing: 0) {
                    queueSidebar
                        .frame(width: 280)

                    Divider()

                    transcriptDetailView
                }
            } else {
                // Full queue view
                VStack(spacing: 0) {
                    queueListView
                    bottomToolbar
                }
            }

            // Success toast
            if viewModel.showSuccess, let message = viewModel.successMessage {
                successToast(message: message)
            }
        }
        .background(Color.clear)
        .onDrop(of: [.fileURL, .audio, .movie], isTargeted: $viewModel.isDragging) { providers in
            viewModel.handleDrop(providers: providers)
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .onAppear {
            // View configured via MainWindow
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Drop zone
            BatchDropZone(
                isDragging: $viewModel.isDragging,
                onDrop: { urls in
                    viewModel.addFiles(urls)
                },
                onChooseFiles: {
                    viewModel.openFilePicker()
                }
            )
            .scaleEffect(viewModel.isDragging ? 1.02 : 1.0)
            .animation(.spring(response: 0.3), value: viewModel.isDragging)

            // Supported formats tip
            supportedFormatsTip

            Spacer()
        }
        .padding(.vertical, 20)
    }

    private var supportedFormatsTip: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(DesignSystem.Colors.accent)

            Text("Supports MP3, WAV, M4A, MP4, MOV, and more")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(DesignSystem.Colors.accentSubtle)
        )
        .opacity(0.8)
    }

    // MARK: - Queue List View (Full)

    private var queueListView: some View {
        VStack(spacing: 0) {
            // Header
            queueHeader

            // File list
            List {
                ForEach(viewModel.queue) { file in
                    BatchFileRow(
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

    private var queueHeader: some View {
        HStack {
            Text("Batch Queue")
                .font(.system(size: 18, weight: .bold, design: .rounded))

            Spacer()

            // Overall progress indicator
            if viewModel.isProcessing {
                ProgressView(value: viewModel.overallProgress)
                    .frame(width: 100)
                    .tint(DesignSystem.Colors.accent)
            }

            // Stats badge
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

            Text("\(viewModel.completedCount)/\(viewModel.queue.count) done")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.secondary.opacity(0.1)))
        }
        .padding(24)
    }

    // MARK: - Queue Sidebar (Split View)

    private var queueSidebar: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Files")
                    .font(.system(size: 14, weight: .bold, design: .rounded))

                Spacer()

                Text("\(viewModel.completedCount)/\(viewModel.queue.count)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // File list
            List {
                ForEach(viewModel.queue) { file in
                    CompactBatchFileRow(
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

            // Sidebar controls
            sidebarControls
        }
        .background(DesignSystem.Colors.glassUltraLight)
    }

    private var sidebarControls: some View {
        VStack(spacing: 8) {
            // Compact drop zone for adding more files
            CompactBatchDropZone(
                onDrop: { urls in
                    viewModel.addFiles(urls)
                }
            )

            // Control buttons
            HStack(spacing: 8) {
                Button {
                    viewModel.openFilePicker()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(GlassButtonStyle())

                if viewModel.isProcessing {
                    Button {
                        viewModel.pauseProcessing()
                    } label: {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(GlassButtonStyle())

                    Button {
                        viewModel.cancelProcessing()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(GlassButtonStyle())
                } else if viewModel.isPaused {
                    Button {
                        viewModel.resumeProcessing()
                    } label: {
                        Image(systemName: "play.fill")
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
                    .disabled(!viewModel.canStart)
                }

                Spacer()

                Button {
                    viewModel.deselectFile()
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

    // MARK: - Transcript Detail View

    private var transcriptDetailView: some View {
        VStack(spacing: 0) {
            if let file = viewModel.selectedFile, let result = file.result {
                // Header
                transcriptHeader(file: file, result: result)

                Divider()

                // Transcript content
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(result.segments, id: \.uuid) { segment in
                            BatchSegmentRow(segment: segment)
                        }
                    }
                    .padding(16)
                }

                // Footer with stats
                transcriptFooter(result: result)
            } else {
                emptyDetailView
            }
        }
        .onKeyPress(.escape) {
            viewModel.deselectFile()
            return .handled
        }
    }

    private var emptyDetailView: some View {
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

    private func transcriptHeader(file: BatchQueuedFile, result: TranscriptionResult) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(file.fileName)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .lineLimit(1)

                HStack(spacing: 12) {
                    Label(formatDuration(result.duration), systemImage: "clock")
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
                        viewModel.copyTranscript(file)
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
                            viewModel.selectedExportFormat = format
                            viewModel.exportFile(file)
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

    private func transcriptFooter(result: TranscriptionResult) -> some View {
        HStack {
            Text("\(result.wordCount) words")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            Spacer()

            Text("Processed in \(String(format: "%.1f", result.processingTime))s")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(DesignSystem.Colors.glassUltraLight)
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
                    viewModel.openFilePicker()
                } label: {
                    Label("Add Files", systemImage: "plus")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(GlassButtonStyle())

                // Queue actions menu
                Menu {
                    Button {
                        viewModel.clearQueue()
                    } label: {
                        Label("Clear All", systemImage: "trash")
                    }
                    .disabled(viewModel.isEmpty)

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

                // Settings button
                Button {
                    viewModel.showSettings.toggle()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(GlassButtonStyle())
                .popover(isPresented: $viewModel.showSettings) {
                    batchSettingsPopover
                }

                Spacer()

                // Queue info
                if !viewModel.isEmpty {
                    Text(viewModel.totalQueueSize)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                // Export all button
                if viewModel.canExport {
                    Menu {
                        ForEach(ExportFormat.allCases) { format in
                            Button(format.displayName) {
                                viewModel.selectedExportFormat = format
                                viewModel.exportAll()
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

                // Processing controls
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
                .tint(viewModel.isPaused ? .orange : DesignSystem.Colors.accent)

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

            // Auto-save toggle
            Toggle(isOn: $viewModel.autoSaveEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Auto-save Results")
                        .font(.system(size: 12, weight: .medium))
                    Text("Save transcript alongside each source file")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.switch)

            // Auto-save format (only when enabled)
            if viewModel.autoSaveEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Auto-save Format")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)

                    Picker("", selection: $viewModel.autoSaveFormat) {
                        ForEach(ExportFormat.allCases) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            Divider()

            // Retry settings
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Auto-retry Attempts")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(viewModel.maxRetryAttempts)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                }

                Slider(value: Binding(
                    get: { Double(viewModel.maxRetryAttempts) },
                    set: { viewModel.maxRetryAttempts = Int($0) }
                ), in: 0...3, step: 1)
                .tint(DesignSystem.Colors.accent)

                Text("Automatically retry failed transcriptions")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .frame(width: 280)
    }

    // MARK: - Success Toast

    private func successToast(message: String) -> some View {
        VStack {
            Spacer()

            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)

                Text(message)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: Capsule())
            .shadow(color: DesignSystem.Shadows.medium, radius: 8, y: 4)
            .padding(.bottom, 100)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.showSuccess)
    }

    // MARK: - Helpers

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Batch Drop Zone

struct BatchDropZone: View {
    @Binding var isDragging: Bool
    let onDrop: ([URL]) -> Void
    let onChooseFiles: () -> Void

    @State private var pulseAnimation = false

    var body: some View {
        ZStack {
            // Background
            dropBackground

            // Content
            VStack(spacing: 24) {
                iconView

                VStack(spacing: 8) {
                    Text("Drop multiple files for batch transcription")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(isDragging ? DesignSystem.Colors.accent : .primary)

                    Text("Audio and video files will be queued and processed sequentially")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Button(action: onChooseFiles) {
                    Label("Choose Files", systemImage: "folder")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(PrimaryGradientButtonStyle())
                .contentShape(Rectangle())
            }
        }
        .frame(maxWidth: 500, maxHeight: 350)
        .onDrop(of: [.fileURL, .audio, .movie], isTargeted: $isDragging) { providers in
            handleDrop(providers: providers)
        }
    }

    private var dropBackground: some View {
        ZStack {
            // Outer glow when dragging
            if isDragging {
                RoundedRectangle(cornerRadius: 24)
                    .fill(DesignSystem.Colors.accent.opacity(0.15))
                    .blur(radius: 20)
                    .scaleEffect(1.05)
            }

            // Main border
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(
                    isDragging ? borderGradientActive : borderGradientInactive,
                    style: StrokeStyle(lineWidth: isDragging ? 3 : 2, dash: [12, 8])
                )

            // Glass background
            RoundedRectangle(cornerRadius: 24)
                .fill(isDragging ? DesignSystem.Colors.accentSubtle : DesignSystem.Colors.glassDark)
        }
    }

    private var borderGradientActive: LinearGradient {
        LinearGradient(
            colors: [DesignSystem.Colors.accent, DesignSystem.Colors.voicePrimary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var borderGradientInactive: LinearGradient {
        LinearGradient(
            colors: [DesignSystem.Colors.accent.opacity(0.5), DesignSystem.Colors.voicePrimary.opacity(0.5)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var iconView: some View {
        ZStack {
            Circle()
                .fill(isDragging ? DesignSystem.Colors.accentSubtle : DesignSystem.Colors.accent.opacity(0.1))
                .frame(width: 80, height: 80)
                .scaleEffect(isDragging ? 1.1 : 1.0)

            if isDragging {
                Circle()
                    .stroke(DesignSystem.Colors.accent.opacity(0.5), lineWidth: 2)
                    .frame(width: 80, height: 80)
                    .scaleEffect(pulseAnimation ? 1.4 : 1.0)
                    .opacity(pulseAnimation ? 0 : 1)
                    .animation(
                        .easeOut(duration: 1.0).repeatForever(autoreverses: false),
                        value: pulseAnimation
                    )
                    .onAppear { pulseAnimation = true }
                    .onDisappear { pulseAnimation = false }
            }

            Image(systemName: "doc.on.doc.fill")
                .font(.system(size: 32))
                .foregroundColor(isDragging ? DesignSystem.Colors.accent : DesignSystem.Colors.accent)
                .scaleEffect(isDragging ? 1.2 : 1.0)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            let types = provider.registeredTypeIdentifiers

            // Try loading as file URL first
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                loadFileURL(from: provider, typeIdentifier: UTType.fileURL.identifier)
            }
            // Try loading from any audio/video type
            else if let audioType = types.first(where: { type in
                UTType(type)?.conforms(to: .audio) == true || UTType(type)?.conforms(to: .movie) == true
            }) {
                loadFileURL(from: provider, typeIdentifier: audioType)
            }
            // Fallback to URL object loading
            else if provider.canLoadObject(ofClass: URL.self) {
                _ = provider.loadObject(ofClass: URL.self) { [self] url, _ in
                    if let url = url {
                        DispatchQueue.main.async {
                            self.onDrop([url])
                        }
                    }
                }
            }
            // Last resort: try first type
            else if let firstType = types.first {
                loadFileURL(from: provider, typeIdentifier: firstType)
            }
        }

        return true
    }

    private func loadFileURL(from provider: NSItemProvider, typeIdentifier: String) {
        provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { [self] item, error in
            guard error == nil else { return }

            DispatchQueue.main.async {
                if let data = item as? Data {
                    // Try as URL string
                    if let urlString = String(data: data, encoding: .utf8),
                       let url = URL(string: urlString) {
                        self.onDrop([url])
                        return
                    }
                    // Try as bookmark
                    var isStale = false
                    if let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale) {
                        self.onDrop([url])
                        return
                    }
                }

                if let url = item as? URL {
                    self.onDrop([url])
                } else if let nsurl = item as? NSURL, let url = nsurl as URL? {
                    self.onDrop([url])
                }
            }
        }
    }
}

// MARK: - Compact Batch Drop Zone

struct CompactBatchDropZone: View {
    let onDrop: ([URL]) -> Void

    @State private var isDragging = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(isDragging ? DesignSystem.Colors.accent : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Drop files here")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isDragging ? DesignSystem.Colors.accent : .primary)

                Text("to add to queue")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDragging ? DesignSystem.Colors.accentSubtle : DesignSystem.Colors.glassDark)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            isDragging ? DesignSystem.Colors.accent : Color.clear,
                            lineWidth: 2
                        )
                )
        )
        .animation(DesignSystem.Animations.quick, value: isDragging)
        .onDrop(of: [.fileURL, .audio, .movie], isTargeted: $isDragging) { providers in
            for provider in providers {
                // Try loading as file URL first (most common for Finder drops)
                if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                        DispatchQueue.main.async {
                            if let data = item as? Data,
                               let urlString = String(data: data, encoding: .utf8),
                               let url = URL(string: urlString) {
                                onDrop([url])
                            } else if let url = item as? URL {
                                onDrop([url])
                            }
                        }
                    }
                }
                // Fallback to URL object loading
                else if provider.canLoadObject(ofClass: URL.self) {
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        if let url = url {
                            DispatchQueue.main.async {
                                onDrop([url])
                            }
                        }
                    }
                }
            }

            return true
        }
    }
}

// MARK: - Batch File Row

struct BatchFileRow: View {
    let file: BatchQueuedFile
    var isSelected: Bool = false
    var onSelect: (() -> Void)?
    var onRetry: (() -> Void)?
    var onMoveUp: (() -> Void)?
    var onMoveDown: (() -> Void)?
    let onRemove: () -> Void

    @State private var isHovered = false

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

            // Status icon
            statusIcon
                .frame(width: 24, height: 24)

            // File info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(file.fileName)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .lineLimit(1)

                    // File type badge
                    Text(file.fileExtension)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.accent)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(DesignSystem.Colors.accentSubtle)
                        .clipShape(Capsule())
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
                            .foregroundColor(DesignSystem.Colors.accent)
                    }

                    if let duration = file.processingDuration {
                        Text("(\(formatDuration(duration)))")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Progress indicator
            if file.status == .processing {
                ProgressView(value: file.progress)
                    .frame(width: 80)
                    .tint(DesignSystem.Colors.accent)
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
            case .processing:
                ProgressView()
                    .scaleEffect(0.6)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .failed:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.red)
            case .cancelled:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
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

// MARK: - Compact Batch File Row

struct CompactBatchFileRow: View {
    let file: BatchQueuedFile
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            statusIcon
                .frame(width: 16, height: 16)

            Text(file.fileName)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .lineLimit(1)
                .foregroundColor(isSelected ? DesignSystem.Colors.accent : .primary)

            Spacer()

            // Progress for processing
            if file.status == .processing {
                Text("\(Int(file.progress * 100))%")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(DesignSystem.Colors.accent)
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
        case .processing:
            ProgressView()
                .scaleEffect(0.4)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.green)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.red)
        case .cancelled:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
    }
}

// MARK: - Batch Segment Row

struct BatchSegmentRow: View {
    let segment: TranscriptionSegment

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timestamp
            Text(formatTime(segment.startTime))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .trailing)

            // Text
            Text(segment.text)
                .font(.system(size: 14))
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Preview

#Preview("Empty State") {
    BatchTranscriptionView(viewModel: BatchTranscriptionViewModel(appState: AppState()))
        .environmentObject(AppState())
        .frame(width: 800, height: 600)
}
