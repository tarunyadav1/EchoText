import AVFoundation
import AVKit
import Combine

/// Service for video playback with precise timing control for subtitle synchronization
@MainActor
final class VideoPlayerService: ObservableObject {

    // MARK: - Published State

    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published var playbackRate: Float = 1.0 {
        didSet {
            applyPlaybackRate()
        }
    }
    @Published private(set) var isLoaded: Bool = false
    @Published private(set) var loadedFileURL: URL?
    @Published private(set) var loadError: String?

    // MARK: - Available Playback Rates

    static let availableRates: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 2.5, 3.0]

    // MARK: - Supported Video Formats

    static let supportedVideoExtensions: Set<String> = ["mp4", "mov", "m4v", "avi", "mkv", "webm"]

    /// Check if a file URL is a supported video format
    static func isVideoFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return supportedVideoExtensions.contains(ext)
    }

    // MARK: - Public Properties

    /// The AVPlayer instance for use with AVKit's VideoPlayer
    let player: AVPlayer

    // MARK: - Private Properties

    private var timeObserver: Any?
    private var statusObservation: NSKeyValueObservation?
    private var durationObservation: NSKeyValueObservation?
    private var rateObservation: NSKeyValueObservation?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        self.player = AVPlayer()
        setupObservers()
    }

    deinit {
        // Remove time observer
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
        }
        // Cancel all observations
        statusObservation?.invalidate()
        durationObservation?.invalidate()
        rateObservation?.invalidate()
    }

    // MARK: - Setup

    private func setupObservers() {
        // Observe player rate to detect play/pause
        rateObservation = player.observe(\.rate, options: [.new]) { [weak self] player, _ in
            Task { @MainActor in
                self?.isPlaying = player.rate > 0
            }
        }
    }

    private func setupTimeObserver() {
        // Remove existing observer
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }

        // Add periodic time observer (every 50ms for smooth subtitle sync)
        let interval = CMTime(seconds: 0.05, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self = self else { return }
                let seconds = CMTimeGetSeconds(time)
                if seconds.isFinite {
                    self.currentTime = seconds
                }
            }
        }
    }

    // MARK: - Public Methods

    /// Load a video file for playback
    func load(url: URL) async throws {
        // Stop any current playback
        stop()
        loadError = nil

        // Verify file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            loadError = "Video file not found"
            throw NSError(domain: "VideoPlayerService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Video file not found"])
        }

        // Create asset and load its properties
        let asset = AVURLAsset(url: url)

        do {
            // Load duration asynchronously
            let duration = try await asset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)

            // Check if playable
            let isPlayable = try await asset.load(.isPlayable)
            guard isPlayable else {
                loadError = "Video format not supported"
                throw NSError(domain: "VideoPlayerService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Video format not supported"])
            }

            // Create player item
            let playerItem = AVPlayerItem(asset: asset)

            // Replace current item
            player.replaceCurrentItem(with: playerItem)

            // Setup observers for the new item
            setupTimeObserver()
            setupItemObservers(playerItem)

            // Update state
            self.duration = durationSeconds.isFinite ? durationSeconds : 0
            self.loadedFileURL = url
            self.isLoaded = true
            self.currentTime = 0

        } catch {
            loadError = error.localizedDescription
            throw error
        }
    }

    private func setupItemObservers(_ item: AVPlayerItem) {
        // Observe when playback reaches end
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: item)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.handlePlaybackCompletion()
                }
            }
            .store(in: &cancellables)
    }

    /// Start or resume playback
    func play() {
        guard isLoaded else { return }
        player.play()
        applyPlaybackRate()
    }

    /// Pause playback
    func pause() {
        player.pause()
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
        player.pause()
        player.seek(to: .zero)
        player.replaceCurrentItem(with: nil)

        // Remove time observer
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }

        // Cancel item observers
        cancellables.removeAll()

        // Reset state
        isLoaded = false
        isPlaying = false
        currentTime = 0
        duration = 0
        loadedFileURL = nil
        loadError = nil
    }

    /// Seek to a specific time
    func seek(to time: TimeInterval) {
        guard isLoaded else { return }

        // Clamp time to valid range
        let clampedTime = max(0, min(time, duration))
        let cmTime = CMTime(seconds: clampedTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))

        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor in
                self?.currentTime = clampedTime
            }
        }
    }

    /// Skip forward by specified seconds
    func skipForward(_ seconds: TimeInterval = 5.0) {
        seek(to: currentTime + seconds)
    }

    /// Skip backward by specified seconds
    func skipBackward(_ seconds: TimeInterval = 5.0) {
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

    // MARK: - Private Methods

    private func handlePlaybackCompletion() {
        isPlaying = false
        currentTime = duration
    }

    private func applyPlaybackRate() {
        guard isPlaying else { return }
        player.rate = playbackRate
    }
}

// MARK: - Time Formatting

extension VideoPlayerService {
    /// Format time as MM:SS
    static func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite && time >= 0 else { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Format time as HH:MM:SS for longer videos
    static func formatTimeLong(_ time: TimeInterval) -> String {
        guard time.isFinite && time >= 0 else { return "0:00:00" }
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    /// Format time as MM:SS.mmm (with milliseconds)
    static func formatTimeWithMilliseconds(_ time: TimeInterval) -> String {
        guard time.isFinite && time >= 0 else { return "00:00.000" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d.%03d", minutes, seconds, milliseconds)
    }
}
