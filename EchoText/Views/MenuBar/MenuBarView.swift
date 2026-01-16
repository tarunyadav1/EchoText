import SwiftUI

/// Menu bar popover view
struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Header with status
            headerSection

            Divider()

            // Quick controls
            controlsSection

            Divider()

            // Recent transcription
            if let lastTranscription = appState.lastTranscription {
                recentTranscriptionSection(lastTranscription)
                Divider()
            }

            // Bottom actions
            bottomSection
        }
        .frame(width: 280)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(spacing: 12) {
            // Status indicator
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: appState.recordingState.systemImageName)
                    .font(.system(size: 18))
                    .foregroundColor(statusColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Echo-text")
                    .font(.headline)

                Text(appState.recordingState.displayText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if appState.isRecording {
                Text(appState.formattedDuration)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
    }

    private var statusColor: Color {
        switch appState.recordingState {
        case .idle:
            return .secondary
        case .recording:
            return .red
        case .processing:
            return .orange
        }
    }

    // MARK: - Controls Section

    private var controlsSection: some View {
        VStack(spacing: 8) {
            // Record button
            Button {
                appState.handleAction(.toggle)
            } label: {
                HStack {
                    Image(systemName: appState.isRecording ? "stop.fill" : "mic.fill")
                    Text(appState.isRecording ? "Stop Recording" : "Start Recording")
                    Spacer()
                    Text(appState.hotkeyService.toggleRecordingShortcutString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .disabled(appState.isProcessing)

            // Recording mode
            Picker("Mode", selection: $appState.settings.recordingMode) {
                ForEach(RecordingMode.allCases) { mode in
                    Label(mode.displayName, systemImage: mode.iconName)
                        .tag(mode)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()

            // Language
            Picker("Language", selection: $appState.settings.selectedLanguage) {
                ForEach(SupportedLanguage.allLanguages.prefix(15)) { language in
                    Text(language.displayName).tag(language.code)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
        .padding(12)
    }

    // MARK: - Recent Transcription Section

    private func recentTranscriptionSection(_ result: TranscriptionResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Last Transcription")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(result.text, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Copy to clipboard")
            }

            Text(result.text)
                .font(.caption)
                .lineLimit(3)
                .foregroundColor(.primary)
        }
        .padding(12)
    }

    // MARK: - Bottom Section

    private var bottomSection: some View {
        VStack(spacing: 8) {
            // Open main window
            Button {
                NSApp.activate(ignoringOtherApps: true)
                for window in NSApp.windows {
                    if window.canBecomeMain {
                        window.makeKeyAndOrderFront(nil)
                        break
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "macwindow")
                    Text("Open Echo-text")
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            // Settings
            Button {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            } label: {
                HStack {
                    Image(systemName: "gearshape")
                    Text("Settings...")
                    Spacer()
                    Text("⌘,")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            Divider()

            // Quit
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Image(systemName: "power")
                    Text("Quit Echo-text")
                    Spacer()
                    Text("⌘Q")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(12)
    }
}

// MARK: - Preview
#Preview {
    MenuBarView()
        .environmentObject(AppState())
}
