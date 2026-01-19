import SwiftUI

/// Model download step in onboarding
struct ModelDownloadStep: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.purple)
                .padding(.top, 20)

            VStack(spacing: 12) {
                Text("Download Model")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Choose a speech recognition model. Larger models are more accurate but use more memory.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }

            // Model selection
            VStack(spacing: 12) {
                ForEach(viewModel.recommendedModels) { model in
                    ModelOptionCard(
                        model: model,
                        isSelected: model.id == viewModel.selectedModelId,
                        isDownloading: viewModel.isDownloading && model.id == viewModel.selectedModelId,
                        downloadProgress: viewModel.downloadProgress,
                        onSelect: {
                            viewModel.selectedModelId = model.id
                        }
                    )
                }
            }
            .frame(maxWidth: 400)

            // Download button
            if !viewModel.isModelDownloaded {
                if viewModel.isDownloading {
                    HStack(spacing: 12) {
                        ProgressView()

                        Text("Downloading...")
                            .foregroundColor(.secondary)

                        Button("Cancel") {
                            viewModel.cancelDownload()
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Button {
                        Task {
                            await viewModel.downloadSelectedModel()
                        }
                    } label: {
                        Label("Download Selected Model", systemImage: "arrow.down.circle")
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Model downloaded and ready")
                        .foregroundColor(.green)
                }
            }

            // Error display
            if let error = viewModel.downloadError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.bottom, 20)
    }
}

// MARK: - Model Option Card

struct ModelOptionCard: View {
    let model: WhisperModel
    let isSelected: Bool
    let isDownloading: Bool
    let downloadProgress: Double
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .font(.title2)

                // Model info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(model.qualityName)
                            .font(.headline)
                            .foregroundColor(.primary)

                        if model.size == .base {
                            Text("Recommended")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }

                    Text(model.qualityDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        Text(model.formattedDownloadSize)
                        Text("•")
                        Text(model.formattedMemoryRequired + " RAM")
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.8))
                }

                Spacer()

                // Download progress or size indicator
                if isDownloading {
                    ProgressView(value: downloadProgress)
                        .frame(width: 50)
                } else {
                    Text(speedLabel)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(speedColor.opacity(0.2))
                        .foregroundColor(speedColor)
                        .cornerRadius(4)
                }
            }
            .padding()
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var speedLabel: String {
        switch model.size {
        case .tiny, .base:
            return "Fast"
        case .small:
            return "Balanced"
        case .medium, .large, .largev2, .largev3:
            return "Accurate"
        case .largev3Turbo:
            return "Best"
        }
    }

    private var speedColor: Color {
        switch model.size {
        case .tiny, .base:
            return .green
        case .small:
            return .orange
        case .medium, .large, .largev2, .largev3:
            return .purple
        case .largev3Turbo:
            return .blue
        }
    }
}

// MARK: - Preview
#Preview {
    ModelDownloadStep(viewModel: OnboardingViewModel(appState: AppState()))
        .frame(width: 600, height: 500)
}
