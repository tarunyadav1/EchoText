import Foundation
import Combine

/// Voice Activity Detection (VAD) service for automatic recording stop
@MainActor
final class VoiceActivityDetector: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var isSpeechDetected = false
    @Published private(set) var silenceDuration: TimeInterval = 0.0

    // MARK: - Configuration
    var energyThreshold: Float = 0.01
    var silenceThreshold: TimeInterval = 1.5

    // MARK: - Private Properties
    private var lastSpeechTime: Date?
    private var silenceTimer: Timer?
    private var isMonitoring = false

    // Callback when silence threshold is exceeded
    var onSilenceDetected: (() -> Void)?

    // MARK: - Initialization
    init(energyThreshold: Float = 0.01, silenceThreshold: TimeInterval = 1.5) {
        self.energyThreshold = energyThreshold
        self.silenceThreshold = silenceThreshold
    }

    deinit {
        // Clean up timer directly without calling MainActor method
        silenceTimer?.invalidate()
    }

    // MARK: - Public Methods

    /// Start monitoring audio levels for voice activity
    func startMonitoring() {
        guard !isMonitoring else { return }

        isMonitoring = true
        lastSpeechTime = Date()
        silenceDuration = 0.0
        isSpeechDetected = false

        // Start timer to check silence duration
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkSilenceDuration()
            }
        }
    }

    /// Stop monitoring voice activity
    func stopMonitoring() {
        isMonitoring = false
        silenceTimer?.invalidate()
        silenceTimer = nil
        silenceDuration = 0.0
        isSpeechDetected = false
    }

    /// Process audio level to detect speech
    /// - Parameter level: Audio level (0.0 - 1.0)
    func processAudioLevel(_ level: Float) {
        guard isMonitoring else { return }

        if level > energyThreshold {
            // Speech detected
            isSpeechDetected = true
            lastSpeechTime = Date()
            silenceDuration = 0.0
        } else {
            // Silence detected
            isSpeechDetected = false
        }
    }

    /// Process raw audio samples for more accurate VAD
    /// - Parameter samples: Array of audio samples
    func processAudioSamples(_ samples: [Float]) {
        guard isMonitoring else { return }

        let rms = AudioRecordingService.computeRMSLevel(from: samples)
        processAudioLevel(rms)
    }

    // MARK: - Private Methods

    private func checkSilenceDuration() {
        guard isMonitoring, let lastSpeech = lastSpeechTime else { return }

        silenceDuration = Date().timeIntervalSince(lastSpeech)

        if silenceDuration >= silenceThreshold {
            onSilenceDetected?()
            stopMonitoring()
        }
    }
}

// MARK: - VAD Configuration
extension VoiceActivityDetector {
    struct Configuration {
        var energyThreshold: Float
        var silenceThreshold: TimeInterval

        static let `default` = Configuration(
            energyThreshold: 0.01,
            silenceThreshold: 1.5
        )

        static let sensitive = Configuration(
            energyThreshold: 0.005,
            silenceThreshold: 2.0
        )

        static let aggressive = Configuration(
            energyThreshold: 0.02,
            silenceThreshold: 1.0
        )
    }

    func apply(configuration: Configuration) {
        self.energyThreshold = configuration.energyThreshold
        self.silenceThreshold = configuration.silenceThreshold
    }
}
