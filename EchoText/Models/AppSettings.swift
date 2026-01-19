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

    // MARK: - Transcription Engine Settings
    /// The active transcription engine (Whisper or Parakeet)
    @Published var transcriptionEngine: TranscriptionEngine = .whisper
    /// Selected Parakeet model ID
    @Published var selectedParakeetModelId: String = ParakeetModel.defaultModel.id

    // MARK: - Voice Activity Detection
    @Published var vadSilenceThreshold: TimeInterval = 1.5
    @Published var vadEnergyThreshold: Float = 0.01

    // MARK: - UI Settings
    @Published var showFloatingWindow: Bool = true
    @Published var floatingWindowOpacity: Double = 0.95
    @Published var showMenuBarIcon: Bool = true
    @Published var launchAtLogin: Bool = false

    // MARK: - Display Settings
    @Published var compactMode: Bool = false

    // MARK: - Onboarding
    @Published var hasCompletedOnboarding: Bool = false
    @Published var lastUsedVersion: String = ""

    // MARK: - Focus Mode
    @Published var focusModeSettings: FocusModeSettings = FocusModeSettings()

    // MARK: - Realtime Captions
    @Published var captionsSettings: CaptionsSettings = CaptionsSettings()

    // MARK: - Speaker Diarization
    @Published var enableSpeakerDiarization: Bool = false

    // MARK: - Meeting Transcription
    @Published var meetingChunkDuration: TimeInterval = 30.0
    @Published var meetingOverlapDuration: TimeInterval = 1.0
    @Published var meetingSilenceThreshold: TimeInterval = 1.5
    @Published var autoDetectMeetingApps: Bool = true

    // MARK: - Custom Vocabulary
    @Published var customVocabulary: [String] = []

    // MARK: - Text Processing
    @Published var removeFillerWords: Bool = true

    // MARK: - Segment Filtering Settings
    /// Hide silence markers like [SILENCE], [BLANK_AUDIO], etc. from transcript display
    @Published var filterSilenceSegments: Bool = false
    /// Hide filler words like "um", "uh", "like" from transcript display
    @Published var filterFillerWords: Bool = false
    /// User-defined regex patterns to filter from transcripts
    @Published var customFilterPatterns: [String] = []

    // MARK: - File Transcription Settings
    /// Automatically start transcription when files are dropped (e.g., from Voice Memos)
    @Published var autoStartTranscription: Bool = true

    // MARK: - Advanced Whisper Parameters
    /// Controls randomness in transcription (0.0 = deterministic, 1.0 = max randomness)
    @Published var whisperTemperature: Double = 0.0
    /// Beam search width for decoding (higher = more accurate but slower)
    @Published var whisperBeamSize: Int = 5
    /// Number of candidate transcriptions to consider (higher = better quality but slower)
    @Published var whisperBestOf: Int = 1
    /// Threshold for detecting silence/no speech (lower = more sensitive)
    @Published var whisperNoSpeechThreshold: Double = 0.6
    /// Threshold for compression ratio to detect hallucinations
    @Published var whisperCompressionRatioThreshold: Double = 2.4

    // MARK: - Timestamp Offset Settings
    /// Whether to apply timestamp offset during export
    @Published var timestampOffsetEnabled: Bool = false
    /// Timestamp offset in seconds (can be negative to shift earlier)
    @Published var timestampOffset: TimeInterval = 0.0
    /// Whether to always apply the default offset on export
    @Published var alwaysApplyTimestampOffset: Bool = false

    // MARK: - Watch Folder Settings
    /// Whether watch folder automation is enabled
    @Published var watchFolderEnabled: Bool = false
    /// Path to the input folder to monitor for new media files
    @Published var watchFolderInputPath: String?
    /// Path to the output folder for transcription results (nil = same as input)
    @Published var watchFolderOutputPath: String?
    /// Export format for watch folder transcriptions
    @Published var watchFolderExportFormat: ExportFormat = .txt
    /// Whether to start watch folder monitoring when app launches
    @Published var watchFolderAutoStart: Bool = true

    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case recordingMode
        case selectedLanguage
        case autoInsertText
        case playFeedbackSounds
        case selectedModelId
        case autoDownloadModels
        case transcriptionEngine
        case selectedParakeetModelId
        case vadSilenceThreshold
        case vadEnergyThreshold
        case showFloatingWindow
        case floatingWindowOpacity
        case showMenuBarIcon
        case launchAtLogin
        case compactMode
        case hasCompletedOnboarding
        case lastUsedVersion
        case focusModeSettings
        case captionsSettings
        case enableSpeakerDiarization
        case meetingChunkDuration
        case meetingOverlapDuration
        case meetingSilenceThreshold
        case autoDetectMeetingApps
        case customVocabulary
        case removeFillerWords
        case filterSilenceSegments
        case filterFillerWords
        case customFilterPatterns
        case autoStartTranscription
        // Advanced Whisper Parameters
        case whisperTemperature
        case whisperBeamSize
        case whisperBestOf
        case whisperNoSpeechThreshold
        case whisperCompressionRatioThreshold
        // Timestamp Offset Settings
        case timestampOffsetEnabled
        case timestampOffset
        case alwaysApplyTimestampOffset
        // Watch Folder Settings
        case watchFolderEnabled
        case watchFolderInputPath
        case watchFolderOutputPath
        case watchFolderExportFormat
        case watchFolderAutoStart
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
        transcriptionEngine = try container.decodeIfPresent(TranscriptionEngine.self, forKey: .transcriptionEngine) ?? .whisper
        selectedParakeetModelId = try container.decodeIfPresent(String.self, forKey: .selectedParakeetModelId) ?? ParakeetModel.defaultModel.id
        vadSilenceThreshold = try container.decodeIfPresent(TimeInterval.self, forKey: .vadSilenceThreshold) ?? 1.5
        vadEnergyThreshold = try container.decodeIfPresent(Float.self, forKey: .vadEnergyThreshold) ?? 0.01
        showFloatingWindow = try container.decodeIfPresent(Bool.self, forKey: .showFloatingWindow) ?? true
        floatingWindowOpacity = try container.decodeIfPresent(Double.self, forKey: .floatingWindowOpacity) ?? 0.95
        showMenuBarIcon = try container.decodeIfPresent(Bool.self, forKey: .showMenuBarIcon) ?? true
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        compactMode = try container.decodeIfPresent(Bool.self, forKey: .compactMode) ?? false
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        lastUsedVersion = try container.decodeIfPresent(String.self, forKey: .lastUsedVersion) ?? ""
        focusModeSettings = try container.decodeIfPresent(FocusModeSettings.self, forKey: .focusModeSettings) ?? FocusModeSettings()
        captionsSettings = try container.decodeIfPresent(CaptionsSettings.self, forKey: .captionsSettings) ?? CaptionsSettings()
        enableSpeakerDiarization = try container.decodeIfPresent(Bool.self, forKey: .enableSpeakerDiarization) ?? false
        meetingChunkDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .meetingChunkDuration) ?? 30.0
        meetingOverlapDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .meetingOverlapDuration) ?? 1.0
        meetingSilenceThreshold = try container.decodeIfPresent(TimeInterval.self, forKey: .meetingSilenceThreshold) ?? 1.5
        autoDetectMeetingApps = try container.decodeIfPresent(Bool.self, forKey: .autoDetectMeetingApps) ?? true
        customVocabulary = try container.decodeIfPresent([String].self, forKey: .customVocabulary) ?? []
        removeFillerWords = try container.decodeIfPresent(Bool.self, forKey: .removeFillerWords) ?? true
        filterSilenceSegments = try container.decodeIfPresent(Bool.self, forKey: .filterSilenceSegments) ?? false
        filterFillerWords = try container.decodeIfPresent(Bool.self, forKey: .filterFillerWords) ?? false
        customFilterPatterns = try container.decodeIfPresent([String].self, forKey: .customFilterPatterns) ?? []
        autoStartTranscription = try container.decodeIfPresent(Bool.self, forKey: .autoStartTranscription) ?? true
        // Advanced Whisper Parameters
        whisperTemperature = try container.decodeIfPresent(Double.self, forKey: .whisperTemperature) ?? 0.0
        whisperBeamSize = try container.decodeIfPresent(Int.self, forKey: .whisperBeamSize) ?? 5
        whisperBestOf = try container.decodeIfPresent(Int.self, forKey: .whisperBestOf) ?? 1
        whisperNoSpeechThreshold = try container.decodeIfPresent(Double.self, forKey: .whisperNoSpeechThreshold) ?? 0.6
        whisperCompressionRatioThreshold = try container.decodeIfPresent(Double.self, forKey: .whisperCompressionRatioThreshold) ?? 2.4
        // Timestamp Offset Settings
        timestampOffsetEnabled = try container.decodeIfPresent(Bool.self, forKey: .timestampOffsetEnabled) ?? false
        timestampOffset = try container.decodeIfPresent(TimeInterval.self, forKey: .timestampOffset) ?? 0.0
        alwaysApplyTimestampOffset = try container.decodeIfPresent(Bool.self, forKey: .alwaysApplyTimestampOffset) ?? false
        // Watch Folder Settings
        watchFolderEnabled = try container.decodeIfPresent(Bool.self, forKey: .watchFolderEnabled) ?? false
        watchFolderInputPath = try container.decodeIfPresent(String.self, forKey: .watchFolderInputPath)
        watchFolderOutputPath = try container.decodeIfPresent(String.self, forKey: .watchFolderOutputPath)
        watchFolderExportFormat = try container.decodeIfPresent(ExportFormat.self, forKey: .watchFolderExportFormat) ?? .txt
        watchFolderAutoStart = try container.decodeIfPresent(Bool.self, forKey: .watchFolderAutoStart) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(recordingMode, forKey: .recordingMode)
        try container.encode(selectedLanguage, forKey: .selectedLanguage)
        try container.encode(autoInsertText, forKey: .autoInsertText)
        try container.encode(playFeedbackSounds, forKey: .playFeedbackSounds)
        try container.encode(selectedModelId, forKey: .selectedModelId)
        try container.encode(autoDownloadModels, forKey: .autoDownloadModels)
        try container.encode(transcriptionEngine, forKey: .transcriptionEngine)
        try container.encode(selectedParakeetModelId, forKey: .selectedParakeetModelId)
        try container.encode(vadSilenceThreshold, forKey: .vadSilenceThreshold)
        try container.encode(vadEnergyThreshold, forKey: .vadEnergyThreshold)
        try container.encode(showFloatingWindow, forKey: .showFloatingWindow)
        try container.encode(floatingWindowOpacity, forKey: .floatingWindowOpacity)
        try container.encode(showMenuBarIcon, forKey: .showMenuBarIcon)
        try container.encode(launchAtLogin, forKey: .launchAtLogin)
        try container.encode(compactMode, forKey: .compactMode)
        try container.encode(hasCompletedOnboarding, forKey: .hasCompletedOnboarding)
        try container.encode(lastUsedVersion, forKey: .lastUsedVersion)
        try container.encode(focusModeSettings, forKey: .focusModeSettings)
        try container.encode(captionsSettings, forKey: .captionsSettings)
        try container.encode(enableSpeakerDiarization, forKey: .enableSpeakerDiarization)
        try container.encode(meetingChunkDuration, forKey: .meetingChunkDuration)
        try container.encode(meetingOverlapDuration, forKey: .meetingOverlapDuration)
        try container.encode(meetingSilenceThreshold, forKey: .meetingSilenceThreshold)
        try container.encode(autoDetectMeetingApps, forKey: .autoDetectMeetingApps)
        try container.encode(customVocabulary, forKey: .customVocabulary)
        try container.encode(removeFillerWords, forKey: .removeFillerWords)
        try container.encode(filterSilenceSegments, forKey: .filterSilenceSegments)
        try container.encode(filterFillerWords, forKey: .filterFillerWords)
        try container.encode(customFilterPatterns, forKey: .customFilterPatterns)
        try container.encode(autoStartTranscription, forKey: .autoStartTranscription)
        // Advanced Whisper Parameters
        try container.encode(whisperTemperature, forKey: .whisperTemperature)
        try container.encode(whisperBeamSize, forKey: .whisperBeamSize)
        try container.encode(whisperBestOf, forKey: .whisperBestOf)
        try container.encode(whisperNoSpeechThreshold, forKey: .whisperNoSpeechThreshold)
        try container.encode(whisperCompressionRatioThreshold, forKey: .whisperCompressionRatioThreshold)
        // Timestamp Offset Settings
        try container.encode(timestampOffsetEnabled, forKey: .timestampOffsetEnabled)
        try container.encode(timestampOffset, forKey: .timestampOffset)
        try container.encode(alwaysApplyTimestampOffset, forKey: .alwaysApplyTimestampOffset)
        // Watch Folder Settings
        try container.encode(watchFolderEnabled, forKey: .watchFolderEnabled)
        try container.encodeIfPresent(watchFolderInputPath, forKey: .watchFolderInputPath)
        try container.encodeIfPresent(watchFolderOutputPath, forKey: .watchFolderOutputPath)
        try container.encode(watchFolderExportFormat, forKey: .watchFolderExportFormat)
        try container.encode(watchFolderAutoStart, forKey: .watchFolderAutoStart)
    }

    // MARK: - Persistence
    private static let settingsKey = "com.echotext.settings"

    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            print("[AppSettings] No saved settings found, returning defaults (engine: whisper)")
            return AppSettings()
        }
        print("[AppSettings] Loaded settings from disk: engine=\(settings.transcriptionEngine.rawValue)")
        return settings
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else {
            print("[AppSettings] Failed to encode settings for save")
            return
        }
        UserDefaults.standard.set(data, forKey: AppSettings.settingsKey)
        print("[AppSettings] Saved settings to disk: engine=\(transcriptionEngine.rawValue)")
    }

    var selectedModel: WhisperModel {
        WhisperModel.availableModels.first { $0.id == selectedModelId } ?? WhisperModel.defaultModel
    }

    var selectedParakeetModel: ParakeetModel {
        ParakeetModel.availableModels.first { $0.id == selectedParakeetModelId } ?? ParakeetModel.defaultModel
    }

    /// Returns the currently active engine's model name for display
    var activeModelName: String {
        switch transcriptionEngine {
        case .whisper:
            return selectedModel.name
        case .parakeet:
            return selectedParakeetModel.name
        }
    }

    // MARK: - Reset Advanced Settings

    /// Reset all advanced Whisper parameters to their default values
    func resetAdvancedWhisperSettings() {
        whisperTemperature = 0.0
        whisperBeamSize = 5
        whisperBestOf = 1
        whisperNoSpeechThreshold = 0.6
        whisperCompressionRatioThreshold = 2.4
        save()
    }

    /// Reset timestamp offset settings to their default values
    func resetTimestampOffsetSettings() {
        timestampOffsetEnabled = false
        timestampOffset = 0.0
        alwaysApplyTimestampOffset = false
        save()
    }

    // MARK: - Reset Filter Settings

    /// Reset all segment filter settings to their default values
    func resetFilterSettings() {
        filterSilenceSegments = false
        filterFillerWords = false
        customFilterPatterns = []
        save()
    }

    // MARK: - Reset Captions Settings

    /// Reset captions settings to their default values
    func resetCaptionsSettings() {
        captionsSettings = CaptionsSettings()
        save()
    }

    // MARK: - Reset Watch Folder Settings

    /// Reset watch folder settings to their default values
    func resetWatchFolderSettings() {
        watchFolderEnabled = false
        watchFolderInputPath = nil
        watchFolderOutputPath = nil
        watchFolderExportFormat = .txt
        watchFolderAutoStart = true
        save()
    }
}
