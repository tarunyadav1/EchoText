import SwiftUI

@main
struct EchoTextApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    init() {
        // Note: appDelegate and appState are not yet initialized here
    }

    var body: some Scene {
        // Main Window - hidden by default, only shown when user opens from menu bar
        WindowGroup {
            MainWindow()
                .environmentObject(appState)
                .onAppear {
                    // Connect appState to appDelegate for floating window
                    appDelegate.appState = appState

                    // Hide the main window after connecting appState
                    // The app runs in menu bar mode - window only shown when requested
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if !appState.showOnboarding {
                            // Hide all main windows, keep app as accessory
                            for window in NSApp.windows {
                                if window.canBecomeMain && window.isVisible {
                                    window.orderOut(nil)
                                }
                            }
                            NSApp.setActivationPolicy(.accessory)
                        }
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 800, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) {}

            CommandMenu("Recording") {
                Button(appState.recordingState == .recording ? "Stop Recording" : "Start Recording") {
                    appState.handleAction(.toggle)
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Button("Cancel Recording") {
                    appState.handleAction(.cancel)
                }
                .disabled(appState.recordingState == .idle)

                Divider()

                Picker("Recording Mode", selection: $appState.settings.recordingMode) {
                    ForEach(RecordingMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
            }

            CommandMenu("Model") {
                Picker("Language", selection: $appState.settings.selectedLanguage) {
                    ForEach(SupportedLanguage.allLanguages.prefix(20)) { language in
                        Text(language.displayName).tag(language.code)
                    }
                }
            }
        }

        // Menu Bar Extra
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            StatusIndicator(state: appState.recordingState)
        }
        .menuBarExtraStyle(.window)

        // Settings Window
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
