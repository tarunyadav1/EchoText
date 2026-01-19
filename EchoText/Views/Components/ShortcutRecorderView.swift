import SwiftUI
import KeyboardShortcuts

/// Custom shortcut recorder with improved UX
/// - Clear visual states for idle, recording, and set states
/// - Pulsing animation when recording
/// - Clear button to remove shortcut
/// - Proper visual feedback matching Liquid Glass design
struct ShortcutRecorderView: View {
    let shortcutName: KeyboardShortcuts.Name
    let title: String
    let description: String

    @State private var isRecording = false
    @State private var currentShortcut: KeyboardShortcuts.Shortcut?

    init(for shortcutName: KeyboardShortcuts.Name, title: String = "", description: String = "") {
        self.shortcutName = shortcutName
        self.title = title
        self.description = description
        self._currentShortcut = State(initialValue: KeyboardShortcuts.getShortcut(for: shortcutName))
    }

    var body: some View {
        HStack(spacing: 16) {
            // Left side - title and description
            if !title.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    if !description.isEmpty {
                        Text(description)
                            .font(.system(size: 13))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }

                Spacer()
            }

            // Shortcut recorder button
            ShortcutRecorderButton(
                shortcutName: shortcutName,
                isRecording: $isRecording,
                currentShortcut: $currentShortcut
            )
        }
        .padding(.vertical, 2)
    }
}

/// The actual recorder button component
struct ShortcutRecorderButton: View {
    let shortcutName: KeyboardShortcuts.Name
    @Binding var isRecording: Bool
    @Binding var currentShortcut: KeyboardShortcuts.Shortcut?

    @State private var isHovered = false
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 0) {
            // Main recorder area
            Button {
                isRecording.toggle()
            } label: {
                HStack(spacing: 10) {
                    // Recording indicator
                    if isRecording {
                        Circle()
                            .fill(DesignSystem.Colors.recordingActive)
                            .frame(width: 8, height: 8)
                            .scaleEffect(pulseScale)
                            .animation(
                                .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                                value: pulseScale
                            )
                            .onAppear {
                                pulseScale = 1.3
                            }
                            .onDisappear {
                                pulseScale = 1.0
                            }
                    }

                    // Shortcut display or placeholder
                    Group {
                        if isRecording {
                            Text("Press shortcut...")
                                .foregroundColor(DesignSystem.Colors.recordingActive)
                        } else if let shortcut = currentShortcut {
                            Text(shortcut.description)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                        } else {
                            Text("Click to record")
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                        }
                    }
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(minWidth: 140)
                .background(recorderBackground)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                        .stroke(borderColor, lineWidth: isRecording ? 2 : 1)
                )
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(DesignSystem.Animations.quick) {
                    isHovered = hovering
                }
            }

            // Clear button (only show when there's a shortcut and not recording)
            if currentShortcut != nil && !isRecording {
                Button {
                    clearShortcut()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
                .help("Clear shortcut")
            }
        }
        .background {
            // Hidden native recorder for actual functionality
            KeyboardShortcuts.Recorder(for: shortcutName) { shortcut in
                currentShortcut = shortcut
                isRecording = false
            }
            .opacity(0)
            .allowsHitTesting(false)
        }
        .onChange(of: isRecording) { _, recording in
            if recording {
                // Focus the hidden recorder when our custom button is clicked
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    // The hidden recorder should capture the next key press
                    NSApp.keyWindow?.makeFirstResponder(nil)
                }
            }
        }
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
            return DesignSystem.Colors.borderHover
        } else {
            return DesignSystem.Colors.border
        }
    }

    private func clearShortcut() {
        KeyboardShortcuts.reset(shortcutName)
        currentShortcut = nil
    }
}

/// Compact shortcut recorder for inline use (like in cards)
struct CompactShortcutRecorder: View {
    let shortcutName: KeyboardShortcuts.Name

    @State private var currentShortcut: KeyboardShortcuts.Shortcut?
    @State private var isRecording = false
    @State private var isHovered = false

    init(for shortcutName: KeyboardShortcuts.Name) {
        self.shortcutName = shortcutName
        self._currentShortcut = State(initialValue: KeyboardShortcuts.getShortcut(for: shortcutName))
    }

    var body: some View {
        KeyboardShortcuts.Recorder(for: shortcutName) { shortcut in
            currentShortcut = shortcut
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                .fill(isHovered ? DesignSystem.Colors.surfaceHover : DesignSystem.Colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(DesignSystem.Animations.quick) {
                isHovered = hovering
            }
        }
    }
}

/// Styled shortcut row for settings sections
struct ShortcutSettingsRow: View {
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
        icon: String = "keyboard",
        iconColor: Color = DesignSystem.Colors.accent,
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
        HStack(spacing: 14) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(iconColor)
                .frame(width: 32, height: 32)
                .background(iconColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // Title and description
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            Spacer()

            // Recorder
            shortcutRecorder
        }
        .padding(.vertical, 4)
    }

    private var shortcutRecorder: some View {
        HStack(spacing: 8) {
            // Main button
            Button {
                withAnimation(DesignSystem.Animations.quick) {
                    isRecording.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    if isRecording {
                        Circle()
                            .fill(DesignSystem.Colors.recordingActive)
                            .frame(width: 6, height: 6)
                            .scaleEffect(1.0 + pulsePhase * 0.4)
                            .opacity(1.0 - pulsePhase * 0.3)
                            .onAppear {
                                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                                    pulsePhase = 1
                                }
                            }

                        Text("Type shortcut...")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.recordingActive)
                    } else if let shortcut = currentShortcut {
                        shortcutKeyView(shortcut)
                    } else {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 12))
                            .foregroundColor(DesignSystem.Colors.textTertiary)

                        Text("Set shortcut")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(recorderBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: isRecording ? 1.5 : 1)
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
                        .font(.system(size: 14))
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

    private func shortcutKeyView(_ shortcut: KeyboardShortcuts.Shortcut) -> some View {
        HStack(spacing: 4) {
            ForEach(shortcutParts(shortcut), id: \.self) { part in
                Text(part)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
    }

    private func shortcutParts(_ shortcut: KeyboardShortcuts.Shortcut) -> [String] {
        var parts: [String] = []
        let desc = shortcut.description

        // Split by common separators
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
            return DesignSystem.Colors.recordingActive.opacity(0.6)
        } else if isHovered {
            return DesignSystem.Colors.borderHover
        } else {
            return DesignSystem.Colors.border
        }
    }
}

// MARK: - Preview

#Preview("Shortcut Recorder") {
    VStack(spacing: 24) {
        // Full row style
        ShortcutSettingsRow(
            icon: "mic.fill",
            iconColor: DesignSystem.Colors.accent,
            title: "Toggle Recording",
            description: "Start or stop voice recording",
            shortcutName: .toggleRecording
        )

        Divider()

        ShortcutSettingsRow(
            icon: "xmark.circle",
            iconColor: DesignSystem.Colors.error,
            title: "Cancel Recording",
            description: "Cancel without transcribing",
            shortcutName: .cancelRecording
        )
    }
    .padding(24)
    .frame(width: 500)
}
