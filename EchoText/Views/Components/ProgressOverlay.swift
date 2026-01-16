import SwiftUI

/// Full-screen progress overlay for long operations
struct ProgressOverlay: View {
    let title: String
    let message: String?
    let progress: Double?
    let showSpinner: Bool
    let onCancel: (() -> Void)?

    init(
        title: String,
        message: String? = nil,
        progress: Double? = nil,
        showSpinner: Bool = true,
        onCancel: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.progress = progress
        self.showSpinner = showSpinner
        self.onCancel = onCancel
    }

    var body: some View {
        ZStack {
            // Background blur
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            // Content card
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Spinner or progress
                if let progress = progress {
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 4)
                            .frame(width: 60, height: 60)

                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-90))

                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                } else if showSpinner {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(width: 60, height: 60)
                }

                // Text content
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Text(title)
                        .font(.headline)

                    if let message = message {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }

                // Cancel button
                if let onCancel = onCancel {
                    Button("Cancel") {
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(DesignSystem.Spacing.xxl)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                    .fill(DesignSystem.Colors.controlBackground)
                    .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
            )
        }
    }
}

// MARK: - View Extension
extension View {
    func progressOverlay(
        isPresented: Bool,
        title: String,
        message: String? = nil,
        progress: Double? = nil,
        onCancel: (() -> Void)? = nil
    ) -> some View {
        ZStack {
            self

            if isPresented {
                ProgressOverlay(
                    title: title,
                    message: message,
                    progress: progress,
                    onCancel: onCancel
                )
                .transition(.opacity)
            }
        }
        .animation(DesignSystem.Animations.standard, value: isPresented)
    }
}

// MARK: - Loading States
struct LoadingState<T> {
    enum Status {
        case idle
        case loading
        case loaded(T)
        case failed(Error)
    }

    var status: Status = .idle

    var isLoading: Bool {
        if case .loading = status {
            return true
        }
        return false
    }

    var value: T? {
        if case .loaded(let value) = status {
            return value
        }
        return nil
    }

    var error: Error? {
        if case .failed(let error) = status {
            return error
        }
        return nil
    }
}

// MARK: - Preview
#Preview("Progress Overlay") {
    VStack {
        Text("Background Content")
    }
    .frame(width: 400, height: 300)
    .progressOverlay(
        isPresented: true,
        title: "Downloading Model",
        message: "Please wait while we download the speech recognition model...",
        progress: 0.65,
        onCancel: {}
    )
}

#Preview("Spinner Overlay") {
    VStack {
        Text("Background Content")
    }
    .frame(width: 400, height: 300)
    .progressOverlay(
        isPresented: true,
        title: "Processing...",
        message: "Transcribing your audio"
    )
}
