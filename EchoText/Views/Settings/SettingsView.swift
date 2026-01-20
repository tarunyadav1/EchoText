import SwiftUI
import KeyboardShortcuts

/// Settings view with top tab bar navigation
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: SettingsTab = .general

    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case shortcuts = "Shortcuts"
        case permissions = "Permissions"
        case model = "Model"
        case advanced = "Advanced"
        case vocabulary = "Vocabulary"
        case diarization = "Speakers"
        case updates = "Updates"
        case license = "License"

        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .shortcuts: return "keyboard"
            case .permissions: return "hand.raised"
            case .model: return "cpu"
            case .advanced: return "slider.horizontal.3"
            case .vocabulary: return "character.book.closed"
            case .diarization: return "person.2"
            case .updates: return "arrow.triangle.2.circlepath"
            case .license: return "star.circle"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top tab bar
            tabBar
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)

            Divider()

            // Content area
            ScrollView(showsIndicators: false) {
                selectedTabContent
                    .padding(32)
                    .frame(maxWidth: 700, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .animation(.easeInOut(duration: 0.2), value: selectedTab)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    tabButton(tab)
                }
            }
            .padding(4)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func tabButton(_ tab: SettingsTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12))
                Text(tab.rawValue)
                    .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
            }
            .foregroundColor(selectedTab == tab ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                selectedTab == tab
                    ? DesignSystem.Colors.accent
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content

    @ViewBuilder
    private var selectedTabContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedTab.rawValue)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))

                Text(tabDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Content based on selected tab
            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsSection()
                case .shortcuts:
                    ShortcutsSettingsSection()
                case .permissions:
                    PermissionsSettingsSection()
                case .model:
                    ModelSettingsSection()
                case .advanced:
                    AdvancedSettingsSection()
                case .vocabulary:
                    VocabularySettingsSection()
                case .diarization:
                    DiarizationSettingsSection()
                case .updates:
                    UpdatesSettingsSection()
                case .license:
                    LicenseSettingsSection()
                }
            }
        }
    }

    private var tabDescription: String {
        switch selectedTab {
        case .general:
            return "Configure recording mode, language, and behavior"
        case .shortcuts:
            return "Customize global keyboard shortcuts"
        case .permissions:
            return "Manage system permissions for EchoText"
        case .model:
            return "Choose transcription engine and manage models"
        case .advanced:
            return "Fine-tune transcription parameters"
        case .vocabulary:
            return "Add custom words to improve accuracy"
        case .diarization:
            return "Configure speaker detection and labeling"
        case .updates:
            return "Check for updates and configure automatic updates"
        case .license:
            return "Manage your EchoText Pro license"
        }
    }
}

// MARK: - Custom Settings Section Component (Liquid Glass)

struct SettingsSection<Content: View>: View {
    let title: String
    var footer: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))

            if let footer = footer {
                Text(footer)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.8))
                    .padding(.horizontal, 4)
            }
        }
    }
}

// MARK: - Settings Row Component

struct SettingsRow: View {
    let label: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 14))
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Settings Toggle Row

struct SettingsToggleRow: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }
}

// MARK: - Settings Divider

struct SettingsDivider: View {
    var body: some View {
        Divider()
            .padding(.vertical, 8)
    }
}

// MARK: - General Settings Section

struct GeneralSettingsSection: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Recording Mode
            SettingsSection(title: "Recording Mode") {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Mode", selection: $appState.settings.recordingMode) {
                        ForEach(RecordingMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    Label(appState.settings.recordingMode.description, systemImage: appState.settings.recordingMode.iconName)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }

            // Language
            SettingsSection(title: "Language", footer: "Select the language you'll be speaking") {
                HStack {
                    Text("Language")
                        .font(.system(size: 14))
                    Spacer()
                    Picker("Language", selection: $appState.settings.selectedLanguage) {
                        ForEach(SupportedLanguage.allLanguages) { language in
                            Text(language.displayName).tag(language.code)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 200)
                }
            }

            // Behavior
            SettingsSection(title: "Behavior", footer: "Auto-insert types text into the active app. Floating indicator shows recording status.") {
                VStack(alignment: .leading, spacing: 0) {
                    SettingsToggleRow(label: "Auto-insert text", isOn: $appState.settings.autoInsertText)
                    SettingsDivider()
                    SettingsToggleRow(label: "Show floating indicator", isOn: $appState.settings.showFloatingWindow)
                }
            }

            // Display
            SettingsSection(title: "Display", footer: "Hide timestamps in transcript segments") {
                SettingsToggleRow(label: "Compact mode", isOn: $appState.settings.compactMode)
            }

            // Text Processing
            SettingsSection(title: "Text Processing", footer: "Removes \"um\", \"uh\", \"like\", and other speech disfluencies") {
                SettingsToggleRow(label: "Remove filler words", isOn: $appState.settings.removeFillerWords)
            }

            // Privacy & Feedback
            PrivacyAndFeedbackSection()
        }
    }
}

// MARK: - Privacy & Feedback Section

struct PrivacyAndFeedbackSection: View {
    @State private var telemetryEnabled: Bool = TelemetryService.shared.telemetryEnabled
    @State private var showFeedback = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsSection(title: "Privacy", footer: "Anonymous analytics help us improve EchoText. No personal data is collected.") {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Send anonymous analytics")
                                .font(.system(size: 14))
                            Text("Usage patterns, errors, and app health")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $telemetryEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: telemetryEnabled) { _, newValue in
                                if newValue {
                                    TelemetryService.shared.enable()
                                } else {
                                    TelemetryService.shared.disable()
                                }
                            }
                    }
                }
            }

            SettingsSection(title: "Feedback", footer: "Help us make EchoText better for everyone.") {
                Button {
                    showFeedback = true
                } label: {
                    HStack {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 14))
                        Text("Send Feedback...")
                            .font(.system(size: 14))
                    }
                }
                .sheet(isPresented: $showFeedback) {
                    FeedbackView()
                }
            }
        }
    }
}

// MARK: - Shortcuts Settings Section

struct ShortcutsSettingsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsSection(title: "Recording Shortcuts", footer: "Shortcuts work globally, even when EchoText is in the background.") {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Toggle Recording")
                                .font(.system(size: 14))
                            Text("Start or stop voice recording")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        KeyboardShortcuts.Recorder(for: .toggleRecording)
                    }

                    SettingsDivider()

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Cancel Recording")
                                .font(.system(size: 14))
                            Text("Cancel without transcribing")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        KeyboardShortcuts.Recorder(for: .cancelRecording)
                    }
                }
            }
        }
    }
}

// MARK: - Model Settings Section

struct ModelSettingsSection: View {
    @EnvironmentObject var appState: AppState
    @State private var isChangingModel = false
    @State private var pendingModelId: String?
    @State private var showDeleteConfirmation = false
    @State private var modelToDelete: String?
    @State private var errorMessage: String?
    @State private var showError = false

    private let whisperModels: [(id: String, name: String, size: String, speed: String, quality: String, icon: String)] = [
        ("openai_whisper-tiny", "Tiny", "75 MB", "Fastest", "Basic", "hare"),
        ("openai_whisper-base", "Base", "142 MB", "Fast", "Good", "figure.walk"),
        ("openai_whisper-small", "Small", "466 MB", "Medium", "Better", "figure.run"),
        ("openai_whisper-medium", "Medium", "1.5 GB", "Slow", "Best", "tortoise")
    ]

    private let parakeetModels: [(id: String, name: String, size: String, speed: String, quality: String, icon: String, languages: String)] = [
        ("parakeet-tdt-0.6b-v2", "Parakeet TDT v2", "600 MB", "190x RT", "Excellent", "bolt.fill", "English only")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Engine Selection
            SettingsSection(title: "Transcription Engine") {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Engine", selection: $appState.settings.transcriptionEngine) {
                        Text("Whisper").tag(TranscriptionEngine.whisper)
                        Text("Parakeet").tag(TranscriptionEngine.parakeet)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .onChange(of: appState.settings.transcriptionEngine) { _, newValue in
                        Task {
                            appState.settings.save()
                            await appState.loadDefaultModel()
                        }
                    }

                    HStack(spacing: 8) {
                        Image(systemName: appState.settings.transcriptionEngine == .parakeet ? "bolt.fill" : "globe")
                            .foregroundColor(.secondary)
                        Text(appState.settings.transcriptionEngine == .parakeet
                             ? "Up to 190x realtime · English only"
                             : "10-50x realtime · 99+ languages")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
            }

            // English-only notice for Parakeet
            if appState.settings.transcriptionEngine == .parakeet {
                Label("Parakeet only supports English. Use Whisper for other languages.", systemImage: "info.circle")
                    .font(.system(size: 13))
                    .foregroundColor(.orange)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassEffect(.regular.tint(.orange), in: RoundedRectangle(cornerRadius: 12))
            }

            // Current Model Status
            SettingsSection(title: "Current Model") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(appState.settings.activeModelName)
                                .font(.system(size: 15, weight: .semibold))

                            HStack(spacing: 6) {
                                Circle()
                                    .fill(appState.isActiveEngineModelLoaded ? Color.green : Color.gray)
                                    .frame(width: 8, height: 8)
                                Text(appState.isActiveEngineModelLoaded ? "Ready" : "Not loaded")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                    }

                    // Show helpful hint when model isn't loaded
                    if !appState.isActiveEngineModelLoaded {
                        Text("Click \"Load Model\" below to download and activate the model (~\(appState.settings.transcriptionEngine == .parakeet ? "600 MB" : "varies")).")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                    }
                }
            }

            // Available Models
            SettingsSection(title: "Available Models", footer: "Larger models provide better accuracy but require more memory.") {
                VStack(alignment: .leading, spacing: 0) {
                    if appState.settings.transcriptionEngine == .whisper {
                        ForEach(Array(whisperModels.enumerated()), id: \.element.id) { index, model in
                            modelRow(
                                name: model.name,
                                detail: "\(model.size) · \(model.speed)",
                                isActive: appState.settings.selectedModelId == model.id,
                                isLoaded: appState.whisperService.isModelLoaded && appState.whisperService.loadedModelId == model.id,
                                onSelect: { selectWhisperModel(model.id) },
                                onDelete: {
                                    modelToDelete = model.id
                                    showDeleteConfirmation = true
                                }
                            )
                            if index < whisperModels.count - 1 {
                                SettingsDivider()
                            }
                        }
                    } else {
                        ForEach(Array(parakeetModels.enumerated()), id: \.element.id) { index, model in
                            modelRow(
                                name: model.name,
                                detail: "\(model.size) · \(model.speed)",
                                isActive: appState.settings.selectedParakeetModelId == model.id,
                                isLoaded: appState.parakeetService.isModelLoaded && appState.parakeetService.loadedModelId == model.id,
                                onSelect: { selectParakeetModel(model.id) },
                                onDelete: {
                                    modelToDelete = model.id
                                    showDeleteConfirmation = true
                                }
                            )
                            if index < parakeetModels.count - 1 {
                                SettingsDivider()
                            }
                        }
                    }
                }
            }
        }
        .overlay {
            if isChangingModel {
                ProgressView("Loading model...")
                    .padding(24)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .alert("Delete Model?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let modelId = modelToDelete {
                    deleteModel(modelId)
                }
            }
        } message: {
            Text("This will remove the model from disk. You can re-download it anytime.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
    }

    // MARK: - Model Row

    private func modelRow(name: String, detail: String, isActive: Bool, isLoaded: Bool = true, onSelect: @escaping () -> Void, onDelete: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 14, weight: isActive ? .semibold : .regular))
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isActive {
                if isLoaded {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DesignSystem.Colors.accent)
                        .font(.system(size: 18))
                } else {
                    // Model is selected but not loaded - show Load button
                    Button("Load Model") {
                        onSelect()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            } else {
                Button("Select") {
                    onSelect()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Model", systemImage: "trash")
            }
        }
    }

    // MARK: - Actions

    private func selectWhisperModel(_ modelId: String) {
        isChangingModel = true
        pendingModelId = modelId

        Task {
            appState.settings.selectedModelId = modelId
            appState.settings.transcriptionEngine = .whisper

            do {
                try await appState.whisperService.loadModel(modelId)
            } catch {
                errorMessage = "Failed to load Whisper model: \(error.localizedDescription)"
                showError = true
            }

            await MainActor.run {
                isChangingModel = false
                pendingModelId = nil
            }
        }
    }

    private func selectParakeetModel(_ modelId: String) {
        isChangingModel = true
        pendingModelId = modelId

        Task {
            appState.settings.selectedParakeetModelId = modelId
            appState.settings.transcriptionEngine = .parakeet

            do {
                try await appState.parakeetService.loadModel(modelId)
            } catch {
                errorMessage = "Failed to load Parakeet model: \(error.localizedDescription)"
                showError = true
            }

            await MainActor.run {
                isChangingModel = false
                pendingModelId = nil
            }
        }
    }

    private func deleteModel(_ modelId: String) {
        Task {
            do {
                if modelId.contains("whisper") {
                    try appState.whisperService.deleteModel(modelId)
                } else {
                    try appState.parakeetService.deleteModel(modelId)
                }
            } catch {
                errorMessage = "Failed to delete model: \(error.localizedDescription)"
                showError = true
            }
        }
    }
}

// MARK: - Advanced Settings Section

struct AdvancedSettingsSection: View {
    @EnvironmentObject var appState: AppState
    @State private var showResetConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Transcription Parameters
            SettingsSection(title: "Transcription Parameters", footer: "Temperature controls randomness. Beam Size and Best Of affect accuracy vs speed.") {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Temperature")
                                .font(.system(size: 14))
                            Spacer()
                            Text(String(format: "%.1f", appState.settings.whisperTemperature))
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $appState.settings.whisperTemperature, in: 0.0...1.0, step: 0.1)
                    }

                    SettingsDivider()

                    HStack {
                        Text("Beam Size")
                            .font(.system(size: 14))
                        Spacer()
                        Stepper("\(appState.settings.whisperBeamSize)", value: $appState.settings.whisperBeamSize, in: 1...10)
                            .labelsHidden()
                        Text("\(appState.settings.whisperBeamSize)")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                            .frame(width: 24, alignment: .trailing)
                    }

                    SettingsDivider()

                    HStack {
                        Text("Best Of")
                            .font(.system(size: 14))
                        Spacer()
                        Stepper("\(appState.settings.whisperBestOf)", value: $appState.settings.whisperBestOf, in: 1...5)
                            .labelsHidden()
                        Text("\(appState.settings.whisperBestOf)")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                            .frame(width: 24, alignment: .trailing)
                    }
                }
            }

            // Detection Thresholds
            SettingsSection(title: "Detection Thresholds", footer: "Adjust sensitivity for silence detection and hallucination prevention.") {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("No Speech Threshold")
                                .font(.system(size: 14))
                            Spacer()
                            Text(String(format: "%.2f", appState.settings.whisperNoSpeechThreshold))
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $appState.settings.whisperNoSpeechThreshold, in: 0.0...1.0, step: 0.05)
                    }

                    SettingsDivider()

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Compression Ratio")
                                .font(.system(size: 14))
                            Spacer()
                            Text(String(format: "%.1f", appState.settings.whisperCompressionRatioThreshold))
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $appState.settings.whisperCompressionRatioThreshold, in: 1.0...5.0, step: 0.1)
                    }
                }
            }

            // Reset
            SettingsSection(title: "Reset", footer: "Default values work well for most use cases.") {
                Button(role: .destructive) {
                    showResetConfirmation = true
                } label: {
                    Text("Reset to Defaults")
                        .font(.system(size: 14))
                }
            }
        }
        .alert("Reset Advanced Settings?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                appState.settings.resetAdvancedWhisperSettings()
            }
        } message: {
            Text("This will restore all advanced Whisper parameters to their default values.")
        }
        .onChange(of: appState.settings.whisperTemperature) { _, _ in appState.settings.save() }
        .onChange(of: appState.settings.whisperBeamSize) { _, _ in appState.settings.save() }
        .onChange(of: appState.settings.whisperBestOf) { _, _ in appState.settings.save() }
        .onChange(of: appState.settings.whisperNoSpeechThreshold) { _, _ in appState.settings.save() }
        .onChange(of: appState.settings.whisperCompressionRatioThreshold) { _, _ in appState.settings.save() }
    }
}

// MARK: - Permissions Settings Section

struct PermissionsSettingsSection: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Microphone
            SettingsSection(title: "Required", footer: "Microphone access is required to capture your voice for transcription.") {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Label("Microphone", systemImage: "mic.fill")
                            .font(.system(size: 14))
                        Spacer()
                        permissionStatusView(appState.permissionService.microphoneStatus)
                    }

                    if appState.permissionService.microphoneStatus == .notDetermined {
                        SettingsDivider()
                        Button("Request Access") {
                            Task {
                                _ = await appState.permissionService.requestMicrophonePermission()
                            }
                        }
                        .font(.system(size: 14))
                    } else if appState.permissionService.microphoneStatus == .denied {
                        SettingsDivider()
                        Button("Open System Settings") {
                            appState.permissionService.openMicrophoneSettings()
                        }
                        .font(.system(size: 14))
                    }
                }
            }

            // Accessibility
            SettingsSection(title: "Recommended", footer: "Accessibility enables global hotkeys and auto-inserting text into any app.") {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Label("Accessibility", systemImage: "hand.raised.fill")
                            .font(.system(size: 14))
                        Spacer()
                        permissionStatusView(appState.permissionService.accessibilityStatus)
                    }

                    if appState.permissionService.accessibilityStatus == .notDetermined {
                        SettingsDivider()
                        Button("Request Access") {
                            appState.permissionService.requestAccessibilityPermission()
                        }
                        .font(.system(size: 14))
                    } else if appState.permissionService.accessibilityStatus == .denied {
                        SettingsDivider()
                        Button("Open System Settings") {
                            appState.permissionService.openAccessibilitySettings()
                        }
                        .font(.system(size: 14))
                    }
                }
            }

            // Status
            SettingsSection(title: "Status") {
                VStack(alignment: .leading, spacing: 0) {
                    if appState.permissionService.microphoneStatus == .granted &&
                       appState.permissionService.accessibilityStatus == .granted {
                        Label("All permissions granted", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.green)
                    } else {
                        Label("Some permissions missing", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.orange)
                    }

                    SettingsDivider()

                    Button("Refresh Status") {
                        appState.permissionService.checkAllPermissions()
                    }
                    .font(.system(size: 14))
                }
            }
        }
    }

    @ViewBuilder
    private func permissionStatusView(_ status: PermissionStatus) -> some View {
        switch status {
        case .granted:
            Text("Enabled")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.green)
        case .denied:
            Text("Denied")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.red)
        case .notDetermined:
            Text("Not Set")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Diarization Settings Section

struct DiarizationSettingsSection: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsSection(title: "Speaker Detection", footer: "Automatically identify and label different speakers in transcriptions.") {
                SettingsToggleRow(label: "Enable speaker diarization", isOn: $appState.settings.enableSpeakerDiarization)
            }

            if appState.settings.enableSpeakerDiarization {
                SettingsSection(title: "Diarization Engine", footer: "Uses Apple's built-in speaker diarization for fast, on-device processing.") {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Label("Status", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 14))
                            Spacer()
                            Text("Ready")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.green)
                        }
                        SettingsDivider()
                        HStack {
                            Label("Engine", systemImage: "cpu")
                                .font(.system(size: 14))
                            Spacer()
                            Text("Apple Intelligence")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                SettingsSection(title: "Features", footer: "Best for interviews, meetings, and conversations with 2-4 speakers.") {
                    VStack(alignment: .leading, spacing: 0) {
                        Label("Analyzes audio to detect unique voice patterns", systemImage: "waveform.path.ecg")
                            .font(.system(size: 13))
                        SettingsDivider()
                        Label("Assigns labels like \"Speaker 1\", \"Speaker 2\"", systemImage: "person.2.badge.plus")
                            .font(.system(size: 13))
                        SettingsDivider()
                        Label("Rename speakers after transcription", systemImage: "pencil.circle")
                            .font(.system(size: 13))
                        SettingsDivider()
                        Label("Speaker labels included in exports", systemImage: "square.and.arrow.up")
                            .font(.system(size: 13))
                    }
                }
            }
        }
    }
}

// MARK: - Vocabulary Settings Section

struct VocabularySettingsSection: View {
    @EnvironmentObject var appState: AppState
    @State private var newWord: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsSection(title: "Add Custom Words", footer: "Add technical jargon, acronyms, or brand names. Separate multiple words with commas.") {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Word or phrase", text: $newWord)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .padding(10)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .onSubmit {
                            addWord()
                        }

                    Button("Add Word") {
                        addWord()
                    }
                    .font(.system(size: 14))
                    .disabled(newWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            SettingsSection(title: "Your Dictionary (\(appState.settings.customVocabulary.count) words)", footer: "These words are passed as hints to improve transcription accuracy.") {
                if appState.settings.customVocabulary.isEmpty {
                    Text("No custom words added yet")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(appState.settings.customVocabulary.enumerated()), id: \.element) { index, word in
                            HStack {
                                Text(word)
                                    .font(.system(size: 14))
                                Spacer()
                                Button(role: .destructive) {
                                    removeWord(word)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 16))
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(.vertical, 4)

                            if index < appState.settings.customVocabulary.count - 1 {
                                SettingsDivider()
                            }
                        }
                    }
                }
            }
        }
    }

    private func addWord() {
        let trimmed = newWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let words = trimmed.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for word in words {
            if !appState.settings.customVocabulary.contains(word) {
                appState.settings.customVocabulary.append(word)
            }
        }

        newWord = ""
        appState.settings.save()
    }

    private func removeWord(_ word: String) {
        appState.settings.customVocabulary.removeAll { $0 == word }
        appState.settings.save()
    }
}

// MARK: - Updates Settings Section

struct UpdatesSettingsSection: View {
    @StateObject private var updateService = UpdateService.shared
    @State private var automaticChecks: Bool = true
    @State private var automaticDownloads: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Current Version
            SettingsSection(title: "Current Version") {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("EchoText \(updateService.currentVersion)")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Build \(updateService.currentBuild)")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 20))
                    }
                }
            }

            // Check for Updates
            SettingsSection(title: "Check for Updates", footer: "Last checked: \(updateService.lastCheckDateFormatted)") {
                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        updateService.checkForUpdates()
                    } label: {
                        HStack {
                            if updateService.isCheckingForUpdates {
                                ProgressView()
                                    .controlSize(.small)
                                    .padding(.trailing, 4)
                            }
                            Text(updateService.isCheckingForUpdates ? "Checking..." : "Check for Updates")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(updateService.isCheckingForUpdates || !updateService.canCheckForUpdates)
                }
            }

            // Automatic Updates
            SettingsSection(title: "Automatic Updates", footer: "When enabled, EchoText will periodically check for updates in the background.") {
                VStack(alignment: .leading, spacing: 0) {
                    SettingsToggleRow(label: "Check for updates automatically", isOn: $automaticChecks)
                        .onChange(of: automaticChecks) { _, newValue in
                            updateService.automaticUpdateChecks = newValue
                        }

                    SettingsDivider()

                    SettingsToggleRow(label: "Download updates automatically", isOn: $automaticDownloads)
                        .onChange(of: automaticDownloads) { _, newValue in
                            updateService.automaticDownloads = newValue
                        }
                        .disabled(!automaticChecks)
                        .opacity(automaticChecks ? 1.0 : 0.5)
                }
            }

            // Update Channel Info
            SettingsSection(title: "About Updates") {
                VStack(alignment: .leading, spacing: 0) {
                    Label("Updates are delivered securely via Sparkle", systemImage: "lock.shield")
                        .font(.system(size: 13))
                    SettingsDivider()
                    Label("All updates are signed and verified", systemImage: "checkmark.seal")
                        .font(.system(size: 13))
                    SettingsDivider()
                    Label("Your data never leaves your device", systemImage: "hand.raised")
                        .font(.system(size: 13))
                }
            }
        }
        .onAppear {
            automaticChecks = updateService.automaticUpdateChecks
            automaticDownloads = updateService.automaticDownloads
        }
    }
}

// MARK: - Legacy compatibility

struct ShortcutsSettingsTab: View {
    var body: some View {
        ShortcutsSettingsSection()
            .padding()
    }
}

struct PermissionsSettingsTab: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        PermissionsSettingsSection()
            .environmentObject(appState)
            .padding()
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
        .frame(width: 800, height: 600)
}
