import SwiftUI

/// A picker component for selecting system audio sources
struct AudioSourcePicker: View {
    @ObservedObject var systemAudioService: SystemAudioService
    @State private var isRefreshing = false
    @State private var showMeetingAppsOnly = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Label("Audio Source", systemImage: "speaker.wave.2.fill")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    Task {
                        isRefreshing = true
                        try? await systemAudioService.refreshSources()
                        isRefreshing = false
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                        .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                }
                .buttonStyle(.borderless)
                .help("Refresh audio sources")
            }

            // Meeting apps filter toggle
            if !systemAudioService.detectedMeetingApps.isEmpty {
                Toggle(isOn: $showMeetingAppsOnly) {
                    HStack(spacing: 4) {
                        Image(systemName: "video.fill")
                        Text("Show meeting apps only")
                    }
                    .font(.caption)
                }
                .toggleStyle(.checkbox)
            }

            // Detected meeting apps banner
            if !systemAudioService.detectedMeetingApps.isEmpty && !showMeetingAppsOnly {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(DesignSystem.Colors.accent)

                    Text("Detected: \(systemAudioService.detectedMeetingApps.map(\.name).joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Source list
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filteredSources) { source in
                        AudioSourceRow(
                            source: source,
                            isSelected: systemAudioService.selectedSource?.id == source.id,
                            isMeetingApp: systemAudioService.detectedMeetingApps.contains(source)
                        ) {
                            systemAudioService.selectedSource = source
                        }
                    }
                }
            }
            .frame(maxHeight: 200)

            // Permission status
            if !systemAudioService.hasPermission {
                PermissionBanner()
            }
        }
    }

    private var filteredSources: [AudioSource] {
        if showMeetingAppsOnly {
            // Always show system audio option + meeting apps
            return systemAudioService.availableSources.filter {
                $0.type == .systemAudio || systemAudioService.detectedMeetingApps.contains($0)
            }
        }
        return systemAudioService.availableSources
    }
}

/// A row representing a single audio source
private struct AudioSourceRow: View {
    let source: AudioSource
    let isSelected: Bool
    let isMeetingApp: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Icon
                if let icon = source.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: iconName)
                        .frame(width: 24, height: 24)
                        .foregroundStyle(source.type == .systemAudio ? DesignSystem.Colors.accent : .secondary)
                }

                // Name
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(source.name)
                            .font(.body)
                            .foregroundStyle(.primary)

                        if isMeetingApp {
                            Image(systemName: "video.fill")
                                .font(.caption2)
                                .foregroundStyle(DesignSystem.Colors.accent)
                        }
                    }

                    if source.type == .systemAudio {
                        Text("Captures all system audio")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DesignSystem.Colors.accent)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? DesignSystem.Colors.accent.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var iconName: String {
        switch source.type {
        case .systemAudio:
            return "speaker.wave.3.fill"
        case .application:
            return "app.fill"
        case .display:
            return "display"
        }
    }
}

/// Banner shown when screen recording permission is not granted
private struct PermissionBanner: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Screen Recording Permission Required")
                    .font(.caption)
                    .fontWeight(.medium)

                Text("Enable in System Settings → Privacy & Security → Screen Recording")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Open Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .background(.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    AudioSourcePicker(systemAudioService: SystemAudioService())
        .frame(width: 400)
        .padding()
}
