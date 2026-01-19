import SwiftUI

/// URL input section for adding videos from YouTube
struct URLInputSection: View {
    @Binding var urlInput: String
    @Binding var isValidating: Bool
    @Binding var previewMetadata: URLVideoMetadata?
    @Binding var validationError: String?

    let onAdd: () -> Void
    let onValidate: () -> Void

    @State private var isHovered: Bool = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            // URL Input Row
            HStack(spacing: 12) {
                // URL Text Field
                HStack(spacing: 8) {
                    Image(systemName: "link")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)

                    TextField("Paste YouTube URL...", text: $urlInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .focused($isInputFocused)
                        .onSubmit {
                            if !urlInput.isEmpty && previewMetadata == nil && !isValidating {
                                onValidate()
                            } else if previewMetadata != nil {
                                onAdd()
                            }
                        }

                    if !urlInput.isEmpty {
                        Button {
                            urlInput = ""
                            previewMetadata = nil
                            validationError = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .glassBackground(cornerRadius: 10)

                // Paste from Clipboard Button
                Button {
                    if let clipboardString = NSPasteboard.general.string(forType: .string) {
                        urlInput = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
                        // Auto-validate after paste
                        if !urlInput.isEmpty {
                            onValidate()
                        }
                    }
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(GlassButtonStyle())
                .help("Paste from clipboard")

                // Validate/Add Button
                if isValidating {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 70)
                } else if previewMetadata != nil {
                    Button {
                        onAdd()
                    } label: {
                        Label("Add", systemImage: "plus")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(PrimaryGradientButtonStyle())
                } else {
                    Button {
                        onValidate()
                    } label: {
                        Text("Check")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .buttonStyle(GlassButtonStyle())
                    .disabled(urlInput.isEmpty)
                }
            }

            // Preview Card
            if let metadata = previewMetadata {
                URLPreviewCard(metadata: metadata)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
            }

            // Error Message
            if let error = validationError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)

                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)

                    Spacer()
                }
                .padding(12)
                .background(DesignSystem.Colors.warningGlass)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .transition(.opacity)
            }
        }
        .animation(.spring(duration: 0.3), value: previewMetadata != nil)
        .animation(.easeInOut(duration: 0.2), value: validationError != nil)
    }
}

/// Preview card showing video metadata
struct URLPreviewCard: View {
    let metadata: URLVideoMetadata

    @State private var thumbnailImage: NSImage?
    @State private var isLoadingThumbnail = false

    var body: some View {
        HStack(spacing: 16) {
            // Thumbnail
            ZStack {
                if let image = thumbnailImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 68)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(DesignSystem.Colors.surface)
                        .frame(width: 120, height: 68)
                        .overlay {
                            if isLoadingThumbnail {
                                ProgressView()
                                    .scaleEffect(0.6)
                            } else {
                                Image(systemName: "play.rectangle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.secondary)
                            }
                        }
                }

                // Duration badge
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(metadata.formattedDuration)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.75))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(4)
                    }
                }
                .frame(width: 120, height: 68)
            }

            // Info
            VStack(alignment: .leading, spacing: 6) {
                // Platform badge
                if let platform = metadata.platform {
                    HStack(spacing: 4) {
                        Image(systemName: metadata.platformIcon)
                            .font(.system(size: 10))
                        Text(platform)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(Color(hex: metadata.platformColor))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: metadata.platformColor).opacity(0.15))
                    .clipShape(Capsule())
                }

                // Title
                Text(metadata.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)

                // Uploader
                if let uploader = metadata.uploader {
                    Text(uploader)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Checkmark
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.green)
        }
        .padding(12)
        .glassBackground(cornerRadius: 12)
        .task {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        guard let url = metadata.thumbnailURL else { return }

        isLoadingThumbnail = true
        defer { isLoadingThumbnail = false }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = NSImage(data: data) {
                await MainActor.run {
                    thumbnailImage = image
                }
            }
        } catch {
            // Silently fail - we'll show placeholder
        }
    }
}

/// Badge showing platform icon and color for file rows
struct PlatformBadge: View {
    let platform: String?
    let compact: Bool

    init(platform: String?, compact: Bool = false) {
        self.platform = platform
        self.compact = compact
    }

    var body: some View {
        if let platform = platform {
            let metadata = URLVideoMetadata(
                id: "",
                title: "",
                duration: 0,
                thumbnailURL: nil,
                platform: platform,
                originalURL: URL(string: "https://example.com")!,
                uploader: nil,
                uploadDate: nil
            )

            if compact {
                Image(systemName: metadata.platformIcon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(hex: metadata.platformColor))
            } else {
                HStack(spacing: 4) {
                    Image(systemName: metadata.platformIcon)
                        .font(.system(size: 10))
                    Text(platform)
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(Color(hex: metadata.platformColor))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color(hex: metadata.platformColor).opacity(0.12))
                .clipShape(Capsule())
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        URLInputSection(
            urlInput: .constant("https://youtube.com/watch?v=dQw4w9WgXcQ"),
            isValidating: .constant(false),
            previewMetadata: .constant(URLVideoMetadata(
                id: "dQw4w9WgXcQ",
                title: "Rick Astley - Never Gonna Give You Up (Official Music Video)",
                duration: 213,
                thumbnailURL: nil,
                platform: "YouTube",
                originalURL: URL(string: "https://youtube.com/watch?v=dQw4w9WgXcQ")!,
                uploader: "Rick Astley",
                uploadDate: nil
            )),
            validationError: .constant(nil),
            onAdd: {},
            onValidate: {}
        )

        URLInputSection(
            urlInput: .constant(""),
            isValidating: .constant(true),
            previewMetadata: .constant(nil),
            validationError: .constant(nil),
            onAdd: {},
            onValidate: {}
        )

        URLInputSection(
            urlInput: .constant("invalid-url"),
            isValidating: .constant(false),
            previewMetadata: .constant(nil),
            validationError: .constant("This website is not supported for video download."),
            onAdd: {},
            onValidate: {}
        )
    }
    .padding(20)
    .frame(width: 500)
}
