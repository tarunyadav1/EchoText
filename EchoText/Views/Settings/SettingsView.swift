import SwiftUI
import KeyboardShortcuts

/// Main settings window with tabbed interface
struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .environmentObject(appState)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            ModelSettingsTab()
                .environmentObject(appState)
                .tabItem {
                    Label("Models", systemImage: "cpu")
                }

            LanguageSettingsTab()
                .environmentObject(appState)
                .tabItem {
                    Label("Language", systemImage: "globe")
                }

            ShortcutsSettingsTab()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }

            PermissionsSettingsTab()
                .environmentObject(appState)
                .tabItem {
                    Label("Permissions", systemImage: "hand.raised")
                }
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - Shortcuts Settings Tab

struct ShortcutsSettingsTab: View {
    var body: some View {
        Form {
            Section {
                KeyboardShortcuts.Recorder("Toggle Recording:", name: .toggleRecording)

                KeyboardShortcuts.Recorder("Cancel Recording:", name: .cancelRecording)
            } header: {
                Text("Keyboard Shortcuts")
            } footer: {
                Text("These shortcuts work globally, even when Echo-text is in the background.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Permissions Settings Tab

struct PermissionsSettingsTab: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section("Required Permissions") {
                PermissionRow(
                    title: "Microphone",
                    description: "Required to record your voice",
                    status: appState.permissionService.microphoneStatus,
                    action: {
                        Task {
                            _ = await appState.permissionService.requestMicrophonePermission()
                        }
                    },
                    openSettings: {
                        appState.permissionService.openMicrophoneSettings()
                    }
                )
            }

            Section("Optional Permissions") {
                PermissionRow(
                    title: "Accessibility",
                    description: "Required for global hotkeys and text insertion",
                    status: appState.permissionService.accessibilityStatus,
                    action: {
                        appState.permissionService.requestAccessibilityPermission()
                    },
                    openSettings: {
                        appState.permissionService.openAccessibilitySettings()
                    }
                )
            }

            Section {
                Button("Check All Permissions") {
                    appState.permissionService.checkAllPermissions()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Permission Row

struct PermissionRow: View {
    let title: String
    let description: String
    let status: PermissionStatus
    let action: () -> Void
    let openSettings: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline)

                    Image(systemName: status.systemImageName)
                        .foregroundColor(statusColor)
                }

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if status == .denied {
                Button("Open Settings") {
                    openSettings()
                }
                .buttonStyle(.bordered)
            } else if status == .notDetermined {
                Button("Request") {
                    action()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
    }

    private var statusColor: Color {
        switch status {
        case .granted:
            return .green
        case .denied:
            return .red
        case .notDetermined:
            return .orange
        }
    }
}

// MARK: - Preview
#Preview {
    SettingsView()
        .environmentObject(AppState())
}
