import SwiftUI

/// Top toolbar for the history detail view
struct HistoryDetailToolbar: View {
    @ObservedObject var viewModel: HistoryDetailViewModel

    var body: some View {
        HStack(spacing: 12) {
            // Back button with item info
            Button {
                viewModel.dismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.accent)

                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 5) {
                            Image(systemName: viewModel.item.source.icon)
                                .font(.system(size: 10))
                                .foregroundColor(DesignSystem.Colors.textSecondary)

                            Text(viewModel.item.source.displayName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                        }

                        Text(viewModel.item.formattedTimestamp)
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                }
            }
            .buttonStyle(.plain)
            .help("Back to history (Escape)")

            Spacer()

            // Metadata badges
            metadataBadges

            Spacer()

            // Action buttons
            actionButtons
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.8))
    }

    // MARK: - Metadata Badges

    private var metadataBadges: some View {
        HStack(spacing: 8) {
            // Word count
            metadataBadge(icon: "textformat.abc", value: "\(viewModel.item.wordCount) words")

            // Duration
            metadataBadge(icon: "clock", value: viewModel.item.formattedDuration)

            // Model
            metadataBadge(icon: "cpu", value: viewModel.item.modelUsed)

            // Language if available
            if let language = viewModel.item.language {
                metadataBadge(icon: "globe", value: language.uppercased())
            }

            // Favorited segments count
            if viewModel.item.hasFavoritedSegments {
                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundColor(DesignSystem.Colors.voiceSecondary)

                    Text("\(viewModel.item.favoritedSegmentsCount)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.voiceSecondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(DesignSystem.Colors.voiceSecondary.opacity(0.1), in: Capsule())
            }

            // Edited indicator
            if viewModel.item.isEdited {
                Text("Edited")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(DesignSystem.Colors.accent.opacity(0.1), in: Capsule())
            }
        }
    }

    private func metadataBadge(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(DesignSystem.Colors.textTertiary)

            Text(value)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.05), in: Capsule())
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 6) {
            // Favorite toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.toggleFavorite()
                }
            } label: {
                Image(systemName: viewModel.item.isFavorite ? "star.fill" : "star")
                    .font(.system(size: 12))
                    .foregroundColor(viewModel.item.isFavorite ? DesignSystem.Colors.voiceSecondary : DesignSystem.Colors.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(
                        viewModel.item.isFavorite
                            ? DesignSystem.Colors.voiceSecondary.opacity(0.12)
                            : Color.primary.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: 6)
                    )
            }
            .buttonStyle(.plain)
            .help(viewModel.item.isFavorite ? "Remove from favorites" : "Add to favorites")

            // Share button
            ShareLink(item: viewModel.item.text) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("Share transcript")

            // Delete button
            Button {
                viewModel.showDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.Colors.error)
                    .frame(width: 28, height: 28)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("Delete transcription")
        }
    }
}

#Preview {
    HistoryDetailToolbar(
        viewModel: HistoryDetailViewModel(
            item: TranscriptionHistoryItem(
                id: UUID(),
                text: "Sample text for preview",
                segments: [],
                language: "en",
                duration: 30,
                processingTime: 2,
                modelUsed: "base",
                timestamp: Date(),
                source: .dictation,
                isFavorite: true,
                tags: [],
                speakerMapping: nil,
                isEdited: true
            )
        )
    )
    .frame(width: 800)
}
