import SwiftUI

/// Permissions setup step in onboarding
struct PermissionsStep: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "hand.raised.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .padding(.top, 20)

            VStack(spacing: 12) {
                Text("Permissions")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Echo-text needs a few permissions to work properly.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Permission cards
            VStack(spacing: 16) {
                PermissionCard(
                    icon: "mic.fill",
                    title: "Microphone",
                    description: "Required to record your voice",
                    isGranted: viewModel.microphonePermissionGranted,
                    isRequired: true,
                    action: {
                        Task {
                            await viewModel.requestMicrophonePermission()
                        }
                    }
                )

                PermissionCard(
                    icon: "keyboard",
                    title: "Accessibility",
                    description: "Required for global hotkeys and text insertion",
                    isGranted: viewModel.accessibilityPermissionGranted,
                    isRequired: false,
                    action: {
                        viewModel.requestAccessibilityPermission()
                    }
                )
            }
            .frame(maxWidth: 400)

            // Note about accessibility
            if !viewModel.accessibilityPermissionGranted {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("If you've granted accessibility, restart the app for changes to take effect.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }

            // Refresh button
            Button {
                viewModel.checkPermissions()
            } label: {
                Label("Refresh Status", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Permission Card

struct PermissionCard: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let isRequired: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(isGranted ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isGranted ? .green : .orange)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline)

                    if isRequired {
                        Text("Required")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.2))
                            .cornerRadius(4)
                    }
                }

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Status/Action
            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            } else {
                Button("Grant") {
                    action()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview
#Preview {
    PermissionsStep(viewModel: OnboardingViewModel(appState: AppState()))
        .frame(width: 600, height: 500)
}
