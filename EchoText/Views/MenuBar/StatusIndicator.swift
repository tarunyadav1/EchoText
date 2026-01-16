import SwiftUI

/// Menu bar status indicator icon
struct StatusIndicator: View {
    let state: RecordingState

    var body: some View {
        Image(systemName: iconName)
            .symbolRenderingMode(.palette)
            .foregroundStyle(primaryColor, secondaryColor)
    }

    private var iconName: String {
        switch state {
        case .idle:
            return "mic"
        case .recording:
            return "mic.fill"
        case .processing:
            return "waveform"
        }
    }

    private var primaryColor: Color {
        switch state {
        case .idle:
            return .primary
        case .recording:
            return .red
        case .processing:
            return .orange
        }
    }

    private var secondaryColor: Color {
        switch state {
        case .idle:
            return .secondary
        case .recording:
            return .red.opacity(0.5)
        case .processing:
            return .orange.opacity(0.5)
        }
    }
}

/// Animated version for menu bar that pulses when recording
struct AnimatedStatusIndicator: View {
    let state: RecordingState
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Base icon
            StatusIndicator(state: state)

            // Pulsing overlay for recording
            if state == .recording {
                Circle()
                    .fill(Color.red)
                    .frame(width: 6, height: 6)
                    .offset(x: 6, y: -6)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .opacity(isAnimating ? 1.0 : 0.6)
            }
        }
        .onChange(of: state) { newState in
            if newState == .recording {
                withAnimation(.easeInOut(duration: 0.5).repeatForever()) {
                    isAnimating = true
                }
            } else {
                isAnimating = false
            }
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            StatusIndicator(state: .idle)
            StatusIndicator(state: .recording)
            StatusIndicator(state: .processing)
        }
        .font(.title)

        HStack(spacing: 20) {
            AnimatedStatusIndicator(state: .idle)
            AnimatedStatusIndicator(state: .recording)
            AnimatedStatusIndicator(state: .processing)
        }
        .font(.title)
    }
    .padding()
}
