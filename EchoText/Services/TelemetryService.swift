import Foundation
import TelemetryDeck

/// Service for privacy-focused analytics and crash reporting using TelemetryDeck
///
/// TelemetryDeck is a privacy-first analytics service that:
/// - Does not collect personal data
/// - Does not use cookies or fingerprinting
/// - Is GDPR compliant by default
/// - Aggregates data so individual users cannot be identified
final class TelemetryService {
    /// Shared instance
    static let shared = TelemetryService()

    /// Whether telemetry is enabled (respects user preference)
    private var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "telemetryEnabled")
    }

    private init() {
        // Initialize TelemetryDeck with app ID
        let config = TelemetryDeck.Config(appID: Constants.Telemetry.appID)
        TelemetryDeck.initialize(config: config)

        // Set default to enabled (user can opt-out in settings)
        if UserDefaults.standard.object(forKey: "telemetryEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "telemetryEnabled")
        }

        NSLog("[TelemetryService] Initialized with app ID: \(Constants.Telemetry.appID.prefix(8))...")
    }

    // MARK: - App Lifecycle Events

    /// Track app launch
    func trackAppLaunch() {
        guard isEnabled else { return }
        TelemetryDeck.signal("app.launched", parameters: [
            "version": Constants.appVersion,
            "build": Constants.buildNumber,
            "firstLaunch": String(!UserDefaults.standard.bool(forKey: "hasLaunchedBefore"))
        ])
        UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
    }

    /// Track app becoming active
    func trackAppBecameActive() {
        guard isEnabled else { return }
        TelemetryDeck.signal("app.becameActive")
    }

    /// Track app termination
    func trackAppTerminated() {
        guard isEnabled else { return }
        TelemetryDeck.signal("app.terminated")
    }

    // MARK: - Feature Usage Events

    /// Track recording started
    func trackRecordingStarted(mode: String) {
        guard isEnabled else { return }
        TelemetryDeck.signal("recording.started", parameters: [
            "mode": mode
        ])
    }

    /// Track recording completed
    func trackRecordingCompleted(durationSeconds: Int, wordCount: Int) {
        guard isEnabled else { return }
        TelemetryDeck.signal("recording.completed", parameters: [
            "durationBucket": durationBucket(durationSeconds),
            "wordCountBucket": wordCountBucket(wordCount)
        ])
    }

    /// Track transcription completed
    func trackTranscriptionCompleted(engine: String, modelSize: String, durationSeconds: Int) {
        guard isEnabled else { return }
        TelemetryDeck.signal("transcription.completed", parameters: [
            "engine": engine,
            "modelSize": modelSize,
            "durationBucket": durationBucket(durationSeconds)
        ])
    }

    /// Track file transcription
    func trackFileTranscription(fileType: String) {
        guard isEnabled else { return }
        TelemetryDeck.signal("file.transcribed", parameters: [
            "fileType": fileType
        ])
    }

    /// Track export
    func trackExport(format: String) {
        guard isEnabled else { return }
        TelemetryDeck.signal("export.completed", parameters: [
            "format": format
        ])
    }

    /// Track model download
    func trackModelDownload(modelId: String) {
        guard isEnabled else { return }
        TelemetryDeck.signal("model.downloaded", parameters: [
            "modelId": modelId
        ])
    }

    /// Track feature used
    func trackFeatureUsed(_ feature: String) {
        guard isEnabled else { return }
        TelemetryDeck.signal("feature.used", parameters: [
            "feature": feature
        ])
    }

    // MARK: - Error Events

    /// Track error occurred
    func trackError(_ error: Error, context: String) {
        guard isEnabled else { return }
        TelemetryDeck.signal("error.occurred", parameters: [
            "context": context,
            "errorType": String(describing: type(of: error)),
            "errorDescription": error.localizedDescription.prefix(100).description
        ])
    }

    /// Track crash (called on next launch if crash detected)
    func trackCrashOnPreviousLaunch() {
        guard isEnabled else { return }
        TelemetryDeck.signal("app.crashedPreviousLaunch")
    }

    // MARK: - Settings Events

    /// Track settings changed
    func trackSettingChanged(_ setting: String, value: String) {
        guard isEnabled else { return }
        TelemetryDeck.signal("setting.changed", parameters: [
            "setting": setting,
            "value": value
        ])
    }

    /// Track onboarding completed
    func trackOnboardingCompleted() {
        guard isEnabled else { return }
        TelemetryDeck.signal("onboarding.completed")
    }

    /// Track license activated
    func trackLicenseActivated() {
        guard isEnabled else { return }
        TelemetryDeck.signal("license.activated")
    }

    // MARK: - Navigation Events

    /// Track screen viewed
    func trackScreenViewed(_ screen: String) {
        guard isEnabled else { return }
        TelemetryDeck.signal("screen.viewed", parameters: [
            "screen": screen
        ])
    }

    // MARK: - Helpers

    /// Bucket duration to avoid tracking exact values
    private func durationBucket(_ seconds: Int) -> String {
        switch seconds {
        case 0..<10: return "0-10s"
        case 10..<30: return "10-30s"
        case 30..<60: return "30-60s"
        case 60..<120: return "1-2min"
        case 120..<300: return "2-5min"
        case 300..<600: return "5-10min"
        default: return "10min+"
        }
    }

    /// Bucket word count to avoid tracking exact values
    private func wordCountBucket(_ count: Int) -> String {
        switch count {
        case 0..<10: return "0-10"
        case 10..<50: return "10-50"
        case 50..<100: return "50-100"
        case 100..<500: return "100-500"
        case 500..<1000: return "500-1000"
        default: return "1000+"
        }
    }

    // MARK: - User Preferences

    /// Enable telemetry
    func enable() {
        UserDefaults.standard.set(true, forKey: "telemetryEnabled")
        NSLog("[TelemetryService] Telemetry enabled")
    }

    /// Disable telemetry
    func disable() {
        UserDefaults.standard.set(false, forKey: "telemetryEnabled")
        NSLog("[TelemetryService] Telemetry disabled")
    }

    /// Check if telemetry is enabled
    var telemetryEnabled: Bool {
        isEnabled
    }
}
