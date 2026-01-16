import SwiftUI

/// Main application window with tabbed interface
struct MainWindow: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: MainTab = .dictation

    enum MainTab: String, CaseIterable {
        case dictation = "Dictation"
        case files = "File Transcription"

        var iconName: String {
            switch self {
            case .dictation: return "mic.fill"
            case .files: return "doc.fill"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(MainTab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.iconName)
                    .tag(tab)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 250)
        } detail: {
            // Content
            Group {
                switch selectedTab {
                case .dictation:
                    DictationTab(viewModel: DictationViewModel(appState: appState))
                case .files:
                    FileTranscriptionTab(viewModel: FileTranscriptionViewModel(appState: appState))
                }
            }
            .frame(minWidth: 500, minHeight: 400)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // Recording status indicator
                HStack(spacing: 8) {
                    if appState.isRecording {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut(duration: 0.5).repeatForever(), value: appState.isRecording)

                        Text(appState.formattedDuration)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }

                // Quick record button
                Button {
                    appState.handleAction(.toggle)
                } label: {
                    Label(
                        appState.isRecording ? "Stop" : "Record",
                        systemImage: appState.isRecording ? "stop.fill" : "mic.fill"
                    )
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(appState.isProcessing)

                // Settings
                Button {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
        .sheet(isPresented: $appState.showOnboarding) {
            OnboardingView(viewModel: OnboardingViewModel(appState: appState))
                .frame(minWidth: 550, idealWidth: 600, maxWidth: 700,
                       minHeight: 550, idealHeight: 600, maxHeight: 700)
        }
        .alert("Error", isPresented: $appState.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(appState.errorMessage ?? "An unknown error occurred")
        }
    }
}

// MARK: - Preview
#Preview {
    MainWindow()
        .environmentObject(AppState())
}
