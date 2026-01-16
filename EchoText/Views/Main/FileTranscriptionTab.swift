import SwiftUI
import UniformTypeIdentifiers

/// Tab for file-based transcription
struct FileTranscriptionTab: View {
    @ObservedObject var viewModel: FileTranscriptionViewModel

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.queuedFiles.isEmpty {
                dropZoneView
            } else {
                fileListView
            }

            Divider()

            bottomToolbar
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onDrop(of: [.fileURL], isTargeted: $viewModel.isDragging) { providers in
            viewModel.handleDrop(providers: providers)
        }
    }

    // MARK: - Drop Zone

    private var dropZoneView: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 2, dash: [10])
                    )
                    .foregroundColor(viewModel.isDragging ? .accentColor : .secondary.opacity(0.5))

                VStack(spacing: 16) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(viewModel.isDragging ? .accentColor : .secondary)

                    VStack(spacing: 8) {
                        Text("Drop audio or video files here")
                            .font(.headline)

                        Text("Supports MP3, WAV, M4A, MP4, MOV, and more")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Button("Choose Files...") {
                        openFilePicker()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(40)
            }
            .frame(maxWidth: 400, maxHeight: 250)
            .animation(.easeInOut, value: viewModel.isDragging)

            Spacer()
        }
        .padding(24)
    }

    // MARK: - File List

    private var fileListView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Files to Transcribe")
                    .font(.headline)

                Spacer()

                if viewModel.isProcessing {
                    ProgressView(value: viewModel.overallProgress)
                        .frame(width: 100)
                }

                Text("\(viewModel.completedCount)/\(viewModel.queuedFiles.count) complete")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()

            Divider()

            // File list
            List {
                ForEach(viewModel.queuedFiles) { file in
                    FileRowView(file: file) {
                        viewModel.removeFile(file)
                    }
                }
            }
            .listStyle(.inset)
        }
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack(spacing: 16) {
            // Add files button
            Button {
                openFilePicker()
            } label: {
                Label("Add Files", systemImage: "plus")
            }

            // Clear button
            Button {
                viewModel.clearQueue()
            } label: {
                Label("Clear All", systemImage: "trash")
            }
            .disabled(viewModel.queuedFiles.isEmpty)

            Spacer()

            // Export format picker
            Picker("Format:", selection: $viewModel.selectedExportFormat) {
                ForEach(ExportFormat.allCases) { format in
                    Text(format.displayName).tag(format)
                }
            }
            .frame(width: 180)

            // Export button
            Button {
                Task {
                    await viewModel.exportAll()
                }
            } label: {
                Label("Export All", systemImage: "square.and.arrow.up")
            }
            .disabled(!viewModel.canExport)

            // Process button
            if viewModel.isProcessing {
                Button("Cancel") {
                    viewModel.cancelProcessing()
                }
                .buttonStyle(.bordered)
            } else {
                Button("Start Transcription") {
                    viewModel.startProcessing()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.queuedFiles.isEmpty)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - File Picker

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = FileTranscriptionViewModel.supportedTypes

        if panel.runModal() == .OK {
            viewModel.addFiles(panel.urls)
        }
    }
}

// MARK: - File Row View

struct FileRowView: View {
    let file: QueuedFile
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            statusIcon

            // File info
            VStack(alignment: .leading, spacing: 2) {
                Text(file.fileName)
                    .font(.body)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(file.fileSize)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let error = file.error {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Progress or actions
            if file.status == .processing {
                ProgressView(value: file.progress)
                    .frame(width: 100)
            } else if file.status == .completed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else if file.status == .failed {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.red)
            }

            // Remove button
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch file.status {
        case .pending:
            Image(systemName: "clock")
                .foregroundColor(.secondary)
        case .processing:
            ProgressView()
                .scaleEffect(0.7)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
        }
    }
}

// MARK: - Preview
#Preview {
    FileTranscriptionTab(viewModel: FileTranscriptionViewModel(appState: AppState()))
        .frame(width: 600, height: 500)
}
