import SwiftUI
import Translation

/// View model for managing multi-language subtitle display
@MainActor
final class MultiLanguageSubtitleViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isEnabled: Bool = false
    @Published var targetLanguage: TranslationLanguage = .spanish
    @Published var translatedSegments: [TranscriptionSegment] = []
    @Published var isTranslating: Bool = false
    @Published var translationProgress: Double = 0.0
    @Published var translationError: String?

    /// Translation configuration - setting this triggers the translationTask
    @Published var translationConfig: TranslationSession.Configuration?

    // MARK: - Properties
    var result: TranscriptionResult?
    var pendingTranslationSegments: [TranscriptionSegment] = []

    // MARK: - Translation Cache
    private var translationCache: [String: String] = [:]

    // MARK: - Methods

    /// Trigger translation for the current result
    func triggerTranslation() {
        guard let result = result else { return }
        guard isEnabled else {
            translatedSegments = []
            return
        }

        isTranslating = true
        translationError = nil
        translationProgress = 0.0

        // Store segments to translate
        pendingTranslationSegments = result.segments

        // Detect source language or use auto-detect (nil)
        let sourceLocale = result.sourceTranslationLanguage?.localeLanguage

        // Create a new configuration to trigger the translationTask
        // Using a new instance ensures the task fires even if language is the same
        translationConfig = TranslationSession.Configuration(
            source: sourceLocale,
            target: targetLanguage.localeLanguage
        )
    }

    /// Translate segments using the provided session from translationTask
    func translateWithSession(_ session: TranslationSession) async {
        guard !pendingTranslationSegments.isEmpty else {
            isTranslating = false
            return
        }

        do {
            // Prepare translation (downloads language models if needed)
            try await session.prepareTranslation()

            var translated: [TranscriptionSegment] = []
            let total = Double(pendingTranslationSegments.count)

            for (index, segment) in pendingTranslationSegments.enumerated() {
                // Check cache first
                let cacheKey = "\(segment.text.hashValue)_\(targetLanguage.rawValue)"

                let translatedText: String
                if let cached = translationCache[cacheKey] {
                    translatedText = cached
                } else {
                    // Translate using Apple's framework
                    let response = try await session.translate(segment.text)
                    translatedText = response.targetText

                    // Cache the result
                    translationCache[cacheKey] = translatedText
                }

                let translatedSegment = TranscriptionSegment(
                    id: segment.id,
                    uuid: segment.uuid,
                    text: translatedText,
                    startTime: segment.startTime,
                    endTime: segment.endTime,
                    speakerId: segment.speakerId,
                    isFavorite: segment.isFavorite
                )
                translated.append(translatedSegment)

                // Update progress on main actor
                translationProgress = Double(index + 1) / total
            }

            translatedSegments = translated
            translationProgress = 1.0
            translationError = nil

        } catch {
            translationError = error.localizedDescription
            translatedSegments = []
        }

        isTranslating = false
        pendingTranslationSegments = []
    }

    /// Update translation when language changes
    func onLanguageChanged() {
        triggerTranslation()
    }

    /// Toggle multi-language mode
    func toggleEnabled() {
        isEnabled.toggle()
        if isEnabled {
            triggerTranslation()
        } else {
            translatedSegments = []
            translationConfig = nil
        }
    }

    /// Set the transcription result
    func setResult(_ newResult: TranscriptionResult?) {
        result = newResult
        if isEnabled && newResult != nil {
            triggerTranslation()
        } else {
            translatedSegments = []
        }
    }

    /// Clear the cache
    func clearCache() {
        translationCache.removeAll()
    }
}

/// Side-by-side multi-language subtitle view
struct MultiLanguageSubtitleView: View {
    let segments: [TranscriptionSegment]
    let translatedSegments: [TranscriptionSegment]
    let sourceLanguage: TranslationLanguage?
    let targetLanguage: TranslationLanguage
    let currentSegmentIndex: Int?
    let isPlaying: Bool
    let compactMode: Bool
    let onSegmentTap: (TranscriptionSegment) -> Void

    @State private var scrollPosition: Int?

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Original language column
                languageColumn(
                    title: sourceLanguage?.displayName ?? "Original",
                    flag: sourceLanguage?.flagEmoji ?? "",
                    segments: segments,
                    isTranslated: false,
                    width: geometry.size.width / 2
                )

                // Divider
                Rectangle()
                    .fill(DesignSystem.Colors.border)
                    .frame(width: 1)

                // Translated language column
                languageColumn(
                    title: targetLanguage.displayName,
                    flag: targetLanguage.flagEmoji,
                    segments: translatedSegments,
                    isTranslated: true,
                    width: geometry.size.width / 2
                )
            }
        }
    }

    @ViewBuilder
    private func languageColumn(
        title: String,
        flag: String,
        segments: [TranscriptionSegment],
        isTranslated: Bool,
        width: CGFloat
    ) -> some View {
        VStack(spacing: 0) {
            // Column header
            HStack(spacing: 8) {
                Text(flag)
                    .font(.system(size: 16))

                Text(title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Spacer()

                if isTranslated {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(DesignSystem.Colors.glassUltraLight)

            Divider()

            // Segments list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(Array(segments.enumerated()), id: \.element.uuid) { index, segment in
                            MultiLanguageSegmentRow(
                                segment: segment,
                                index: index,
                                isCurrentSegment: currentSegmentIndex == index,
                                isPlaying: isPlaying && currentSegmentIndex == index,
                                isTranslated: isTranslated,
                                compactMode: compactMode,
                                onTap: {
                                    // Find original segment to seek to
                                    if isTranslated && index < self.segments.count {
                                        onSegmentTap(self.segments[index])
                                    } else {
                                        onSegmentTap(segment)
                                    }
                                }
                            )
                            .id(index)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                }
                .onChange(of: currentSegmentIndex) { _, newIndex in
                    if let index = newIndex {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(index, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(width: width)
    }
}

/// Individual segment row for multi-language view
struct MultiLanguageSegmentRow: View {
    let segment: TranscriptionSegment
    let index: Int
    let isCurrentSegment: Bool
    let isPlaying: Bool
    let isTranslated: Bool
    let compactMode: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Timestamp (only in original column and non-compact mode)
            if !isTranslated && !compactMode {
                Text(formatTime(segment.startTime))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(isCurrentSegment ? DesignSystem.Colors.accent : DesignSystem.Colors.textTertiary)
                    .frame(width: 44, alignment: .trailing)
            }

            // Playing indicator
            if isPlaying {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 9))
                    .foregroundColor(DesignSystem.Colors.accent)
                    .frame(width: 14)
            } else if !isTranslated && !compactMode {
                Color.clear
                    .frame(width: 14)
            }

            // Text content
            Text(segment.text)
                .font(.system(size: 13))
                .foregroundColor(isCurrentSegment ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isCurrentSegment ? DesignSystem.Colors.accent.opacity(0.4) : Color.clear,
                    lineWidth: 1
                )
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

/// Language selector dropdown for translation target
struct TranslationLanguagePicker: View {
    @Binding var selectedLanguage: TranslationLanguage
    let sourceLanguage: TranslationLanguage?
    var onChange: (() -> Void)?

    var body: some View {
        Menu {
            ForEach(availableLanguages, id: \.self) { language in
                Button {
                    selectedLanguage = language
                    onChange?()
                } label: {
                    HStack {
                        Text(language.flagEmoji)
                        Text(language.displayName)
                        if selectedLanguage == language {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(selectedLanguage.flagEmoji)
                    .font(.system(size: 14))

                Text(selectedLanguage.displayName)
                    .font(.system(size: 12, weight: .medium))

                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(DesignSystem.Colors.glassLight)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .menuStyle(.borderlessButton)
    }

    private var availableLanguages: [TranslationLanguage] {
        // Filter out source language
        TranslationLanguage.allCases.filter { $0 != sourceLanguage }
    }
}

/// Toggle button for enabling/disabling multi-language mode
struct MultiLanguageToggle: View {
    @Binding var isEnabled: Bool
    let isTranslating: Bool
    var onToggle: (() -> Void)?

    var body: some View {
        Button {
            onToggle?()
        } label: {
            HStack(spacing: 6) {
                if isTranslating {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: isEnabled ? "text.word.spacing" : "globe")
                        .font(.system(size: 12, weight: .medium))
                }

                Text(isEnabled ? "Single" : "Bilingual")
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                isEnabled
                    ? DesignSystem.Colors.accentSubtle
                    : DesignSystem.Colors.glassLight
            )
            .foregroundColor(
                isEnabled
                    ? DesignSystem.Colors.accent
                    : DesignSystem.Colors.textPrimary
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(isTranslating)
    }
}

/// Header bar for multi-language subtitle view with controls
struct MultiLanguageSubtitleHeader: View {
    @ObservedObject var viewModel: MultiLanguageSubtitleViewModel
    let sourceLanguage: TranslationLanguage?

    var body: some View {
        HStack(spacing: 12) {
            // Multi-language toggle
            MultiLanguageToggle(
                isEnabled: $viewModel.isEnabled,
                isTranslating: viewModel.isTranslating,
                onToggle: {
                    viewModel.toggleEnabled()
                }
            )

            if viewModel.isEnabled {
                // Target language picker
                HStack(spacing: 6) {
                    Text("to")
                        .font(.system(size: 11))
                        .foregroundColor(DesignSystem.Colors.textTertiary)

                    TranslationLanguagePicker(
                        selectedLanguage: $viewModel.targetLanguage,
                        sourceLanguage: sourceLanguage,
                        onChange: {
                            viewModel.onLanguageChanged()
                        }
                    )
                }

                // Translation progress
                if viewModel.isTranslating {
                    HStack(spacing: 6) {
                        ProgressView(value: viewModel.translationProgress)
                            .frame(width: 60)
                            .tint(DesignSystem.Colors.accent)

                        Text("\(Int(viewModel.translationProgress * 100))%")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                }

                // Error indicator
                if let error = viewModel.translationError {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.Colors.warning)

                        Text(error)
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.Colors.warning)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(DesignSystem.Colors.glassUltraLight)
    }
}

/// Complete multi-language subtitle container with header and content
/// Uses Apple's Translation framework for on-device translation
struct MultiLanguageSubtitleContainer: View {
    let result: TranscriptionResult
    let currentSegmentIndex: Int?
    let isPlaying: Bool
    let compactMode: Bool
    let onSegmentTap: (TranscriptionSegment) -> Void

    @StateObject private var viewModel = MultiLanguageSubtitleViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header with controls
            MultiLanguageSubtitleHeader(
                viewModel: viewModel,
                sourceLanguage: result.sourceTranslationLanguage
            )

            Divider()

            // Content
            if viewModel.isEnabled {
                // Side-by-side view
                MultiLanguageSubtitleView(
                    segments: result.segments,
                    translatedSegments: viewModel.translatedSegments.isEmpty ? result.segments : viewModel.translatedSegments,
                    sourceLanguage: result.sourceTranslationLanguage,
                    targetLanguage: viewModel.targetLanguage,
                    currentSegmentIndex: currentSegmentIndex,
                    isPlaying: isPlaying,
                    compactMode: compactMode,
                    onSegmentTap: onSegmentTap
                )
            } else {
                // Single column view (original)
                singleColumnView
            }
        }
        .onAppear {
            viewModel.setResult(result)
        }
        .onChange(of: result.id) { _, _ in
            viewModel.setResult(result)
        }
        // Apple Translation framework integration
        .translationTask(viewModel.translationConfig) { session in
            await viewModel.translateWithSession(session)
        }
    }

    @ViewBuilder
    private var singleColumnView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(Array(result.segments.enumerated()), id: \.element.uuid) { index, segment in
                        MultiLanguageSegmentRow(
                            segment: segment,
                            index: index,
                            isCurrentSegment: currentSegmentIndex == index,
                            isPlaying: isPlaying && currentSegmentIndex == index,
                            isTranslated: false,
                            compactMode: compactMode,
                            onTap: {
                                onSegmentTap(segment)
                            }
                        )
                        .id(index)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
            }
            .onChange(of: currentSegmentIndex) { _, newIndex in
                if let index = newIndex {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(index, anchor: .center)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Multi-Language Subtitles") {
    let sampleSegments = [
        TranscriptionSegment(id: 0, text: "Hello, welcome to this presentation.", startTime: 0.0, endTime: 3.5),
        TranscriptionSegment(id: 1, text: "Today we will discuss the new features.", startTime: 3.5, endTime: 7.2),
        TranscriptionSegment(id: 2, text: "Let me start with the first topic.", startTime: 7.2, endTime: 11.0),
        TranscriptionSegment(id: 3, text: "This is really exciting stuff.", startTime: 11.0, endTime: 14.5)
    ]

    let translatedSegments = [
        TranscriptionSegment(id: 0, text: "Hola, bienvenidos a esta presentacion.", startTime: 0.0, endTime: 3.5),
        TranscriptionSegment(id: 1, text: "Hoy discutiremos las nuevas funciones.", startTime: 3.5, endTime: 7.2),
        TranscriptionSegment(id: 2, text: "Permitanme empezar con el primer tema.", startTime: 7.2, endTime: 11.0),
        TranscriptionSegment(id: 3, text: "Esto es realmente emocionante.", startTime: 11.0, endTime: 14.5)
    ]

    return MultiLanguageSubtitleView(
        segments: sampleSegments,
        translatedSegments: translatedSegments,
        sourceLanguage: .english,
        targetLanguage: .spanish,
        currentSegmentIndex: 1,
        isPlaying: true,
        compactMode: false,
        onSegmentTap: { _ in }
    )
    .frame(width: 800, height: 400)
}
