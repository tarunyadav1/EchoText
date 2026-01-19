import SwiftUI

/// Audio player control bar with playback controls, progress slider, and speed selection
struct AudioPlayerBar: View {
    @ObservedObject var playbackService: AudioPlaybackService
    var onSeekToSegment: ((TimeInterval) -> Void)?

    @State private var isDragging = false
    @State private var dragValue: Double = 0

    var body: some View {
        VStack(spacing: 8) {
            // Progress slider
            progressSlider

            // Controls row
            HStack(spacing: 12) {
                // Current time
                Text(AudioPlaybackService.formatTime(displayTime))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .frame(width: 40, alignment: .trailing)

                Spacer()

                // Playback controls
                playbackControls

                Spacer()

                // Speed picker + Duration
                HStack(spacing: 8) {
                    speedPicker

                    Text(AudioPlaybackService.formatTime(playbackService.duration))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .frame(width: 40, alignment: .leading)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Subviews

    private var progressSlider: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track background
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.primary.opacity(0.08))
                    .frame(height: 3)

                // Progress fill
                RoundedRectangle(cornerRadius: 2)
                    .fill(DesignSystem.Colors.accent)
                    .frame(width: progressWidth(in: geometry.size.width), height: 3)

                // Scrubber handle (visible on hover/drag)
                Circle()
                    .fill(DesignSystem.Colors.accent)
                    .frame(width: 10, height: 10)
                    .offset(x: progressWidth(in: geometry.size.width) - 5)
                    .opacity(isDragging ? 1 : 0)
            }
            .frame(height: 10)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let progress = max(0, min(1, value.location.x / geometry.size.width))
                        dragValue = progress * playbackService.duration
                    }
                    .onEnded { value in
                        let progress = max(0, min(1, value.location.x / geometry.size.width))
                        let seekTime = progress * playbackService.duration
                        playbackService.seek(to: seekTime)
                        isDragging = false
                    }
            )
            .onHover { hovering in
                if !isDragging {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        // Could add hover state here
                    }
                }
            }
        }
        .frame(height: 10)
    }

    private var playbackControls: some View {
        HStack(spacing: 16) {
            // Skip backward
            Button {
                playbackService.skipBackward(5)
            } label: {
                Image(systemName: "gobackward.5")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(PlayerControlButtonStyle())
            .help("Skip back 5 seconds (J)")

            // Play/Pause
            Button {
                playbackService.togglePlayback()
            } label: {
                Image(systemName: playbackService.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(PlayerControlButtonStyle(isPrimary: true))
            .help(playbackService.isPlaying ? "Pause (Space/K)" : "Play (Space/K)")

            // Skip forward
            Button {
                playbackService.skipForward(5)
            } label: {
                Image(systemName: "goforward.5")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(PlayerControlButtonStyle())
            .help("Skip forward 5 seconds (L)")
        }
    }

    private var speedPicker: some View {
        Menu {
            ForEach(AudioPlaybackService.availableRates, id: \.self) { rate in
                Button {
                    playbackService.playbackRate = rate
                } label: {
                    HStack {
                        Text(formatRate(rate))
                        if playbackService.playbackRate == rate {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Text(formatRate(playbackService.playbackRate))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Playback speed ([ / ])")
    }

    // MARK: - Helpers

    private var displayTime: TimeInterval {
        isDragging ? dragValue : playbackService.currentTime
    }

    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        guard playbackService.duration > 0 else { return 0 }
        let progress = displayTime / playbackService.duration
        return totalWidth * CGFloat(progress)
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

// MARK: - Player Control Button Style

struct PlayerControlButtonStyle: ButtonStyle {
    var isPrimary: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isPrimary ? DesignSystem.Colors.accent : DesignSystem.Colors.textSecondary)
            .frame(width: isPrimary ? 36 : 30, height: isPrimary ? 36 : 30)
            .background(
                Circle()
                    .fill(configuration.isPressed ? Color.primary.opacity(0.1) : Color.primary.opacity(0.05))
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Compact Audio Player Bar

/// A more compact version of the audio player for smaller spaces
struct CompactAudioPlayerBar: View {
    @ObservedObject var playbackService: AudioPlaybackService

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Play/Pause
            Button {
                playbackService.togglePlayback()
            } label: {
                Image(systemName: playbackService.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(PlayerControlButtonStyle())

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(DesignSystem.Colors.glassMedium)
                        .frame(height: 3)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(DesignSystem.Colors.accent)
                        .frame(width: progressWidth(in: geometry.size.width), height: 3)
                }
                .frame(height: 3)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            let progress = max(0, min(1, value.location.x / geometry.size.width))
                            playbackService.seek(to: progress * playbackService.duration)
                        }
                )
            }
            .frame(height: 20)

            // Time
            Text("\(AudioPlaybackService.formatTime(playbackService.currentTime)) / \(AudioPlaybackService.formatTime(playbackService.duration))")
                .font(DesignSystem.Typography.monoSmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .fixedSize()
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
    }

    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        guard playbackService.duration > 0 else { return 0 }
        return totalWidth * CGFloat(playbackService.currentTime / playbackService.duration)
    }
}

// MARK: - Preview

#Preview("Audio Player Bar") {
    VStack(spacing: 20) {
        AudioPlayerBar(playbackService: AudioPlaybackService())
            .frame(width: 500)

        CompactAudioPlayerBar(playbackService: AudioPlaybackService())
            .frame(width: 400)
    }
    .padding()
    .frame(width: 600, height: 200)
    .background(Color.gray.opacity(0.2))
}
