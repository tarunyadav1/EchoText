import AVFoundation
import Combine

/// Service for audio playback with precise timing control for transcript synchronization
@MainActor
final class AudioPlaybackService: NSObject, ObservableObject, AVAudioPlayerDelegate {

    // MARK: - Published State

    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published var playbackRate: Float = 1.0 {
        didSet {
            audioPlayer?.rate = playbackRate
        }
    }
    @Published private(set) var isLoaded: Bool = false
    @Published private(set) var loadedFileURL: URL?

    // MARK: - Available Playback Rates

    static let availableRates: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 2.5, 3.0]

    // MARK: - Private Properties

    private var audioPlayer: AVAudioPlayer?
    private var timeObserverTimer: Timer?

    // MARK: - Initialization

    override init() {
        super.init()
    }

    // MARK: - Public Methods

    /// Load an audio file for playback
    func load(url: URL) async throws {
        // Stop any current playback
        stop()

        // Create audio player
        let player = try AVAudioPlayer(contentsOf: url)
        player.delegate = self
        player.enableRate = true
        player.prepareToPlay()

        audioPlayer = player
        duration = player.duration
        loadedFileURL = url
        isLoaded = true
        currentTime = 0
    }

    /// Start or resume playback
    func play() {
        guard let player = audioPlayer, isLoaded else { return }

        // If at the end, restart from beginning
        if currentTime >= duration - 0.1 {
            player.currentTime = 0
            currentTime = 0
        }

        player.rate = playbackRate
        player.play()
        isPlaying = true
        startTimeObserver()
    }

    /// Pause playback
    func pause() {
        guard let player = audioPlayer else { return }

        player.pause()
        currentTime = player.currentTime
        isPlaying = false
        stopTimeObserver()
    }

    /// Toggle between play and pause
    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    /// Stop playback and reset to beginning
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil

        timeObserverTimer?.invalidate()
        timeObserverTimer = nil

        isLoaded = false
        isPlaying = false
        currentTime = 0
        duration = 0
        loadedFileURL = nil
    }

    /// Seek to a specific time
    func seek(to time: TimeInterval) {
        guard let player = audioPlayer, isLoaded else { return }

        // Clamp time to valid range
        let clampedTime = max(0, min(time, duration))
        player.currentTime = clampedTime
        currentTime = clampedTime
    }

    /// Skip forward by specified seconds
    func skipForward(_ seconds: TimeInterval = 5.0) {
        guard isLoaded else { return }
        seek(to: currentTime + seconds)
    }

    /// Skip backward by specified seconds
    func skipBackward(_ seconds: TimeInterval = 5.0) {
        guard isLoaded else { return }
        seek(to: currentTime - seconds)
    }

    /// Increase playback rate to next available step
    func increaseRate() {
        if let currentIndex = Self.availableRates.firstIndex(of: playbackRate),
           currentIndex < Self.availableRates.count - 1 {
            playbackRate = Self.availableRates[currentIndex + 1]
        }
    }

    /// Decrease playback rate to previous available step
    func decreaseRate() {
        if let currentIndex = Self.availableRates.firstIndex(of: playbackRate),
           currentIndex > 0 {
            playbackRate = Self.availableRates[currentIndex - 1]
        }
    }

    // MARK: - AVAudioPlayerDelegate

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.currentTime = self.duration
            self.stopTimeObserver()
        }
    }

    // MARK: - Private Methods

    private func startTimeObserver() {
        stopTimeObserver()

        // Update time every 50ms for smooth UI updates
        timeObserverTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateCurrentTime()
            }
        }
    }

    private func stopTimeObserver() {
        timeObserverTimer?.invalidate()
        timeObserverTimer = nil
    }

    private func updateCurrentTime() {
        guard let player = audioPlayer, isPlaying else { return }
        currentTime = player.currentTime
    }
}

// MARK: - Time Formatting

extension AudioPlaybackService {
    /// Format time as MM:SS
    static func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Format time as MM:SS.mmm (with milliseconds)
    static func formatTimeWithMilliseconds(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d.%03d", minutes, seconds, milliseconds)
    }
}

// MARK: - Segment Sync

extension AudioPlaybackService {
    /// Find the segment index for the current playback time
    func currentSegmentIndex(for segments: [TranscriptionSegment]) -> Int? {
        segments.firstIndex { segment in
            currentTime >= segment.startTime && currentTime < segment.endTime
        }
    }

    /// Check if the playback is within a specific segment
    func isWithinSegment(_ segment: TranscriptionSegment) -> Bool {
        currentTime >= segment.startTime && currentTime < segment.endTime
    }
}
