import SwiftUI
import AVKit

/// Inline video player with synced subtitles overlay
struct VideoPlayerView: View {
    @ObservedObject var videoService: VideoPlayerService
    let segments: [TranscriptionSegment]
    let onSegmentTap: (TranscriptionSegment) -> Void

    @State private var showControls: Bool = true
    @State private var controlsHideTask: Task<Void, Never>?
    @State private var isHoveringVideo: Bool = false
    @State private var currentSegmentIndex: Int?
    @State private var showSubtitles: Bool = true

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Video player with subtitle overlay
                videoPlayerSection(geometry: geometry)

                Divider()

                // Synced transcript list
                transcriptListSection
            }
        }
    }

    // MARK: - Video Player Section

    @ViewBuilder
    private func videoPlayerSection(geometry: GeometryProxy) -> some View {
        let videoHeight = min(geometry.size.height * 0.5, 400)

        ZStack(alignment: .bottom) {
            // Video player
            VideoPlayer(player: videoService.player)
                .frame(height: videoHeight)
                .background(Color.black)
                .onHover { hovering in
                    isHoveringVideo = hovering
                    if hovering {
                        showControlsTemporarily()
                    }
                }
                .onTapGesture {
                    videoService.togglePlayback()
                    showControlsTemporarily()
                }

            // Subtitle overlay
            if showSubtitles, let segment = currentSegment {
                subtitleOverlay(text: segment.text)
                    .padding(.bottom, showControls ? 80 : 40)
            }

            // Custom controls overlay
            if showControls || !videoService.isPlaying {
                controlsOverlay
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showControls)
        .onChange(of: videoService.currentTime) { _, _ in
            updateCurrentSegment()
        }
    }

    // MARK: - Subtitle Overlay

    @ViewBuilder
    private func subtitleOverlay(text: String) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.75))
            )
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .frame(maxWidth: 600)
            .padding(.horizontal, 20)
    }

    // MARK: - Controls Overlay

    private var controlsOverlay: some View {
        VStack(spacing: 0) {
            Spacer()

            // Progress bar and controls
            VStack(spacing: 8) {
                // Seek slider
                seekSlider

                // Control buttons
                HStack(spacing: 16) {
                    // Play/Pause
                    Button {
                        videoService.togglePlayback()
                        showControlsTemporarily()
                    } label: {
                        Image(systemName: videoService.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.plain)

                    // Skip backward
                    Button {
                        videoService.skipBackward(5)
                        showControlsTemporarily()
                    } label: {
                        Image(systemName: "gobackward.5")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)

                    // Skip forward
                    Button {
                        videoService.skipForward(5)
                        showControlsTemporarily()
                    } label: {
                        Image(systemName: "goforward.5")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)

                    // Time display
                    Text("\(VideoPlayerService.formatTime(videoService.currentTime)) / \(VideoPlayerService.formatTime(videoService.duration))")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))

                    Spacer()

                    // Playback speed
                    Menu {
                        ForEach(VideoPlayerService.availableRates, id: \.self) { rate in
                            Button {
                                videoService.playbackRate = rate
                            } label: {
                                HStack {
                                    Text(formatRate(rate))
                                    if videoService.playbackRate == rate {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Text(formatRate(videoService.playbackRate))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.white.opacity(0.2)))
                    }
                    .menuStyle(.borderlessButton)

                    // Subtitle toggle
                    Button {
                        showSubtitles.toggle()
                    } label: {
                        Image(systemName: showSubtitles ? "captions.bubble.fill" : "captions.bubble")
                            .font(.system(size: 16))
                            .foregroundColor(showSubtitles ? DesignSystem.Colors.accent : .white)
                    }
                    .buttonStyle(.plain)
                    .help(showSubtitles ? "Hide subtitles" : "Show subtitles")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    // MARK: - Seek Slider

    private var seekSlider: some View {
        GeometryReader { geometry in
            let width = geometry.size.width - 32

            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 4)

                // Progress track
                RoundedRectangle(cornerRadius: 2)
                    .fill(DesignSystem.Colors.accent)
                    .frame(width: progressWidth(totalWidth: width), height: 4)

                // Segment markers
                ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                    if videoService.duration > 0 {
                        let position = segment.startTime / videoService.duration * width
                        Rectangle()
                            .fill(currentSegmentIndex == index ? DesignSystem.Colors.accent : Color.white.opacity(0.5))
                            .frame(width: 2, height: currentSegmentIndex == index ? 8 : 6)
                            .offset(x: position)
                    }
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 20)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let progress = max(0, min(1, (value.location.x - 16) / width))
                        let seekTime = progress * videoService.duration
                        videoService.seek(to: seekTime)
                        showControlsTemporarily()
                    }
            )
        }
        .frame(height: 20)
    }

    private func progressWidth(totalWidth: CGFloat) -> CGFloat {
        guard videoService.duration > 0 else { return 0 }
        let progress = videoService.currentTime / videoService.duration
        return max(0, min(totalWidth, progress * totalWidth))
    }

    // MARK: - Transcript List Section

    private var transcriptListSection: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                    VideoTranscriptSegmentRow(
                        segment: segment,
                        index: index,
                        isCurrentSegment: currentSegmentIndex == index,
                        isPlaying: currentSegmentIndex == index && videoService.isPlaying,
                        onTap: {
                            videoService.seek(to: segment.startTime)
                            if !videoService.isPlaying {
                                videoService.play()
                            }
                            onSegmentTap(segment)
                        }
                    )
                    .id(index)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .onChange(of: currentSegmentIndex) { _, newIndex in
                if let index = newIndex {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(index, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - Helper Methods

    private var currentSegment: TranscriptionSegment? {
        guard let index = currentSegmentIndex, index >= 0, index < segments.count else {
            return nil
        }
        return segments[index]
    }

    private func updateCurrentSegment() {
        let time = videoService.currentTime

        // Find segment containing current playback time
        for (index, segment) in segments.enumerated() {
            if time >= segment.startTime && time < segment.endTime {
                if currentSegmentIndex != index {
                    currentSegmentIndex = index
                }
                return
            }
        }

        // If past all segments, select last one
        if time >= (segments.last?.endTime ?? 0) && !segments.isEmpty {
            currentSegmentIndex = segments.count - 1
        } else if time < (segments.first?.startTime ?? 0) {
            currentSegmentIndex = nil
        }
    }

    private func showControlsTemporarily() {
        showControls = true

        // Cancel existing hide task
        controlsHideTask?.cancel()

        // Schedule hide after 3 seconds if playing
        controlsHideTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !Task.isCancelled && videoService.isPlaying && !isHoveringVideo {
                await MainActor.run {
                    showControls = false
                }
            }
        }
    }

    private func formatRate(_ rate: Float) -> String {
        if rate == 1.0 {
            return "1x"
        } else if rate == floor(rate) {
            return "\(Int(rate))x"
        } else {
            return String(format: "%.2gx", rate)
        }
    }
}

// MARK: - Video Transcript Segment Row

struct VideoTranscriptSegmentRow: View {
    let segment: TranscriptionSegment
    let index: Int
    let isCurrentSegment: Bool
    let isPlaying: Bool
    let onTap: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timestamp
            Text(formatTime(segment.startTime))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(isCurrentSegment ? DesignSystem.Colors.accent : .secondary)
                .frame(width: 50, alignment: .trailing)

            // Playing indicator
            if isPlaying {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 10))
                    .foregroundColor(DesignSystem.Colors.accent)
                    .frame(width: 16)
            } else if isCurrentSegment {
                Image(systemName: "play.fill")
                    .font(.system(size: 8))
                    .foregroundColor(DesignSystem.Colors.accent)
                    .frame(width: 16)
            } else {
                Color.clear
                    .frame(width: 16)
            }

            // Text
            Text(segment.text)
                .font(.system(size: 14))
                .foregroundColor(isCurrentSegment ? .primary : .secondary)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isCurrentSegment ? DesignSystem.Colors.accent.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            onTap()
        }
    }

    private var backgroundColor: Color {
        if isCurrentSegment {
            return DesignSystem.Colors.accentSubtle
        } else if isHovered {
            return DesignSystem.Colors.surfaceHover
        }
        return Color.clear
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Compact Video Player Bar

/// A compact video player control bar (similar to AudioPlayerBar but for video)
struct VideoPlayerBar: View {
    @ObservedObject var videoService: VideoPlayerService

    var body: some View {
        VStack(spacing: 8) {
            // Progress slider
            GeometryReader { geometry in
                let width = geometry.size.width

                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 2)
                        .fill(DesignSystem.Colors.surfaceHover)
                        .frame(height: 4)

                    // Progress
                    RoundedRectangle(cornerRadius: 2)
                        .fill(DesignSystem.Colors.accent)
                        .frame(width: progressWidth(totalWidth: width), height: 4)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let progress = max(0, min(1, value.location.x / width))
                            videoService.seek(to: progress * videoService.duration)
                        }
                )
            }
            .frame(height: 4)

            // Controls
            HStack(spacing: 12) {
                // Play/Pause
                Button {
                    videoService.togglePlayback()
                } label: {
                    Image(systemName: videoService.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(GlassButtonStyle(cornerRadius: 8))

                // Skip back
                Button {
                    videoService.skipBackward(5)
                } label: {
                    Image(systemName: "gobackward.5")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                // Time
                Text(VideoPlayerService.formatTime(videoService.currentTime))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)

                // Progress indicator
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(DesignSystem.Colors.accent)
                    .frame(maxWidth: 100)

                Text(VideoPlayerService.formatTime(videoService.duration))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)

                // Skip forward
                Button {
                    videoService.skipForward(5)
                } label: {
                    Image(systemName: "goforward.5")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Spacer()

                // Speed control
                Menu {
                    ForEach(VideoPlayerService.availableRates, id: \.self) { rate in
                        Button {
                            videoService.playbackRate = rate
                        } label: {
                            HStack {
                                Text(formatRate(rate))
                                if videoService.playbackRate == rate {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Text(formatRate(videoService.playbackRate))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(DesignSystem.Colors.surfaceHover))
                }
                .menuStyle(.borderlessButton)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .glassBackground(cornerRadius: 12, opacity: 0.1)
    }

    private var progress: Double {
        guard videoService.duration > 0 else { return 0 }
        return videoService.currentTime / videoService.duration
    }

    private func progressWidth(totalWidth: CGFloat) -> CGFloat {
        return progress * totalWidth
    }

    private func formatRate(_ rate: Float) -> String {
        if rate == 1.0 {
            return "1x"
        } else if rate == floor(rate) {
            return "\(Int(rate))x"
        } else {
            return String(format: "%.2gx", rate)
        }
    }
}

// MARK: - Preview

#Preview {
    VideoPlayerView(
        videoService: VideoPlayerService(),
        segments: [
            TranscriptionSegment(id: 0, text: "Hello, this is a test segment.", startTime: 0, endTime: 3),
            TranscriptionSegment(id: 1, text: "This is another segment with more text to display.", startTime: 3, endTime: 7),
            TranscriptionSegment(id: 2, text: "And here is a third segment.", startTime: 7, endTime: 10),
        ],
        onSegmentTap: { _ in }
    )
    .frame(width: 800, height: 600)
}
