import SwiftUI
import KeyboardShortcuts

/// Keyboard shortcut setup step in onboarding
struct ShortcutStep: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "keyboard.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
                .padding(.top, 20)

            VStack(spacing: 12) {
                Text("Set Your Shortcut")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Choose a keyboard shortcut to quickly start recording from anywhere on your Mac.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }

            // Shortcut recorder
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Toggle Recording")
                        .font(.headline)

                    KeyboardShortcuts.Recorder(for: .toggleRecording)
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)

                    Text("Press this shortcut to start recording, press again to stop and transcribe.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Cancel Recording")
                        .font(.headline)

                    KeyboardShortcuts.Recorder(for: .cancelRecording)
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)

                    Text("Press this shortcut to cancel recording without transcribing.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: 350)
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )

            // Tips
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)

                Text("Tip: Use a shortcut that won't conflict with other apps")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Preview
#Preview {
    ShortcutStep()
        .frame(width: 600, height: 500)
}
