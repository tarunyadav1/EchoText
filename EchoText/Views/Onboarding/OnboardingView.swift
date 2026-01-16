import SwiftUI

/// Main onboarding flow view
struct OnboardingView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(OnboardingStep.allCases, id: \.self) { step in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(step.rawValue <= viewModel.currentStep.rawValue ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 8)

            // Content - scrollable
            ScrollView {
                stepContent(for: viewModel.currentStep)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
            }
            .frame(maxHeight: .infinity)

            Divider()

            // Navigation buttons
            navigationButtons
        }
        .frame(minWidth: 500, minHeight: 500)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Step Content

    @ViewBuilder
    private func stepContent(for step: OnboardingStep) -> some View {
        switch step {
        case .welcome:
            WelcomeStep()
        case .permissions:
            PermissionsStep(viewModel: viewModel)
        case .modelDownload:
            ModelDownloadStep(viewModel: viewModel)
        case .shortcut:
            ShortcutStep()
        case .complete:
            CompleteStep()
        }
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack {
            // Back button
            if !viewModel.isFirstStep {
                Button("Back") {
                    viewModel.previousStep()
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Skip button (on some steps)
            if viewModel.currentStep == .modelDownload && viewModel.isModelDownloaded {
                Button("Skip") {
                    viewModel.nextStep()
                }
                .buttonStyle(.plain)
            }

            // Next/Done button
            Button(viewModel.isLastStep ? "Get Started" : "Continue") {
                if viewModel.isLastStep {
                    viewModel.completeOnboarding()
                } else {
                    viewModel.nextStep()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canProceed && !viewModel.isLastStep)
        }
        .padding()
    }
}

// MARK: - Welcome Step

struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.linearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .padding(.top, 20)

            VStack(spacing: 12) {
                Text("Welcome to Echo-text")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Fast, accurate voice-to-text transcription that runs entirely on your Mac. No internet required.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }

            // Feature highlights
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(
                    icon: "lock.shield.fill",
                    title: "100% Local",
                    description: "Your voice never leaves your Mac"
                )

                FeatureRow(
                    icon: "bolt.fill",
                    title: "Lightning Fast",
                    description: "Optimized for Apple Silicon"
                )

                FeatureRow(
                    icon: "globe",
                    title: "100+ Languages",
                    description: "Transcribe in any language"
                )
            }
            .padding(.top, 20)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Complete Step

struct CompleteStep: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
                .padding(.top, 20)

            VStack(spacing: 12) {
                Text("You're All Set!")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Echo-text is ready to use. Press your keyboard shortcut to start dictating from anywhere.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }

            // Quick tips
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick Tips:")
                    .font(.headline)

                TipRow(text: "Press ⇧⌘R to start/stop recording")
                TipRow(text: "Look for the mic icon in your menu bar")
                TipRow(text: "Your text is automatically inserted where you're typing")
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Tip Row

struct TipRow: View {
    let text: String

    var body: some View {
        HStack {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.yellow)
            Text(text)
                .font(.caption)
        }
    }
}

// MARK: - Preview
#Preview {
    OnboardingView(viewModel: OnboardingViewModel(appState: AppState()))
        .frame(width: 600, height: 500)
}
