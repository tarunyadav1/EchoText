import SwiftUI

/// General settings tab
struct GeneralSettingsTab: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section("Recording") {
                // Recording mode
                Picker("Recording Mode", selection: $appState.settings.recordingMode) {
                    ForEach(RecordingMode.allCases) { mode in
                        VStack(alignment: .leading) {
                            Text(mode.displayName)
                            Text(mode.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .tag(mode)
                    }
                }
                .pickerStyle(.inline)

                // Auto insert
                Toggle("Automatically insert transcribed text", isOn: $appState.settings.autoInsertText)

                // Feedback sounds
                Toggle("Play feedback sounds", isOn: $appState.settings.playFeedbackSounds)
            }

            Section("Voice Activity Detection") {
                // Silence threshold
                HStack {
                    Text("Silence threshold")
                    Spacer()
                    Text("\(appState.settings.vadSilenceThreshold, specifier: "%.1f")s")
                        .foregroundColor(.secondary)
                }
                Slider(
                    value: $appState.settings.vadSilenceThreshold,
                    in: 0.5...5.0,
                    step: 0.5
                )

                Text("How long to wait after you stop speaking before ending the recording")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("User Interface") {
                // Floating window
                Toggle("Show floating window when recording", isOn: $appState.settings.showFloatingWindow)

                // Window opacity
                if appState.settings.showFloatingWindow {
                    HStack {
                        Text("Window opacity")
                        Spacer()
                        Text("\(Int(appState.settings.floatingWindowOpacity * 100))%")
                            .foregroundColor(.secondary)
                    }
                    Slider(
                        value: $appState.settings.floatingWindowOpacity,
                        in: 0.5...1.0
                    )
                }

                // Menu bar icon
                Toggle("Show menu bar icon", isOn: $appState.settings.showMenuBarIcon)
            }

            Section("Startup") {
                Toggle("Launch at login", isOn: $appState.settings.launchAtLogin)
            }

            Section("Data & Storage") {
                // Storage used
                HStack {
                    Text("Models storage")
                    Spacer()
                    Text(appState.modelDownloadService.formattedStorageUsed)
                        .foregroundColor(.secondary)
                }

                // Open data folder
                Button("Show App Data in Finder") {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: appState.modelDownloadService.appDataDirectory.path)
                }

                // Reset app data
                Button("Delete All App Data", role: .destructive) {
                    showDeleteConfirmation = true
                }
                .foregroundColor(.red)
            }
        }
        .formStyle(.grouped)
        .padding()
        .alert("Delete All App Data?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                do {
                    try ModelDownloadService.deleteAllAppData()
                    // Reset onboarding
                    appState.settings.hasCompletedOnboarding = false
                    appState.showOnboarding = true
                } catch {
                    print("Failed to delete app data: \(error)")
                }
            }
        } message: {
            Text("This will delete all downloaded models, settings, and cached data. This action cannot be undone.")
        }
    }

    @State private var showDeleteConfirmation = false
}

// MARK: - Preview
#Preview {
    GeneralSettingsTab()
        .environmentObject(AppState())
}
