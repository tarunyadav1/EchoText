import SwiftUI

/// Native Liquid Glass menu bar popover (macOS 26+)
/// Combines Liquid Glass with Murmur-inspired warmth
struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @State private var idlePulse = false

    var body: some View {
        GlassEffectContainer {
            VStack(spacing: 0) {
                // Header with status
                headerSection

                // Primary action - Recording button (prominent)
                recordingButtonSection

                Divider()
                    .padding(.horizontal, 12)

                // Recording options
                recordingOptionsSection

                Divider()
                    .padding(.horizontal, 12)

                // Recent transcription
                if let lastTranscription = appState.lastTranscription {
                    recentTranscriptionSection(lastTranscription)

                    Divider()
                        .padding(.horizontal, 12)
                }

                // Bottom actions
                bottomSection
            }
        }
        .frame(width: 320)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
        .preferredColorScheme(.dark)
        .onAppear { idlePulse = true }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(spacing: 14) {
            // Status indicator with glow effect
            ZStack {
                if appState.isRecording {
                    Circle()
                        .fill(DesignSystem.Colors.recordingPulse)
                        .frame(width: 52, height: 52)
                        .scaleEffect(1.3)
                        .animation(DesignSystem.Animations.pulse, value: appState.isRecording)
                }

                Image(systemName: appState.recordingState.systemImageName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(statusIconColor)
                    .frame(width: 44, height: 44)
                    .modifier(StatusGlassModifier(recordingState: appState.recordingState))
                    .breathing(isActive: idlePulse && appState.isIdle)
            }
            .softGlow(statusGlowColor, radius: 12, isActive: appState.isRecording || appState.isProcessing)

            VStack(alignment: .leading, spacing: 3) {
                Text("EchoText")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(.primary)

                HStack(spacing: 6) {
                    Circle()
                        .fill(statusDotColor)
                        .frame(width: 6, height: 6)

                    Text(appState.recordingState.displayText)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(statusTextColor)
                }
            }

            Spacer()

            if appState.isRecording {
                Text(appState.formattedDuration)
                    .font(DesignSystem.Typography.mono)
                    .foregroundColor(DesignSystem.Colors.recordingActive)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                            .stroke(DesignSystem.Colors.recordingActive.opacity(0.3), lineWidth: 1)
                    )
            }
        }
        .padding(16)
    }

    private var statusGlowColor: Color {
        switch appState.recordingState {
        case .idle: return DesignSystem.Colors.voicePrimary
        case .recording: return DesignSystem.Colors.recordingActive
        case .processing: return DesignSystem.Colors.processingActive
        }
    }

    private var statusDotColor: Color {
        switch appState.recordingState {
        case .idle: return DesignSystem.Colors.success
        case .recording: return DesignSystem.Colors.recordingActive
        case .processing: return DesignSystem.Colors.processingActive
        }
    }

    private var statusTextColor: Color {
        switch appState.recordingState {
        case .idle: return DesignSystem.Colors.success
        case .recording: return DesignSystem.Colors.recordingActive
        case .processing: return DesignSystem.Colors.processingActive
        }
    }

    private var statusBackgroundColor: Color {
        switch appState.recordingState {
        case .idle:
            return Color.clear
        case .recording:
            return DesignSystem.Colors.recordingActive.opacity(0.15)
        case .processing:
            return DesignSystem.Colors.processingActive.opacity(0.15)
        }
    }

    private var statusIconColor: Color {
        switch appState.recordingState {
        case .idle:
            return DesignSystem.Colors.textSecondary
        case .recording:
            return DesignSystem.Colors.recordingActive
        case .processing:
            return DesignSystem.Colors.processingActive
        }
    }

    // MARK: - Recording Button Section (Prominent)

    private var recordingButtonSection: some View {
        Button {
            appState.handleAction(.toggle)
        } label: {
            HStack(spacing: 14) {
                // Icon with glow effect
                ZStack {
                    if appState.isRecording {
                        Circle()
                            .fill(DesignSystem.Colors.recordingActive.opacity(0.2))
                            .frame(width: 48, height: 48)
                            .blur(radius: 6)
                    }

                    Image(systemName: appState.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(appState.isRecording ? DesignSystem.Colors.recordingActive : DesignSystem.Colors.voicePrimary)
                        )
                }
                .softGlow(
                    appState.isRecording ? DesignSystem.Colors.recordingActive : DesignSystem.Colors.voicePrimary,
                    radius: 10,
                    isActive: true
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.isRecording ? "Stop Recording" : "Start Recording")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(recordingModeHint)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                // Keyboard shortcut badge
                KeyboardHint(keys: appState.hotkeyService.toggleRecordingShortcutString)
            }
            .padding(12)
            .glassEffect(
                appState.isRecording
                    ? .regular.tint(DesignSystem.Colors.recordingActive).interactive()
                    : .regular.interactive(),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pressable(isPressed: false)
        .disabled(appState.isProcessing)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var recordingModeHint: String {
        switch appState.settings.recordingMode {
        case .pressToToggle: return "Press shortcut to toggle"
        case .holdToRecord: return "Hold shortcut while speaking"
        case .voiceActivity: return "Auto-stops when you pause"
        }
    }

    // MARK: - Recording Options Section

    private var recordingOptionsSection: some View {
        VStack(spacing: 8) {
            // Section label
            HStack {
                Text("OPTIONS")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                    .tracking(0.5)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Recording mode - segmented picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Recording Mode")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                Picker("", selection: $appState.settings.recordingMode) {
                    Text("Toggle").tag(RecordingMode.pressToToggle)
                    Text("Hold").tag(RecordingMode.holdToRecord)
                    Text("Auto").tag(RecordingMode.voiceActivity)
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, 16)

            // Language picker
            HStack(spacing: 12) {
                Image(systemName: "globe")
                    .font(.system(size: 13))
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                Text("Language")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                Spacer()

                Picker("", selection: $appState.settings.selectedLanguage) {
                    ForEach(SupportedLanguage.allLanguages.prefix(15)) { language in
                        Text(language.displayName).tag(language.code)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .tint(DesignSystem.Colors.textPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Recent Transcription Section

    private func recentTranscriptionSection(_ result: TranscriptionResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Last Transcription")
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(result.text, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Copy to clipboard")
            }

            Text(result.text)
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .lineLimit(3)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        }
        .padding(16)
    }

    // MARK: - Bottom Section

    private var bottomSection: some View {
        VStack(spacing: 2) {
            // Focus Mode
            menuButton(
                icon: "target",
                title: "Focus Mode",
                shortcut: appState.hotkeyService.focusModeShortcutString
            ) {
                appState.handleAction(.enterFocusMode)
            }

            // Open main window
            menuButton(
                icon: "macwindow",
                title: "Open EchoText",
                shortcut: nil
            ) {
                if let delegate = NSApplication.shared.delegate as? AppDelegate {
                    delegate.showMainWindow()
                }
            }

            // Settings
            menuButton(
                icon: "gearshape",
                title: "Settings...",
                shortcut: "\u{2318},"
            ) {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }

            Divider()
                .background(DesignSystem.Colors.border)
                .padding(.vertical, 4)

            // Quit
            menuButton(
                icon: "power",
                title: "Quit EchoText",
                shortcut: "\u{2318}Q"
            ) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
    }

    private func menuButton(icon: String, title: String, shortcut: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .frame(width: 20)

                Text(title)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Spacer()

                if let shortcut = shortcut {
                    Text(shortcut)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// Helper modifier for status glass effect with Murmur-inspired material styling
struct StatusGlassModifier: ViewModifier {
    let recordingState: RecordingState

    func body(content: Content) -> some View {
        switch recordingState {
        case .idle:
            content
                .background(.regularMaterial, in: Circle())
                .overlay(
                    Circle()
                        .stroke(DesignSystem.Colors.voicePrimary.opacity(0.2), lineWidth: 1)
                )
        case .recording:
            content
                .background(.regularMaterial, in: Circle())
                .overlay(
                    Circle()
                        .stroke(DesignSystem.Colors.recordingActive.opacity(0.4), lineWidth: 1)
                )
                .softGlow(DesignSystem.Colors.recordingActive, radius: 10, isActive: true)
        case .processing:
            content
                .background(.regularMaterial, in: Circle())
                .overlay(
                    Circle()
                        .stroke(DesignSystem.Colors.processingActive.opacity(0.3), lineWidth: 1)
                )
                .softGlow(DesignSystem.Colors.processingActive, radius: 8, isActive: true)
        }
    }
}

// MARK: - Preview
#Preview {
    MenuBarView()
        .environmentObject(AppState())
}
