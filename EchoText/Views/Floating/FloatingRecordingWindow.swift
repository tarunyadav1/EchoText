import SwiftUI

/// Floating window that appears during recording and processing (300x80px)
struct FloatingRecordingWindow: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 16) {
            // Left indicator - waveform or processing spinner
            if appState.isProcessing {
                // Processing spinner
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(width: 80, height: 50)
            } else {
                // Waveform visualization
                WaveformView(level: appState.audioLevel)
                    .frame(width: 80)
            }

            // Status info
            VStack(alignment: .leading, spacing: 4) {
                Text(statusText)
                    .font(.headline)
                    .foregroundColor(statusColor)

                Text(subtitleText)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Controls - only show during recording
            if appState.isRecording {
                RecordingControlsView(
                    onStop: {
                        appState.handleAction(.stop)
                    },
                    onCancel: {
                        appState.handleAction(.cancel)
                    }
                )
            }
        }
        .padding(16)
        .frame(width: 300, height: 80)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
    }

    private var statusText: String {
        switch appState.recordingState {
        case .recording:
            return "Recording..."
        case .processing:
            return "Processing..."
        case .idle:
            return "Ready"
        }
    }

    private var subtitleText: String {
        switch appState.recordingState {
        case .recording:
            return appState.formattedDuration
        case .processing:
            return "Transcribing audio"
        case .idle:
            return ""
        }
    }

    private var statusColor: Color {
        switch appState.recordingState {
        case .recording:
            return .primary
        case .processing:
            return .orange
        case .idle:
            return .secondary
        }
    }
}

// MARK: - Recording Controls View

struct RecordingControlsView: View {
    let onStop: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Stop button
            Button(action: onStop) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.red)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Stop recording and transcribe")

            // Cancel button
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Cancel recording")
        }
    }
}

// MARK: - Window Controller

class FloatingWindowController {
    private var window: NSWindow?

    func show(with view: some View) {
        if window == nil {
            createWindow()
        }

        window?.contentView = NSHostingView(rootView: view)
        window?.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
    }

    private func createWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 80),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.collectionBehavior = [.canJoinAllSpaces, .transient]
        window.isMovableByWindowBackground = true

        // Position in top-center of main screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - 150
            let y = screenFrame.maxY - 100
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        self.window = window
    }
}

// MARK: - Preview
#Preview {
    FloatingRecordingWindow()
        .environmentObject(AppState())
}
