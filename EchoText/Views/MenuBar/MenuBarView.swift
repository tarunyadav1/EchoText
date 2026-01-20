import SwiftUI

/// Minimal Liquid Glass menu bar popover (macOS 26+)
struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Simple header
            headerSection

            Divider()
                .background(Color.primary.opacity(0.08))
                .padding(.horizontal, 12)

            // Record button
            recordingButtonSection

            Divider()
                .background(Color.primary.opacity(0.08))
                .padding(.horizontal, 12)

            // Menu items
            menuSection
        }
        .frame(width: 260)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text("EchoText")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)

            Text("•")
                .foregroundColor(.secondary.opacity(0.6))

            Text(appState.recordingState.displayText)
                .font(.system(size: 13))
                .foregroundColor(statusColor)

            Spacer()

            if appState.isRecording {
                Text(appState.formattedDuration)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(DesignSystem.Colors.recordingActive)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var statusColor: Color {
        switch appState.recordingState {
        case .idle: return DesignSystem.Colors.success
        case .recording: return DesignSystem.Colors.recordingActive
        case .processing: return DesignSystem.Colors.processingActive
        }
    }

    // MARK: - Recording Button

    private var recordingButtonSection: some View {
        Button {
            appState.handleAction(.toggle)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: appState.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(appState.isRecording ? DesignSystem.Colors.recordingActive : DesignSystem.Colors.voicePrimary)
                    )

                Text(appState.isRecording ? "Stop Recording" : "Start Recording")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)

                Spacer()

                KeyboardHint(keys: appState.hotkeyService.toggleRecordingShortcutString)
            }
            .padding(8)
            .glassEffect(
                appState.isRecording
                    ? .regular.tint(DesignSystem.Colors.recordingActive.opacity(0.2)).interactive()
                    : .regular.interactive(),
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .buttonStyle(.plain)
        .disabled(appState.isProcessing)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    // MARK: - Menu Section

    private var menuSection: some View {
        VStack(spacing: 2) {
            menuButton(icon: "power", title: "Quit EchoText", shortcut: "⌘Q") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
    }

    private func menuButton(icon: String, title: String, shortcut: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 16)

                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)

                Spacer()

                Text(shortcut)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Preview
#Preview {
    MenuBarView()
        .environmentObject(AppState())
}
