import Foundation
import AVFoundation
import ScreenCaptureKit
import Combine

/// Represents an audio source that can be captured
struct AudioSource: Identifiable, Hashable {
    let id: String
    let name: String
    let bundleIdentifier: String?
    let icon: NSImage?
    let type: AudioSourceType

    enum AudioSourceType: String, Codable {
        case application
        case systemAudio
        case display
    }

    static func == (lhs: AudioSource, rhs: AudioSource) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Known meeting apps for auto-detection
enum MeetingApp: String, CaseIterable {
    case zoom = "us.zoom.xos"
    case teams = "com.microsoft.teams"
    case meet = "com.google.Chrome"  // Google Meet runs in browser
    case discord = "com.ggerganov.Discord"
    case slack = "com.tinyspeck.slackmacgap"
    case webex = "com.webex.meetingmanager"
    case facetime = "com.apple.FaceTime"
    case skype = "com.skype.skype"

    var displayName: String {
        switch self {
        case .zoom: return "Zoom"
        case .teams: return "Microsoft Teams"
        case .meet: return "Google Meet"
        case .discord: return "Discord"
        case .slack: return "Slack"
        case .webex: return "Webex"
        case .facetime: return "FaceTime"
        case .skype: return "Skype"
        }
    }
}

/// Error types for system audio operations
enum SystemAudioError: LocalizedError {
    case permissionDenied
    case noAudioAvailable
    case captureConfigurationFailed
    case captureFailed(Error)
    case noSourceSelected
    case unsupportedMacOSVersion

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Screen recording permission is required to capture system audio. Please enable it in System Settings → Privacy & Security → Screen Recording."
        case .noAudioAvailable:
            return "No audio is available from the selected source."
        case .captureConfigurationFailed:
            return "Failed to configure audio capture."
        case .captureFailed(let error):
            return "Audio capture failed: \(error.localizedDescription)"
        case .noSourceSelected:
            return "Please select an audio source to capture."
        case .unsupportedMacOSVersion:
            return "System audio capture requires macOS 13.0 or later."
        }
    }
}

/// Service for capturing system audio using ScreenCaptureKit
@MainActor
final class SystemAudioService: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var isCapturing = false
    @Published private(set) var availableSources: [AudioSource] = []
    @Published var selectedSource: AudioSource?
    @Published private(set) var audioLevel: Float = 0.0
    @Published private(set) var capturedDuration: TimeInterval = 0.0
    @Published private(set) var hasPermission = false
    @Published private(set) var detectedMeetingApps: [AudioSource] = []

    // MARK: - Audio Buffer
    /// Callback when a new audio chunk is available (16kHz mono Float32)
    var onAudioChunk: (([Float], TimeInterval) -> Void)?

    // MARK: - Private Properties
    private var stream: SCStream?
    private var streamOutput: SystemAudioStreamOutput?
    private var audioBuffer: [Float] = []
    private var captureStartTime: Date?
    private var durationTimer: Timer?
    private var pausedDuration: TimeInterval = 0.0  // Duration accumulated before pause
    private var isPaused = false

    // Audio format for Whisper (16kHz, mono, Float32)
    private let targetSampleRate: Double = 16000.0
    private let targetChannelCount: AVAudioChannelCount = 1

    // Chunking configuration
    private let chunkDuration: TimeInterval = 30.0  // Max chunk length
    private let chunkOverlap: TimeInterval = 1.0    // Overlap between chunks

    // MARK: - Initialization
    override init() {
        super.init()
        Task {
            await checkPermission()
        }
    }

    // MARK: - Permission Handling

    /// Check if screen recording permission is granted
    func checkPermission() async {
        // ScreenCaptureKit doesn't have a direct permission check API
        // We check by attempting to get shareable content
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            hasPermission = true
        } catch {
            hasPermission = false
        }
    }

    /// Request screen recording permission by triggering the system prompt
    func requestPermission() async throws {
        // Triggering SCShareableContent will prompt for permission if not granted
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            hasPermission = true
        } catch {
            hasPermission = false
            throw SystemAudioError.permissionDenied
        }
    }

    // MARK: - Source Discovery

    /// Refresh the list of available audio sources
    func refreshSources() async throws {
        if !hasPermission {
            try await requestPermission()
        }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)

        var sources: [AudioSource] = []
        var meetingApps: [AudioSource] = []

        // Add running applications as potential sources
        for app in content.applications {
            let source = AudioSource(
                id: app.bundleIdentifier,
                name: app.applicationName,
                bundleIdentifier: app.bundleIdentifier,
                icon: NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleIdentifier).first?.icon,
                type: .application
            )
            sources.append(source)

            // Check if this is a known meeting app
            if MeetingApp.allCases.contains(where: { $0.rawValue == app.bundleIdentifier }) {
                meetingApps.append(source)
            }
        }

        // Add system audio option (captures all audio)
        if let mainDisplay = content.displays.first {
            let systemAudioSource = AudioSource(
                id: "system-audio-\(mainDisplay.displayID)",
                name: "All System Audio",
                bundleIdentifier: nil,
                icon: NSImage(systemSymbolName: "speaker.wave.3.fill", accessibilityDescription: "System Audio"),
                type: .systemAudio
            )
            sources.insert(systemAudioSource, at: 0)
        }

        availableSources = sources
        detectedMeetingApps = meetingApps

        // Auto-select first meeting app if none selected
        if selectedSource == nil && !meetingApps.isEmpty {
            selectedSource = meetingApps.first
        }
    }

    // MARK: - Capture Control

    /// Start capturing audio from the selected source
    func startCapture() async throws {
        guard !isCapturing else { return }

        guard let source = selectedSource else {
            throw SystemAudioError.noSourceSelected
        }

        guard hasPermission else {
            throw SystemAudioError.permissionDenied
        }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)

        // Create content filter based on source type
        let filter: SCContentFilter

        switch source.type {
        case .application:
            guard let app = content.applications.first(where: { $0.bundleIdentifier == source.bundleIdentifier }) else {
                throw SystemAudioError.noAudioAvailable
            }
            // Capture only from the specific application
            filter = SCContentFilter(desktopIndependentWindow: content.windows.first { $0.owningApplication?.bundleIdentifier == app.bundleIdentifier } ?? content.windows.first!)

        case .systemAudio, .display:
            guard let display = content.displays.first else {
                throw SystemAudioError.captureConfigurationFailed
            }
            // Capture all system audio by excluding nothing
            filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        }

        // Configure stream for audio-only capture
        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = true
        configuration.excludesCurrentProcessAudio = true  // Don't capture our own app
        configuration.sampleRate = Int(targetSampleRate)
        configuration.channelCount = Int(targetChannelCount)

        // We don't need video, but SCStream requires it - use minimal settings
        configuration.width = 2
        configuration.height = 2
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 1)  // 1 fps minimum
        configuration.showsCursor = false

        // Create stream output handler
        streamOutput = SystemAudioStreamOutput { [weak self] samples, timestamp in
            Task { @MainActor in
                self?.processAudioSamples(samples, timestamp: timestamp)
            }
        }

        guard let streamOutput = streamOutput else {
            throw SystemAudioError.captureConfigurationFailed
        }

        // Create and start the stream
        stream = SCStream(filter: filter, configuration: configuration, delegate: nil)

        guard let stream = stream else {
            throw SystemAudioError.captureConfigurationFailed
        }

        try stream.addStreamOutput(streamOutput, type: .audio, sampleHandlerQueue: .global(qos: .userInitiated))

        do {
            try await stream.startCapture()
        } catch {
            throw SystemAudioError.captureFailed(error)
        }

        audioBuffer = []
        captureStartTime = Date()
        isCapturing = true
        startDurationTimer()
    }

    /// Stop capturing audio
    func stopCapture() async -> [Float] {
        guard isCapturing else { return [] }

        stopDurationTimer()

        do {
            try await stream?.stopCapture()
        } catch {
            print("[SystemAudioService] Error stopping capture: \(error)")
        }

        stream = nil
        streamOutput = nil
        isCapturing = false
        capturedDuration = 0.0
        pausedDuration = 0.0
        isPaused = false
        audioLevel = 0.0

        // Return the complete audio buffer
        let capturedAudio = audioBuffer
        audioBuffer = []
        return capturedAudio
    }

    /// Pause the duration timer (audio capture continues but time stops)
    func pauseTimer() {
        guard isCapturing, !isPaused else { return }
        isPaused = true
        // Save the current duration before stopping timer
        if let startTime = captureStartTime {
            pausedDuration = Date().timeIntervalSince(startTime)
        }
        stopDurationTimer()
    }

    /// Resume the duration timer
    func resumeTimer() {
        guard isCapturing, isPaused else { return }
        isPaused = false
        // Reset capture start time to account for paused duration
        captureStartTime = Date().addingTimeInterval(-pausedDuration)
        startDurationTimer()
    }

    /// Get the current audio buffer without stopping capture
    func getCurrentBuffer() -> [Float] {
        return audioBuffer
    }

    /// Clear the audio buffer
    func clearBuffer() {
        audioBuffer = []
    }

    // MARK: - Private Methods

    private func processAudioSamples(_ samples: [Float], timestamp: TimeInterval) {
        // Append to main buffer
        audioBuffer.append(contentsOf: samples)

        // Calculate audio level for visualization
        let rms = SystemAudioService.computeRMSLevel(from: samples)
        audioLevel = min(rms * 10, 1.0)

        // Check if we have enough audio for a chunk
        let samplesPerChunk = Int(targetSampleRate * chunkDuration)
        if audioBuffer.count >= samplesPerChunk {
            // Extract chunk with overlap
            let chunkSamples = Array(audioBuffer.prefix(samplesPerChunk))
            let overlapSamples = Int(targetSampleRate * chunkOverlap)

            // Remove processed samples, keeping overlap
            if audioBuffer.count > overlapSamples {
                audioBuffer.removeFirst(samplesPerChunk - overlapSamples)
            }

            // Notify listener of new chunk
            let chunkTimestamp = capturedDuration - chunkDuration
            onAudioChunk?(chunkSamples, max(0, chunkTimestamp))
        }
    }

    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let startTime = self.captureStartTime else { return }
                self.capturedDuration = Date().timeIntervalSince(startTime)
            }
        }
    }

    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }

    /// Compute the RMS (root mean square) level of audio data
    static func computeRMSLevel(from samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0.0 }

        var sum: Float = 0.0
        for sample in samples {
            sum += sample * sample
        }

        return sqrt(sum / Float(samples.count))
    }
}

// MARK: - Stream Output Handler

private class SystemAudioStreamOutput: NSObject, SCStreamOutput {
    private let onAudioReceived: ([Float], TimeInterval) -> Void
    private let targetSampleRate: Double = 16000.0

    init(onAudioReceived: @escaping ([Float], TimeInterval) -> Void) {
        self.onAudioReceived = onAudioReceived
        super.init()
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }

        // Extract audio samples from the CMSampleBuffer
        guard let samples = extractAudioSamples(from: sampleBuffer) else { return }

        // Get timestamp
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let timeSeconds = CMTimeGetSeconds(timestamp)

        onAudioReceived(samples, timeSeconds)
    }

    private func extractAudioSamples(from sampleBuffer: CMSampleBuffer) -> [Float]? {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return nil }

        var length: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?

        let status = CMBlockBufferGetDataPointer(
            blockBuffer,
            atOffset: 0,
            lengthAtOffsetOut: nil,
            totalLengthOut: &length,
            dataPointerOut: &dataPointer
        )

        guard status == kCMBlockBufferNoErr, let dataPointer = dataPointer else { return nil }

        // Get audio format description
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) else { return nil }
        guard let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)?.pointee else { return nil }

        // Convert to Float32 samples
        let sampleCount = length / Int(asbd.mBytesPerFrame)
        var floatSamples = [Float](repeating: 0, count: sampleCount)

        if asbd.mFormatFlags & kAudioFormatFlagIsFloat != 0 {
            // Already float format
            dataPointer.withMemoryRebound(to: Float.self, capacity: sampleCount) { floatPointer in
                for i in 0..<sampleCount {
                    floatSamples[i] = floatPointer[i]
                }
            }
        } else if asbd.mBitsPerChannel == 16 {
            // Convert from Int16
            dataPointer.withMemoryRebound(to: Int16.self, capacity: sampleCount) { int16Pointer in
                for i in 0..<sampleCount {
                    floatSamples[i] = Float(int16Pointer[i]) / Float(Int16.max)
                }
            }
        } else if asbd.mBitsPerChannel == 32 {
            // Convert from Int32
            dataPointer.withMemoryRebound(to: Int32.self, capacity: sampleCount) { int32Pointer in
                for i in 0..<sampleCount {
                    floatSamples[i] = Float(int32Pointer[i]) / Float(Int32.max)
                }
            }
        }

        // Convert to mono if stereo
        if asbd.mChannelsPerFrame > 1 {
            let monoSampleCount = sampleCount / Int(asbd.mChannelsPerFrame)
            var monoSamples = [Float](repeating: 0, count: monoSampleCount)
            for i in 0..<monoSampleCount {
                var sum: Float = 0
                for ch in 0..<Int(asbd.mChannelsPerFrame) {
                    sum += floatSamples[i * Int(asbd.mChannelsPerFrame) + ch]
                }
                monoSamples[i] = sum / Float(asbd.mChannelsPerFrame)
            }
            return monoSamples
        }

        return floatSamples
    }
}
