import SwiftUI

// MARK: - Recording Status Indicator

/// Displays the recording status with a pulsing dot
struct FocusModeStatusIndicator: View {
    let isRecording: Bool
    let isTranscribing: Bool
    let shortcutHint: String

    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 8) {
            // Status dot
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .scaleEffect(isPulsing && isRecording ? 1.3 : 1.0)
                .animation(
                    isRecording ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default,
                    value: isPulsing
                )

            Text(statusText)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.8))

            if isRecording {
                Text("  \(shortcutHint) to stop")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial.opacity(0.5), in: Capsule())
        .onAppear {
            isPulsing = true
        }
    }

    private var statusColor: Color {
        if isRecording {
            return DesignSystem.Colors.recordingActive
        } else if isTranscribing {
            return DesignSystem.Colors.processingActive
        } else {
            return DesignSystem.Colors.success
        }
    }

    private var statusText: String {
        if isRecording {
            return "Recording"
        } else if isTranscribing {
            return "Processing..."
        } else {
            return "Ready"
        }
    }
}

// MARK: - Blinking Cursor

/// A blinking cursor that appears at the end of text
struct BlinkingCursor: View {
    let color: Color

    @State private var isVisible = true

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 2, height: 24)
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    isVisible.toggle()
                }
            }
    }
}

// MARK: - Word Count Badge

/// Displays word count and duration
struct FocusModeStatsBadge: View {
    let wordCount: Int
    let duration: String
    let showWordCount: Bool
    let showDuration: Bool

    var body: some View {
        HStack(spacing: 12) {
            if showWordCount {
                HStack(spacing: 4) {
                    Image(systemName: "text.word.spacing")
                        .font(.system(size: 11))
                    Text("\(wordCount) word\(wordCount == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                }
            }

            if showWordCount && showDuration {
                Text("|")
                    .foregroundColor(.white.opacity(0.3))
            }

            if showDuration {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                    Text(duration)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                }
            }
        }
        .foregroundColor(.white.opacity(0.6))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial.opacity(0.3), in: Capsule())
    }
}

// MARK: - Hint Text

/// Shows escape hint at bottom left
struct FocusModeHint: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(.white.opacity(0.4))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
    }
}

// MARK: - Transcription Text View

/// Displays the transcribed text with custom styling
struct FocusModeTextView: View {
    let text: String
    let settings: FocusModeSettings
    let showCursor: Bool

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            // Use a flow layout approach with Text
            HStack(alignment: .bottom, spacing: 0) {
                Text(text.isEmpty ? placeholderText : text)
                    .font(settings.font.font(size: settings.fontSize, weight: .regular))
                    .foregroundColor(text.isEmpty ? settings.theme.secondaryTextColor : settings.theme.textColor)
                    .lineSpacing(settings.fontSize * (settings.lineHeight - 1))
                    .multilineTextAlignment(.center)

                if showCursor && !text.isEmpty {
                    BlinkingCursor(color: settings.theme.cursorColor)
                        .frame(height: settings.fontSize)
                }
            }
        }
        .frame(maxWidth: 800)
    }

    private var placeholderText: String {
        "Start speaking..."
    }
}

// MARK: - Control Button

/// A glass-style control button for the customization panel
struct FocusModeControlButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(isActive ? .white : .white.opacity(0.7))
            .frame(width: 60, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isActive ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Theme Picker Item

struct ThemePickerItem: View {
    let theme: FocusModeTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(theme.backgroundColor)
                    .frame(width: 32, height: 24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isSelected ? Color.white : Color.white.opacity(0.2), lineWidth: isSelected ? 2 : 1)
                    )

                Text(theme.displayName)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.6))
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Font Picker Item

struct FontPickerItem: View {
    let font: FocusModeFont
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Aa")
                .font(font.font(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                .frame(width: 36, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.white.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(font.displayName)
    }
}

// MARK: - Slider Control

struct FocusModeSlider: View {
    let label: String
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    let step: CGFloat
    let format: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text(String(format: format, value))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
            }

            Slider(value: $value, in: range, step: step)
                .tint(.white.opacity(0.4))
        }
        .frame(width: 100)
    }
}
