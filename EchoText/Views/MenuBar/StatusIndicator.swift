import SwiftUI

/// Menu bar status indicator icon using custom AI Mic icon
struct StatusIndicator: View {
    let state: RecordingState

    var body: some View {
        Image("MenuBarIcon")
            .renderingMode(.template)
            .foregroundStyle(primaryColor)
    }

    private var primaryColor: Color {
        switch state {
        case .idle:
            return .primary
        case .recording:
            return Color(hex: "F9564F") // Tart Orange
        case .processing:
            return Color(hex: "F3C677") // Gold Crayola
        }
    }
}

/// Animated version for menu bar that pulses when recording
struct AnimatedStatusIndicator: View {
    let state: RecordingState
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            StatusIndicator(state: state)

            // Pulsing dot for recording state
            if state == .recording {
                Circle()
                    .fill(Color(hex: "F9564F"))
                    .frame(width: 4, height: 4)
                    .offset(x: 8, y: -8)
                    .scaleEffect(isAnimating ? 1.3 : 1.0)
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
    VStack(spacing: 30) {
        Text("AI Mic Menu Bar Icon")
            .font(.headline)

        HStack(spacing: 30) {
            VStack {
                StatusIndicator(state: .idle)
                Text("Idle").font(.caption)
            }
            VStack {
                StatusIndicator(state: .recording)
                Text("Recording").font(.caption)
            }
            VStack {
                StatusIndicator(state: .processing)
                Text("Processing").font(.caption)
            }
        }
    }
    .padding(40)
}
