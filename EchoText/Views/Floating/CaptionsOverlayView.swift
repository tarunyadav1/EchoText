import SwiftUI

/// The SwiftUI view for displaying realtime captions
struct CaptionsOverlayView: View {
    @EnvironmentObject var appState: AppState
    @State private var displayedText: String = ""
    @State private var animationOffset: CGFloat = 0
    @State private var opacity: Double = 0

    private var settings: CaptionsSettings {
        appState.settings.captionsSettings
    }

    var body: some View {
        VStack(spacing: 0) {
            if settings.position == .topCenter {
                Spacer()
            }

            captionsContent
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .frame(maxWidth: 800)
                .background(captionsBackground)
                .opacity(opacity)
                .offset(y: animationOffset)

            if settings.position == .bottomCenter || settings.position == .custom {
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                opacity = 1
                animationOffset = 0
            }
        }
        .onChange(of: appState.lastTranscription?.text) { _, newText in
            updateDisplayedText(newText ?? "")
        }
    }

    // MARK: - Caption Content

    private var captionsContent: some View {
        Text(displayedText.isEmpty ? "Listening..." : displayedText)
            .font(.system(size: settings.fontSize, weight: .medium, design: .rounded))
            .foregroundColor(settings.textColorOption.color)
            .multilineTextAlignment(.center)
            .lineLimit(settings.maxLines)
            .lineSpacing(6)
            .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
            .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
            .animation(settings.animateText ? .easeOut(duration: 0.15) : nil, value: displayedText)
    }

    // MARK: - Background

    private var captionsBackground: some View {
        ZStack {
            // Base glass effect
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .opacity(settings.backgroundOpacity)

            // Subtle gradient overlay for depth
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.3),
                            Color.black.opacity(0.5)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .opacity(settings.backgroundOpacity * 0.8)

            // Border for definition
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.2),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }

    // MARK: - Text Update Logic

    private func updateDisplayedText(_ newText: String) {
        guard !newText.isEmpty else {
            displayedText = ""
            return
        }

        // Get the last few sentences/lines based on maxLines setting
        let lines = getLastLines(from: newText, count: settings.maxLines)

        if settings.animateText {
            // Animate text change
            withAnimation(.easeOut(duration: 0.15)) {
                displayedText = lines
            }
        } else {
            displayedText = lines
        }
    }

    private func getLastLines(from text: String, count: Int) -> String {
        // Split by sentence endings or newlines
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if sentences.count <= count {
            return text
        }

        // Get last N sentences
        let lastSentences = Array(sentences.suffix(count))
        return lastSentences.joined(separator: ". ") + (text.hasSuffix(".") || text.hasSuffix("!") || text.hasSuffix("?") ? "" : "...")
    }
}

/// Compact captions view for the floating overlay window
struct CompactCaptionsView: View {
    @EnvironmentObject var appState: AppState
    @State private var displayedWords: [AnimatedWord] = []
    @State private var isDragging = false

    private var settings: CaptionsSettings {
        appState.settings.captionsSettings
    }

    /// Live transcription text from the current recording session
    private var liveText: String {
        // During recording, show real-time transcription if available
        // This would typically come from WhisperService's streaming output
        appState.lastTranscription?.text ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            // Recording indicator bar
            recordingIndicator
                .padding(.bottom, 8)

            // Caption text area
            captionTextArea
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(minWidth: 400, maxWidth: 700)
        .background(captionsBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
        .onChange(of: liveText) { _, newText in
            updateWords(from: newText)
        }
    }

    // MARK: - Recording Indicator

    private var recordingIndicator: some View {
        HStack(spacing: 8) {
            // Pulsing recording dot
            Circle()
                .fill(appState.isRecording ? DesignSystem.Colors.recordingActive : DesignSystem.Colors.textTertiary)
                .frame(width: 8, height: 8)
                .modifier(PulsingModifier(isActive: appState.isRecording))

            Text(appState.isRecording ? "Recording" : (appState.isProcessing ? "Processing..." : "Ready"))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Spacer()

            // Duration
            if appState.isRecording {
                Text(appState.formattedDuration)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }

            // Drag handle indicator
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 10))
                .foregroundColor(DesignSystem.Colors.textTertiary.opacity(0.5))
        }
    }

    // MARK: - Caption Text Area

    private var captionTextArea: some View {
        Group {
            if displayedWords.isEmpty {
                Text("Speak now...")
                    .font(.system(size: settings.fontSize, weight: .medium, design: .rounded))
                    .foregroundColor(settings.textColorOption.color.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                // Animated word-by-word display
                FlowingTextView(words: displayedWords, fontSize: settings.fontSize, textColor: settings.textColorOption.color)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minHeight: CGFloat(settings.maxLines) * (settings.fontSize + 8))
        .lineLimit(settings.maxLines)
    }

    // MARK: - Background

    private var captionsBackground: some View {
        ZStack {
            // Glass effect with Liquid Glass
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)

            // Dark overlay for readability
            Color.black.opacity(settings.backgroundOpacity * 0.6)

            // Subtle accent gradient at top
            LinearGradient(
                colors: [
                    DesignSystem.Colors.accent.opacity(0.1),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // MARK: - Word Animation Logic

    private func updateWords(from text: String) {
        let newWords = text.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }

        // Only add new words
        let existingCount = displayedWords.count
        let newWordsToAdd = Array(newWords.dropFirst(existingCount))

        for (index, word) in newWordsToAdd.enumerated() {
            let delay = Double(index) * 0.05 // Stagger animation
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    displayedWords.append(AnimatedWord(text: word))
                }
            }
        }

        // Trim old words if too many
        let maxWords = settings.maxLines * 15 // Approximate words per line
        if displayedWords.count > maxWords {
            displayedWords = Array(displayedWords.suffix(maxWords))
        }
    }
}

// MARK: - Supporting Types

struct AnimatedWord: Identifiable, Equatable {
    let id = UUID()
    let text: String
}

struct FlowingTextView: View {
    let words: [AnimatedWord]
    let fontSize: CGFloat
    let textColor: Color

    var body: some View {
        Text(words.map(\.text).joined(separator: " "))
            .font(.system(size: fontSize, weight: .medium, design: .rounded))
            .foregroundColor(textColor)
            .shadow(color: .black.opacity(0.8), radius: 1, x: 0, y: 1)
            .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 2)
            .lineSpacing(4)
    }
}

struct PulsingModifier: ViewModifier {
    let isActive: Bool
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .opacity(isPulsing ? 0.7 : 1.0)
            .animation(
                isActive ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default,
                value: isPulsing
            )
            .onAppear {
                if isActive { isPulsing = true }
            }
            .onChange(of: isActive) { _, active in
                isPulsing = active
            }
    }
}

// MARK: - Visual Effect Blur

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Preview

#Preview("Captions Overlay") {
    CaptionsOverlayView()
        .environmentObject(AppState())
        .frame(width: 600, height: 200)
        .background(Color.gray)
}

#Preview("Compact Captions") {
    CompactCaptionsView()
        .environmentObject(AppState())
        .frame(width: 500, height: 120)
        .background(Color.gray)
}
