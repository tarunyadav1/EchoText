import Foundation
import SwiftUI

/// User preferences for the application
final class AppSettings: ObservableObject, Codable {
    // MARK: - Recording Settings
    @Published var recordingMode: RecordingMode = .pressToToggle
    @Published var selectedLanguage: String = "auto"
    @Published var autoInsertText: Bool = true
    @Published var playFeedbackSounds: Bool = true

    // MARK: - Model Settings
    @Published var selectedModelId: String = WhisperModel.defaultModel.id
    @Published var autoDownloadModels: Bool = false

    // MARK: - Voice Activity Detection
    @Published var vadSilenceThreshold: TimeInterval = 1.5
    @Published var vadEnergyThreshold: Float = 0.01

    // MARK: - UI Settings
    @Published var showFloatingWindow: Bool = true
    @Published var floatingWindowOpacity: Double = 0.95
    @Published var showMenuBarIcon: Bool = true
    @Published var launchAtLogin: Bool = false

    // MARK: - Onboarding
    @Published var hasCompletedOnboarding: Bool = false
    @Published var lastUsedVersion: String = ""

    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case recordingMode
        case selectedLanguage
        case autoInsertText
        case playFeedbackSounds
        case selectedModelId
        case autoDownloadModels
        case vadSilenceThreshold
        case vadEnergyThreshold
        case showFloatingWindow
        case floatingWindowOpacity
        case showMenuBarIcon
        case launchAtLogin
        case hasCompletedOnboarding
        case lastUsedVersion
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        recordingMode = try container.decodeIfPresent(RecordingMode.self, forKey: .recordingMode) ?? .pressToToggle
        selectedLanguage = try container.decodeIfPresent(String.self, forKey: .selectedLanguage) ?? "auto"
        autoInsertText = try container.decodeIfPresent(Bool.self, forKey: .autoInsertText) ?? true
        playFeedbackSounds = try container.decodeIfPresent(Bool.self, forKey: .playFeedbackSounds) ?? true
        selectedModelId = try container.decodeIfPresent(String.self, forKey: .selectedModelId) ?? WhisperModel.defaultModel.id
        autoDownloadModels = try container.decodeIfPresent(Bool.self, forKey: .autoDownloadModels) ?? false
        vadSilenceThreshold = try container.decodeIfPresent(TimeInterval.self, forKey: .vadSilenceThreshold) ?? 1.5
        vadEnergyThreshold = try container.decodeIfPresent(Float.self, forKey: .vadEnergyThreshold) ?? 0.01
        showFloatingWindow = try container.decodeIfPresent(Bool.self, forKey: .showFloatingWindow) ?? true
        floatingWindowOpacity = try container.decodeIfPresent(Double.self, forKey: .floatingWindowOpacity) ?? 0.95
        showMenuBarIcon = try container.decodeIfPresent(Bool.self, forKey: .showMenuBarIcon) ?? true
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        lastUsedVersion = try container.decodeIfPresent(String.self, forKey: .lastUsedVersion) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(recordingMode, forKey: .recordingMode)
        try container.encode(selectedLanguage, forKey: .selectedLanguage)
        try container.encode(autoInsertText, forKey: .autoInsertText)
        try container.encode(playFeedbackSounds, forKey: .playFeedbackSounds)
        try container.encode(selectedModelId, forKey: .selectedModelId)
        try container.encode(autoDownloadModels, forKey: .autoDownloadModels)
        try container.encode(vadSilenceThreshold, forKey: .vadSilenceThreshold)
        try container.encode(vadEnergyThreshold, forKey: .vadEnergyThreshold)
        try container.encode(showFloatingWindow, forKey: .showFloatingWindow)
        try container.encode(floatingWindowOpacity, forKey: .floatingWindowOpacity)
        try container.encode(showMenuBarIcon, forKey: .showMenuBarIcon)
        try container.encode(launchAtLogin, forKey: .launchAtLogin)
        try container.encode(hasCompletedOnboarding, forKey: .hasCompletedOnboarding)
        try container.encode(lastUsedVersion, forKey: .lastUsedVersion)
    }

    // MARK: - Persistence
    private static let settingsKey = "com.echotext.settings"

    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return settings
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: AppSettings.settingsKey)
    }

    var selectedModel: WhisperModel {
        WhisperModel.availableModels.first { $0.id == selectedModelId } ?? WhisperModel.defaultModel
    }
}
