import SwiftUI
import KeyboardShortcuts

/// Keyboard shortcut setup step in onboarding
struct ShortcutStep: View {
    var body: some View {
        VStack(spacing: 28) {
            // Icon
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.accentSubtle)
                    .frame(width: 80, height: 80)

                Image(systemName: "keyboard.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(DesignSystem.Colors.accentGradient)
            }
            .padding(.top, 16)

            // Title and description
            VStack(spacing: 10) {
                Text("Set Your Shortcuts")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text("Choose keyboard shortcuts to quickly control recording from anywhere on your Mac.")
                    .font(.system(size: 15))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 380)
            }

            // Shortcut recorders
            VStack(spacing: 0) {
                // Toggle Recording
                OnboardingShortcutRow(
                    icon: "mic.fill",
                    iconColor: DesignSystem.Colors.accent,
                    title: "Toggle Recording",
                    description: "Press to start, press again to stop and transcribe",
                    shortcutName: .toggleRecording
                )

                Divider()
                    .padding(.vertical, 16)

                // Cancel Recording
                OnboardingShortcutRow(
                    icon: "xmark.circle.fill",
                    iconColor: DesignSystem.Colors.voicePrimary,
                    title: "Cancel Recording",
                    description: "Stop recording without transcribing",
                    shortcutName: .cancelRecording
                )
            }
            .padding(20)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
            .frame(maxWidth: 420)

            // Tips
            HStack(spacing: 10) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 14))
                    .foregroundColor(DesignSystem.Colors.voiceSecondary)

                Text("Use shortcuts that won't conflict with other apps")
                    .font(.system(size: 13))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(DesignSystem.Colors.voiceSecondary.opacity(0.1))
            .clipShape(Capsule())
            .padding(.bottom, 16)
        }
    }
}

/// Shortcut row specifically styled for onboarding
private struct OnboardingShortcutRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let shortcutName: KeyboardShortcuts.Name

    @State private var currentShortcut: KeyboardShortcuts.Shortcut?
    @State private var isRecording = false
    @State private var isHovered = false
    @State private var pulsePhase: CGFloat = 0

    init(
        icon: String,
        iconColor: Color,
        title: String,
        description: String,
        shortcutName: KeyboardShortcuts.Name
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.description = description
        self.shortcutName = shortcutName
        self._currentShortcut = State(initialValue: KeyboardShortcuts.getShortcut(for: shortcutName))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
                    .frame(width: 36, height: 36)
                    .background(iconColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                Spacer()
            }

            // Recorder button
            HStack(spacing: 10) {
                Button {
                    withAnimation(DesignSystem.Animations.quick) {
                        isRecording.toggle()
                    }
                } label: {
                    HStack(spacing: 10) {
                        if isRecording {
                            Circle()
                                .fill(DesignSystem.Colors.recordingActive)
                                .frame(width: 8, height: 8)
                                .scaleEffect(1 + pulsePhase * 0.4)
                                .onAppear {
                                    withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                                        pulsePhase = 1
                                    }
                                }

                            Text("Press your shortcut...")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.recordingActive)
                        } else if let shortcut = currentShortcut {
                            shortcutKeyView(shortcut)

                            Spacer()

                            Text("Click to change")
                                .font(.system(size: 11))
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                        } else {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(DesignSystem.Colors.accent)

                            Text("Click to set shortcut")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.accent)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(recorderBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(borderColor, lineWidth: isRecording ? 2 : 1)
                    )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(DesignSystem.Animations.quick) {
                        isHovered = hovering
                    }
                }

                // Clear button
                if currentShortcut != nil && !isRecording {
                    Button {
                        withAnimation(DesignSystem.Animations.quick) {
                            KeyboardShortcuts.reset(shortcutName)
                            currentShortcut = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear shortcut")
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .background {
                // Hidden native recorder
                KeyboardShortcuts.Recorder(for: shortcutName) { shortcut in
                    withAnimation(DesignSystem.Animations.quick) {
                        currentShortcut = shortcut
                        isRecording = false
                        pulsePhase = 0
                    }
                }
                .opacity(0)
                .allowsHitTesting(isRecording)
                .frame(width: 1, height: 1)
            }
        }
    }

    private func shortcutKeyView(_ shortcut: KeyboardShortcuts.Shortcut) -> some View {
        HStack(spacing: 4) {
            ForEach(shortcutParts(shortcut), id: \.self) { part in
                Text(part)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
        }
    }

    private func shortcutParts(_ shortcut: KeyboardShortcuts.Shortcut) -> [String] {
        var parts: [String] = []
        let desc = shortcut.description
        let components = desc.components(separatedBy: CharacterSet(charactersIn: "+"))
        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                parts.append(trimmed)
            }
        }
        return parts.isEmpty ? [desc] : parts
    }

    private var recorderBackground: Color {
        if isRecording {
            return DesignSystem.Colors.recordingGlass
        } else if isHovered {
            return DesignSystem.Colors.surfaceHover
        } else {
            return DesignSystem.Colors.surface
        }
    }

    private var borderColor: Color {
        if isRecording {
            return DesignSystem.Colors.recordingActive
        } else if isHovered {
            return DesignSystem.Colors.accent.opacity(0.4)
        } else if currentShortcut != nil {
            return DesignSystem.Colors.success.opacity(0.4)
        } else {
            return DesignSystem.Colors.border
        }
    }
}

// MARK: - Preview
#Preview {
    ShortcutStep()
        .frame(width: 600, height: 550)
        .background(Color(nsColor: .windowBackgroundColor))
}
