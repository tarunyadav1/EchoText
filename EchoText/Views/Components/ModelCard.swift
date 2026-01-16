import SwiftUI

/// Card view for displaying a Whisper model
struct ModelCard: View {
    let model: WhisperModel
    let isSelected: Bool
    let isDownloaded: Bool
    let isDownloading: Bool
    let downloadProgress: Double
    let onSelect: () -> Void
    let onDownload: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Model icon
            modelIcon

            // Model info
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                HStack {
                    Text(model.name)
                        .font(.headline)

                    if isSelected {
                        Text("Active")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                }

                HStack(spacing: DesignSystem.Spacing.sm) {
                    Label(model.formattedDownloadSize, systemImage: "arrow.down.circle")
                    Label(model.formattedMemoryRequired, systemImage: "memorychip")
                }
                .font(.caption)
                .foregroundColor(.secondary)

                // Speed indicator
                HStack(spacing: 4) {
                    ForEach(0..<5) { index in
                        Rectangle()
                            .fill(index < speedBars ? speedColor : Color.secondary.opacity(0.3))
                            .frame(width: 12, height: 4)
                            .cornerRadius(2)
                    }
                    Text(speedLabel)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Action button
            actionButton
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .fill(DesignSystem.Colors.controlBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )
        )
    }

    // MARK: - Subviews

    private var modelIcon: some View {
        ZStack {
            Circle()
                .fill(iconBackgroundColor)
                .frame(width: 48, height: 48)

            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(iconColor)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if isDownloading {
            VStack(spacing: 4) {
                ProgressView(value: downloadProgress)
                    .frame(width: 60)

                Text("\(Int(downloadProgress * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        } else if isDownloaded {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
            } else {
                Button("Use") {
                    onSelect()
                }
                .buttonStyle(.borderedProminent)
            }
        } else {
            Button("Download") {
                onDownload()
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Computed Properties

    private var speedBars: Int {
        switch model.size {
        case .tiny: return 5
        case .base: return 4
        case .small: return 3
        case .medium: return 2
        case .large, .largev2, .largev3: return 1
        case .largev3Turbo: return 4
        }
    }

    private var speedLabel: String {
        switch model.size {
        case .tiny: return "Fastest"
        case .base: return "Fast"
        case .small: return "Balanced"
        case .medium: return "Accurate"
        case .large, .largev2, .largev3: return "Most Accurate"
        case .largev3Turbo: return "Fast & Accurate"
        }
    }

    private var speedColor: Color {
        switch model.size {
        case .tiny, .base: return .green
        case .small: return .orange
        case .medium: return .purple
        case .large, .largev2, .largev3: return .purple
        case .largev3Turbo: return .blue
        }
    }

    private var iconBackgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.2)
        } else if isDownloaded {
            return Color.green.opacity(0.2)
        } else {
            return Color.secondary.opacity(0.2)
        }
    }

    private var iconColor: Color {
        if isSelected {
            return .accentColor
        } else if isDownloaded {
            return .green
        } else {
            return .secondary
        }
    }

    private var iconName: String {
        switch model.size {
        case .tiny: return "hare.fill"
        case .base: return "bolt.fill"
        case .small: return "gauge.with.dots.needle.33percent"
        case .medium: return "gauge.with.dots.needle.50percent"
        case .large, .largev2, .largev3: return "gauge.with.dots.needle.67percent"
        case .largev3Turbo: return "bolt.horizontal.fill"
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 16) {
        ModelCard(
            model: WhisperModel.availableModels[0],
            isSelected: false,
            isDownloaded: false,
            isDownloading: false,
            downloadProgress: 0,
            onSelect: {},
            onDownload: {},
            onDelete: {}
        )

        ModelCard(
            model: WhisperModel.availableModels[1],
            isSelected: false,
            isDownloaded: false,
            isDownloading: true,
            downloadProgress: 0.45,
            onSelect: {},
            onDownload: {},
            onDelete: {}
        )

        ModelCard(
            model: WhisperModel.availableModels[2],
            isSelected: true,
            isDownloaded: true,
            isDownloading: false,
            downloadProgress: 1,
            onSelect: {},
            onDownload: {},
            onDelete: {}
        )
    }
    .padding()
    .frame(width: 400)
}
