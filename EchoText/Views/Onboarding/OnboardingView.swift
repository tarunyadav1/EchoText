import SwiftUI

/// Native Liquid Glass onboarding flow view (macOS 26+)
struct OnboardingView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        ZStack {
            // Liquid Glass background
            Color.clear
                .glassEffect(.clear, in: .rect)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress indicator with Liquid Glass pills
                GlassEffectContainer {
                    HStack(spacing: 6) {
                        ForEach(OnboardingStep.allCases, id: \.self) { step in
                            Capsule()
                                .fill(step.rawValue <= viewModel.currentStep.rawValue ? Color.accentColor : Color.secondary.opacity(0.2))
                                .frame(height: 6)
                                .animation(.spring(), value: viewModel.currentStep)
                        }
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 24)
                .padding(.bottom, 12)

                // Content - scrollable
                ScrollView {
                    stepContent(for: viewModel.currentStep)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 32)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
                .frame(maxHeight: .infinity)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.currentStep)

                // Navigation buttons with Liquid Glass
                navigationButtons
                    .padding(24)
                    .glassEffect(.regular, in: .rect)
            }
        }
        .frame(minWidth: 600, minHeight: 600)
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
            if !viewModel.isFirstStep {
                Button {
                    viewModel.previousStep()
                } label: {
                    Text("Back")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if viewModel.currentStep == .modelDownload && viewModel.isModelDownloaded {
                Button("Skip") {
                    viewModel.nextStep()
                }
                .buttonStyle(GlassButtonStyle())
            }

            Button {
                if viewModel.isLastStep {
                    viewModel.completeOnboarding()
                } else {
                    viewModel.nextStep()
                }
            } label: {
                Text(viewModel.isLastStep ? "Get Started" : "Continue")
                    .font(.system(size: 14, weight: .bold))
            }
            .buttonStyle(PrimaryGradientButtonStyle())
            .disabled(!viewModel.canProceed && !viewModel.isLastStep)
        }
    }
}

// MARK: - Welcome Step

struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 32) {
            // Hero icon with Liquid Glass
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.linearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .symbolEffect(.bounce, options: .repeating)
                .frame(width: 140, height: 140)
                .glassEffect(.regular.tint(.blue.opacity(0.15)), in: .circle)

            VStack(spacing: 12) {
                Text("Welcome to EchoText")
                    .font(.system(size: 32, weight: .bold, design: .rounded))

                Text("Lightning-fast, accurate transcription that lives on your Mac. Experience the future of dictation.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }

            // Feature list with Liquid Glass card
            VStack(alignment: .leading, spacing: 20) {
                FeatureRow(
                    icon: "lock.shield.fill",
                    title: "Privacy First",
                    description: "Your voice never leaves your device."
                )

                FeatureRow(
                    icon: "bolt.fill",
                    title: "Lightning Fast",
                    description: "Powered by optimized AI for Apple Silicon."
                )

                FeatureRow(
                    icon: "globe",
                    title: "Global Reach",
                    description: "Support for 100+ languages and dialects."
                )
            }
            .padding(24)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
        }
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            // Icon with Liquid Glass
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.accentColor)
                .frame(width: 40, height: 40)
                .glassEffect(.regular.tint(.accentColor.opacity(0.2)), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))

                Text(description)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Complete Step

struct CompleteStep: View {
    var body: some View {
        VStack(spacing: 32) {
            // Success icon with Liquid Glass
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
                .symbolEffect(.bounce, options: .repeating)
                .frame(width: 140, height: 140)
                .glassEffect(.regular.tint(.green.opacity(0.15)), in: .circle)

            VStack(spacing: 12) {
                Text("You're All Set!")
                    .font(.system(size: 32, weight: .bold, design: .rounded))

                Text("EchoText is ready to go. Dictate from anywhere with a single shortcut.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }

            // Tips with Liquid Glass card
            VStack(alignment: .leading, spacing: 16) {
                Text("Quick Tips")
                    .font(.system(size: 18, weight: .bold, design: .rounded))

                TipRow(icon: "command", text: "Press ⇧⌘R to start/stop anytime")
                TipRow(icon: "menubar.arrow.up.rectangle", text: "Control from the Menu Bar icon")
                TipRow(icon: "text.cursor", text: "Text is auto-inserted at your cursor")
            }
            .padding(24)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
        }
    }
}

struct TipRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.accentColor)
                .frame(width: 20)
            
            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.primary.opacity(0.8))
        }
    }
}

// MARK: - Preview
#Preview {
    OnboardingView(viewModel: OnboardingViewModel(appState: AppState()))
        .frame(width: 600, height: 500)
}
