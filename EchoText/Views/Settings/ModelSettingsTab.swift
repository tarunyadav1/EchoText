import SwiftUI

/// Model management settings tab
struct ModelSettingsTab: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: ModelManagerViewModel

    init() {
        // Note: This is a workaround - in actual usage, this will be initialized properly
        _viewModel = StateObject(wrappedValue: ModelManagerViewModel(appState: AppState()))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Speech Recognition Models")
                        .font(.headline)

                    Text("Storage used: \(viewModel.totalStorageUsed)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if viewModel.isModelLoaded {
                    Label("Model loaded", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }
            .padding()

            Divider()

            // Model list
            List(viewModel.models) { model in
                ModelRow(
                    model: model,
                    isSelected: model.id == viewModel.selectedModelId,
                    downloadState: viewModel.downloadState(for: model.id),
                    onSelect: {
                        Task {
                            await viewModel.selectModel(model.id)
                        }
                    },
                    onDownload: {
                        Task {
                            await viewModel.downloadModel(model.id)
                        }
                    },
                    onCancel: {
                        viewModel.cancelDownload(model.id)
                    },
                    onDelete: {
                        viewModel.deleteModel(model.id)
                    }
                )
            }
            .listStyle(.inset)

            // Error display
            if let error = viewModel.loadingError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                }
                .padding()
            }
        }
        .onAppear {
            // Re-initialize with actual app state
            // In practice, this would use dependency injection
        }
    }
}

// MARK: - Model Row

struct ModelRow: View {
    let model: WhisperModel
    let isSelected: Bool
    let downloadState: ModelDownloadState
    let onSelect: () -> Void
    let onDownload: () -> Void
    let onCancel: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Selection indicator
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .font(.title3)

            // Model info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(model.name)
                        .font(.headline)

                    if model.id == WhisperModel.defaultModel.id {
                        Text("Recommended")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.2))
                            .cornerRadius(4)
                    }
                }

                HStack(spacing: 12) {
                    Label(model.formattedDownloadSize, systemImage: "arrow.down.circle")
                    Label(model.formattedMemoryRequired, systemImage: "memorychip")

                    if model.isMultilingual {
                        Label("Multilingual", systemImage: "globe")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            // Actions
            actionButton
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            if downloadState.status == .downloaded {
                onSelect()
            }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch downloadState.status {
        case .notDownloaded:
            Button("Download") {
                onDownload()
            }
            .buttonStyle(.bordered)

        case .downloading:
            HStack(spacing: 8) {
                ProgressView(value: downloadState.progress)
                    .frame(width: 60)

                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

        case .downloaded:
            Menu {
                if !isSelected {
                    Button("Use This Model") {
                        onSelect()
                    }
                }
                Button("Delete", role: .destructive) {
                    onDelete()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)

        case .failed:
            Button("Retry") {
                onDownload()
            }
            .buttonStyle(.bordered)
            .tint(.orange)
        }
    }
}

// MARK: - Preview
#Preview {
    ModelSettingsTab()
        .environmentObject(AppState())
        .frame(width: 500, height: 400)
}
