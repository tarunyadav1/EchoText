import SwiftUI

/// Right sidebar for the history detail view with controls
struct HistoryDetailSidebar: View {
    @ObservedObject var viewModel: HistoryDetailViewModel
    @ObservedObject var playbackService: AudioPlaybackService

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // Quick Actions Section
                quickActionsSection

                // View Mode Section
                viewModeSection

                // People Section (Speaker Management)
                if !viewModel.speakerMapping.isEmpty {
                    peopleSection
                }

                // Appearance Section
                appearanceSection

                // Filters Section
                filtersSection

                Spacer(minLength: 20)
            }
            .padding(16)
        }
        .frame(width: 260)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
    }

    // MARK: - Quick Actions Section

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Quick Actions")

            // Compact button row
            HStack(spacing: 6) {
                // Copy button
                Button {
                    viewModel.copyToClipboard()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: viewModel.showCopied ? "checkmark" : "doc.on.doc.fill")
                            .font(.system(size: 10))
                        Text(viewModel.showCopied ? "Copied" : "Copy")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(viewModel.showCopied ? DesignSystem.Colors.success : DesignSystem.Colors.accent, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .fixedSize()

                // Copy As menu
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
                    HStack(spacing: 3) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 9))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 7))
                    }
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                }
                .menuStyle(.borderlessButton)

                // Export menu
                Menu {
                    ForEach(ExportFormat.allCases) { format in
                        Button {
                            Task {
                                await viewModel.exportTranscription(format: format)
                            }
                        } label: {
                            Label(format.displayName, systemImage: "doc")
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 9))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 7))
                    }
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                }
                .menuStyle(.borderlessButton)

                Spacer()
            }
        }
    }

    // MARK: - View Mode Section

    private var viewModeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("View Mode")

            HStack(spacing: 0) {
                ForEach(HistoryDetailViewMode.allCases, id: \.self) { mode in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.viewMode = mode
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 11))
                            Text(mode.rawValue)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(viewModel.viewMode == mode ? .white : DesignSystem.Colors.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            viewModel.viewMode == mode
                                ? DesignSystem.Colors.accent
                                : Color.primary.opacity(0.06),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - People Section

    private var peopleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader("People")

                Spacer()

                Button {
                    viewModel.showSpeakerManager = true
                } label: {
                    Text("Edit")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.accent)
                }
                .buttonStyle(.plain)
                .help("Edit speaker names")
            }

            // Speaker legend
            VStack(alignment: .leading, spacing: 6) {
                ForEach(viewModel.speakerMapping.speakers) { speaker in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(DesignSystem.Colors.speakerColor(at: speaker.colorIndex))
                            .frame(width: 8, height: 8)

                        Text(speaker.displayName)
                            .font(.system(size: 12))
                            .foregroundColor(DesignSystem.Colors.textPrimary)

                        Spacer()

                        // Segment count for this speaker
                        let count = viewModel.item.segments.filter { $0.speakerId == speaker.id }.count
                        Text("\(count)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(10)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Appearance")

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Font Size")
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Spacer()

                    Text("\(Int(viewModel.fontSize))pt")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(DesignSystem.Colors.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(DesignSystem.Colors.accentSubtle, in: RoundedRectangle(cornerRadius: 4))
                }

                HStack(spacing: 10) {
                    Text("A")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textTertiary)

                    Slider(value: $viewModel.fontSize, in: 12...24, step: 1)
                        .tint(DesignSystem.Colors.accent)

                    Text("A")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
            }
            .padding(10)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Filters Section

    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Filters")

            VStack(spacing: 8) {
                // Favorites only toggle
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.Colors.voiceSecondary)

                        Text("Favorites only")
                            .font(.system(size: 12))
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    }

                    Spacer()

                    Toggle("", isOn: $viewModel.showFavoritesOnly)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .scaleEffect(0.8)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))

                // Group segments toggle
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "rectangle.stack")
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        Text("Group by speaker")
                            .font(.system(size: 12))
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    }

                    Spacer()

                    Toggle("", isOn: $viewModel.groupSegments)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .scaleEffect(0.8)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                .disabled(viewModel.speakerMapping.isEmpty)
                .opacity(viewModel.speakerMapping.isEmpty ? 0.5 : 1)
            }
        }
    }

    // MARK: - Helper Views

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.tertiary)
            .tracking(0.8)
    }
}

#Preview {
    HistoryDetailSidebar(
        viewModel: HistoryDetailViewModel(
            item: TranscriptionHistoryItem(
                id: UUID(),
                text: "Sample text",
                segments: [],
                language: "en",
                duration: 30,
                processingTime: 2,
                modelUsed: "base",
                timestamp: Date(),
                source: .dictation,
                isFavorite: false,
                tags: [],
                speakerMapping: SpeakerMapping(speakers: [
                    Speaker(id: "speaker_0", displayName: "John", colorIndex: 0),
                    Speaker(id: "speaker_1", displayName: "Sarah", colorIndex: 1)
                ])
            )
        ),
        playbackService: AudioPlaybackService()
    )
    .frame(height: 600)
}
