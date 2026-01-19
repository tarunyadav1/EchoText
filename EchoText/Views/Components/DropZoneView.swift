import SwiftUI
import UniformTypeIdentifiers
import AppKit

/// Reusable drop zone component with Voice Memos support
/// Supports both direct file drops and file promises (used by Voice Memos)
struct DropZoneView: View {
    // MARK: - Configuration

    /// Supported file types for dropping
    let supportedTypes: [UTType]

    /// Callback when files are dropped
    let onDrop: ([URL]) -> Void

    /// Optional custom title
    var title: String = "Drop your media files"

    /// Optional custom subtitle (if nil, shows supported types)
    var subtitle: String?

    /// Optional custom icon
    var icon: String = "square.and.arrow.down.fill"

    /// Whether to show Voice Memos badge
    var showVoiceMemosBadge: Bool = true

    /// Optional action button title
    var buttonTitle: String?

    /// Optional action button callback
    var onButtonTap: (() -> Void)?

    // MARK: - State

    @State private var isDragging = false
    @State private var pulseAnimation = false

    // Voice Memos drop handler
    private let voiceMemosHandler = VoiceMemosDropHandler()

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background with animated border
            dropBackground

            // Content
            VStack(spacing: 24) {
                // Icon with animation
                iconView

                // Text content
                textContent

                // Voice Memos badge
                if showVoiceMemosBadge {
                    voiceMemosBadge
                }

                // Optional button
                if let buttonTitle = buttonTitle {
                    Button {
                        onButtonTap?()
                    } label: {
                        Text(buttonTitle)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .buttonStyle(PrimaryGradientButtonStyle())
                }
            }
        }
        .frame(maxWidth: 450, maxHeight: 320)
        .animation(DesignSystem.Animations.spring, value: isDragging)
        .onDrop(of: dropTypes, isTargeted: $isDragging) { providers in
            handleDrop(providers: providers)
        }
    }

    // MARK: - Subviews

    private var dropBackground: some View {
        ZStack {
            // Outer glow when dragging
            if isDragging {
                RoundedRectangle(cornerRadius: 24)
                    .fill(DesignSystem.Colors.accent.opacity(0.15))
                    .blur(radius: 20)
                    .scaleEffect(1.05)
            }

            // Main border
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(
                    isDragging ? borderGradientActive : borderGradientInactive,
                    style: StrokeStyle(lineWidth: isDragging ? 3 : 2, dash: [12, 8])
                )

            // Glass background
            RoundedRectangle(cornerRadius: 24)
                .fill(isDragging ? DesignSystem.Colors.accentSubtle : DesignSystem.Colors.glassDark)
        }
    }

    private var borderGradientActive: LinearGradient {
        LinearGradient(
            colors: [DesignSystem.Colors.accent, DesignSystem.Colors.voicePrimary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var borderGradientInactive: LinearGradient {
        LinearGradient(
            colors: [Color.blue.opacity(0.5), Color.purple.opacity(0.5)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var iconView: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(isDragging ? DesignSystem.Colors.accentSubtle : Color.accentColor.opacity(0.1))
                .frame(width: 80, height: 80)
                .scaleEffect(isDragging ? 1.1 : 1.0)

            // Pulse animation when dragging
            if isDragging {
                Circle()
                    .stroke(DesignSystem.Colors.accent.opacity(0.5), lineWidth: 2)
                    .frame(width: 80, height: 80)
                    .scaleEffect(pulseAnimation ? 1.4 : 1.0)
                    .opacity(pulseAnimation ? 0 : 1)
                    .animation(
                        .easeOut(duration: 1.0).repeatForever(autoreverses: false),
                        value: pulseAnimation
                    )
                    .onAppear { pulseAnimation = true }
                    .onDisappear { pulseAnimation = false }
            }

            // Icon
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(isDragging ? DesignSystem.Colors.accent : .accentColor)
                .scaleEffect(isDragging ? 1.2 : 1.0)
        }
    }

    private var textContent: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(isDragging ? DesignSystem.Colors.accent : .primary)

            Text(subtitle ?? supportedTypesDescription)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
    }

    private var voiceMemosBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "waveform")
                .font(.system(size: 12))

            Text("Voice Memos supported")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(DesignSystem.Colors.voicePrimary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(DesignSystem.Colors.voicePrimary.opacity(0.1))
        )
        .opacity(isDragging ? 1.0 : 0.7)
    }

    // MARK: - Helpers

    /// Types to accept for drop operations
    private var dropTypes: [UTType] {
        var types = supportedTypes
        // Add file URL type for file promise support
        if !types.contains(.fileURL) {
            types.append(.fileURL)
        }
        return types
    }

    private var supportedTypesDescription: String {
        let extensions = supportedTypes.compactMap { $0.preferredFilenameExtension?.uppercased() }
        let uniqueExtensions = Array(Set(extensions)).sorted()
        return uniqueExtensions.joined(separator: ", ")
    }

    // MARK: - Drop Handling

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        NSLog("[DropZoneView] Received drop with %d providers", providers.count)

        // Check if this might be from Voice Memos (uses file promises)
        if voiceMemosHandler.containsVoiceMemos(providers) {
            NSLog("[DropZoneView] Detected Voice Memos content, using file promise handler")

            voiceMemosHandler.handleFilePromises(from: providers) { urls in
                let validURLs = urls.filter { self.isValidFileType($0) }
                if !validURLs.isEmpty {
                    NSLog("[DropZoneView] Received %d valid files from Voice Memos", validURLs.count)
                    self.onDrop(validURLs)
                }
            }

            return true
        }

        // Standard file URL drop handling
        var droppedURLs: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                group.enter()

                _ = provider.loadObject(ofClass: URL.self) { url, error in
                    defer { group.leave() }

                    if let error = error {
                        NSLog("[DropZoneView] Error loading URL: %@", error.localizedDescription)
                        return
                    }

                    if let url = url {
                        DispatchQueue.main.async {
                            droppedURLs.append(url)
                        }
                    }
                }
            }
        }

        group.notify(queue: .main) {
            let validURLs = droppedURLs.filter { self.isValidFileType($0) }
            if !validURLs.isEmpty {
                NSLog("[DropZoneView] Received %d valid files", validURLs.count)
                self.onDrop(validURLs)
            }
        }

        return true
    }

    /// Check if a URL has a valid file type
    private func isValidFileType(_ url: URL) -> Bool {
        let pathExtension = url.pathExtension.lowercased()

        // Check against supported extensions
        for type in supportedTypes {
            if let ext = type.preferredFilenameExtension?.lowercased(), ext == pathExtension {
                return true
            }

            // Check common audio/video extensions
            let commonExtensions = ["mp3", "wav", "m4a", "aac", "flac", "ogg", "mp4", "mov", "m4v"]
            if commonExtensions.contains(pathExtension) {
                return true
            }
        }

        return false
    }
}

// MARK: - Specialized Drop Zones

/// Drop zone specifically styled for Voice Memos integration
struct VoiceMemosDropZone: View {
    let onDrop: ([URL]) -> Void
    var onChooseFiles: (() -> Void)?

    var body: some View {
        DropZoneView(
            supportedTypes: [.mp3, .wav, .mpeg4Audio, .audio, .movie],
            onDrop: onDrop,
            title: "Drop your media files",
            subtitle: "MP3, WAV, M4A, MP4, MOV",
            icon: "square.and.arrow.down.fill",
            showVoiceMemosBadge: true,
            buttonTitle: onChooseFiles != nil ? "Choose Files..." : nil,
            onButtonTap: onChooseFiles
        )
    }
}

/// Compact drop zone for sidebar or smaller areas
struct CompactDropZone: View {
    let supportedTypes: [UTType]
    let onDrop: ([URL]) -> Void

    @State private var isDragging = false

    private let voiceMemosHandler = VoiceMemosDropHandler()

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(isDragging ? DesignSystem.Colors.accent : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Drop files here")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isDragging ? DesignSystem.Colors.accent : .primary)

                Text("or drag from Voice Memos")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDragging ? DesignSystem.Colors.accentSubtle : DesignSystem.Colors.glassDark)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            isDragging ? DesignSystem.Colors.accent : Color.clear,
                            lineWidth: 2
                        )
                )
        )
        .animation(DesignSystem.Animations.quick, value: isDragging)
        .onDrop(of: [.fileURL, .audio, .mpeg4Audio], isTargeted: $isDragging) { providers in
            if voiceMemosHandler.containsVoiceMemos(providers) {
                voiceMemosHandler.handleFilePromises(from: providers) { urls in
                    if !urls.isEmpty {
                        onDrop(urls)
                    }
                }
                return true
            }

            // Standard handling
            for provider in providers {
                if provider.canLoadObject(ofClass: URL.self) {
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        if let url = url {
                            DispatchQueue.main.async {
                                onDrop([url])
                            }
                        }
                    }
                }
            }

            return true
        }
    }
}

// MARK: - Preview

#Preview("Standard Drop Zone") {
    DropZoneView(
        supportedTypes: [.mp3, .wav, .mpeg4Audio],
        onDrop: { urls in
            print("Dropped: \(urls)")
        },
        buttonTitle: "Choose Files...",
        onButtonTap: { print("Button tapped") }
    )
    .frame(width: 500, height: 350)
    .padding()
}

#Preview("Voice Memos Drop Zone") {
    VoiceMemosDropZone(
        onDrop: { urls in print("Dropped: \(urls)") },
        onChooseFiles: { print("Choose files") }
    )
    .frame(width: 500, height: 350)
    .padding()
}

#Preview("Compact Drop Zone") {
    CompactDropZone(
        supportedTypes: [.mp3, .wav, .mpeg4Audio],
        onDrop: { urls in print("Dropped: \(urls)") }
    )
    .frame(width: 300)
    .padding()
}
