import SwiftUI

/// Clean floating recording indicator - no borders
struct FloatingRecordingWindow: View {
    @EnvironmentObject var appState: AppState
    @State private var wavePhase: CGFloat = 0

    var body: some View {
        HStack(spacing: 12) {
            // Waveform indicator
            waveformIndicator

            // Status text
            VStack(alignment: .leading, spacing: 1) {
                Text(statusText)
                    .font(DesignSystem.Typography.headlineMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text(subtitleText)
                    .font(DesignSystem.Typography.monoSmall)
                    .foregroundColor(appState.isRecording ? DesignSystem.Colors.error : DesignSystem.Colors.textSecondary)
            }

            Spacer()

            // Controls
            if appState.isRecording {
                controlButtons
            } else if appState.isProcessing {
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(DesignSystem.Colors.warning)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(width: 300, height: 60)
        .liquidGlassPill()
        .onAppear {
            withAnimation(Animation.linear(duration: 2).repeatForever(autoreverses: false)) {
                wavePhase = .pi * 2
            }
        }
    }

    // MARK: - Visual Effect Blur (proper macOS glass)

    struct VisualEffectBlur: NSViewRepresentable {
        func makeNSView(context: Context) -> NSVisualEffectView {
            let view = NSVisualEffectView()
            view.material = .hudWindow
            view.blendingMode = .behindWindow
            view.state = .active
            view.wantsLayer = true
            return view
        }

        func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
    }

    // MARK: - Waveform Indicator

    private var waveformIndicator: some View {
        ZStack {
            if appState.isRecording {
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "F9564F"), Color(hex: "F3C677")],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(width: 3, height: barHeight(for: i))
                            .animation(.easeInOut(duration: 0.12), value: appState.audioLevel)
                    }
                }
            } else if appState.isProcessing {
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "F9564F"), Color(hex: "F3C677")],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
                    .frame(width: 20, height: 20)
                    .rotationEffect(Angle(radians: Double(wavePhase)))
            } else {
                Image(systemName: "mic.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "F9564F"))
            }
        }
        .frame(width: 36, height: 36)
        .background(Color.primary.opacity(0.06), in: Circle())
    }

    private func barHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 6
        let maxHeight: CGFloat = 22
        let level = CGFloat(appState.audioLevel)
        let offset = CGFloat(index) * 0.2
        let height = baseHeight + (maxHeight - baseHeight) * level * (0.5 + sin(wavePhase + offset) * 0.5)
        return max(baseHeight, min(maxHeight, height))
    }

    // MARK: - Control Buttons

    private var controlButtons: some View {
        HStack(spacing: 8) {
            Button {
                appState.handleAction(.stop)
            } label: {
                Image(systemName: "stop.fill")
            }
            .buttonStyle(WisprIconButtonStyle(size: 32, isActive: true))

            Button {
                appState.handleAction(.cancel)
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(WisprIconButtonStyle(size: 28, isActive: false))
        }
    }

    // MARK: - Text

    private var statusText: String {
        switch appState.recordingState {
        case .recording: return "Recording"
        case .processing: return "Processing"
        case .idle: return "Ready"
        }
    }

    private var subtitleText: String {
        switch appState.recordingState {
        case .recording: return appState.formattedDuration
        case .processing: return "Transcribing..."
        case .idle: return ""
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
        window?.contentView = NSHostingView(rootView: 
            view
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clear)
        )
        window?.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
    }

    private func createWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 120),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        window.isMovableByWindowBackground = true

        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - 200
            let y = screenFrame.minY + 60
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        self.window = window
    }
}

#Preview {
    FloatingRecordingWindow()
        .environmentObject(AppState())
}
