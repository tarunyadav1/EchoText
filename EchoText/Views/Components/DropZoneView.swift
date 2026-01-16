import SwiftUI
import UniformTypeIdentifiers

/// Reusable drop zone for file uploads
struct DropZoneView: View {
    let supportedTypes: [UTType]
    let onDrop: ([URL]) -> Void

    @State private var isDragging = false

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 2, dash: [10])
                )
                .foregroundColor(isDragging ? .accentColor : .secondary.opacity(0.5))
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                        .fill(isDragging ? Color.accentColor.opacity(0.1) : Color.clear)
                )

            // Content
            VStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 48))
                    .foregroundColor(isDragging ? .accentColor : .secondary)

                VStack(spacing: DesignSystem.Spacing.xs) {
                    Text("Drop files here")
                        .font(.headline)

                    Text(supportedTypesDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(DesignSystem.Spacing.xl)
        }
        .animation(DesignSystem.Animations.quick, value: isDragging)
        .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
            handleDrop(providers: providers)
        }
    }

    private var supportedTypesDescription: String {
        let extensions = supportedTypes.compactMap { $0.preferredFilenameExtension?.uppercased() }
        return "Supports: " + extensions.joined(separator: ", ")
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []

        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url = url {
                        DispatchQueue.main.async {
                            urls.append(url)
                            if urls.count == providers.count {
                                onDrop(urls)
                            }
                        }
                    }
                }
            }
        }

        return true
    }
}

// MARK: - Preview
#Preview {
    DropZoneView(
        supportedTypes: [.mp3, .wav, .mpeg4Audio],
        onDrop: { urls in
            print("Dropped: \(urls)")
        }
    )
    .frame(width: 400, height: 250)
    .padding()
}
