import SwiftUI

/// Minimal feedback view for sheet presentation
struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var feedbackService = FeedbackService.shared

    @State private var selectedType: FeedbackType = .general
    @State private var message: String = ""
    @State private var email: String = ""
    @State private var includeSystemInfo: Bool = true
    @State private var showSuccess: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header with glass effect
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Send Feedback")
                        .font(DesignSystem.Typography.title3)
                    Text("Help us improve EchoText")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .liquidGlassCircleInteractive()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider().opacity(0.5)

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Type picker with glass pills
                    feedbackTypePicker

                    // Message with glass container
                    messageSection

                    // Email with glass styling
                    emailSection

                    // System info toggle
                    Toggle(isOn: $includeSystemInfo) {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.secondary)
                            Text("Include system info")
                                .font(DesignSystem.Typography.callout)
                        }
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(DesignSystem.Colors.accent)
                }
                .padding(20)
            }

            Divider().opacity(0.5)

            // Footer with glass buttons
            HStack(spacing: 12) {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(LiquidGlassButtonStyle(style: .secondary))
                    .keyboardShortcut(.escape)

                Button {
                    submitFeedback()
                } label: {
                    HStack(spacing: 6) {
                        if feedbackService.isSubmitting {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        }
                        Text(feedbackService.isSubmitting ? "Sending..." : "Send")
                    }
                }
                .buttonStyle(LiquidGlassButtonStyle(style: .primary))
                .disabled(!canSubmit)
                .keyboardShortcut(.return)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 440, height: 420)
        .background(.ultraThinMaterial)
        .alert("Sent!", isPresented: $showSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("Thanks for your feedback!")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Feedback Type Picker

    private var feedbackTypePicker: some View {
        FlowLayout(spacing: 8) {
            ForEach(FeedbackType.allCases) { type in
                FeedbackTypeButton(
                    type: type,
                    isSelected: selectedType == type
                ) {
                    withAnimation(DesignSystem.Animations.glass) {
                        selectedType = type
                    }
                }
            }
        }
    }

    // MARK: - Message Section

    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $message)
                    .font(DesignSystem.Typography.callout)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 100)

                if message.isEmpty {
                    Text(selectedType.placeholder)
                        .font(DesignSystem.Typography.callout)
                        .foregroundColor(.secondary.opacity(0.6))
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
            .padding(12)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))

            HStack {
                Spacer()
                Text("\(message.count)/2000")
                    .font(DesignSystem.Typography.monoSmall)
                    .foregroundColor(message.count > 2000 ? DesignSystem.Colors.error : .secondary)
            }
        }
    }

    // MARK: - Email Section

    private var emailSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Email (optional)")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(.secondary)

            TextField("your@email.com", text: $email)
                .textFieldStyle(.plain)
                .font(DesignSystem.Typography.callout)
                .padding(12)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        }
    }

    private var canSubmit: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        message.count <= 2000 &&
        !feedbackService.isSubmitting
    }

    private func submitFeedback() {
        Task {
            do {
                _ = try await feedbackService.submitFeedback(
                    type: selectedType,
                    message: message.trimmingCharacters(in: .whitespacesAndNewlines),
                    email: email.isEmpty ? nil : email,
                    includeSystemInfo: includeSystemInfo
                )
                showSuccess = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Embedded Feedback View (for sidebar)

struct EmbeddedFeedbackView: View {
    @StateObject private var feedbackService = FeedbackService.shared

    @State private var selectedType: FeedbackType = .general
    @State private var message: String = ""
    @State private var email: String = ""
    @State private var includeSystemInfo: Bool = true
    @State private var showSuccess: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var isHoveringSubmit: Bool = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack {
                if showSuccess {
                    successView
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9).combined(with: .opacity),
                            removal: .opacity
                        ))
                } else {
                    formView
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: 420)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .animation(.spring(duration: 0.4, bounce: 0.2), value: showSuccess)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 40)

            // Animated checkmark with glass effect
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.success.opacity(0.15))
                    .frame(width: 80, height: 80)

                Circle()
                    .fill(DesignSystem.Colors.success.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DesignSystem.Colors.success, DesignSystem.Colors.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .padding(.bottom, 8)

            Text("Thank You!")
                .font(DesignSystem.Typography.title)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Text("Your feedback helps make EchoText better for everyone.")
                .font(DesignSystem.Typography.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                withAnimation {
                    showSuccess = false
                    message = ""
                    email = ""
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle")
                    Text("Send Another")
                }
                .font(DesignSystem.Typography.captionMedium)
                .foregroundStyle(DesignSystem.Colors.accent)
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
        }
        .padding(24)
    }

    // MARK: - Form View

    private var formView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Send Feedback")
                    .font(DesignSystem.Typography.title2)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                Text("Help us improve EchoText")
                    .font(DesignSystem.Typography.callout)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 4)

            // Type selector with glass pills
            VStack(alignment: .leading, spacing: 10) {
                Text("FEEDBACK TYPE")
                    .sectionHeaderStyle()

                FlowLayout(spacing: 8) {
                    ForEach(FeedbackType.allCases) { type in
                        FeedbackTypeButton(
                            type: type,
                            isSelected: selectedType == type
                        ) {
                            withAnimation(DesignSystem.Animations.glass) {
                                selectedType = type
                            }
                        }
                    }
                }
            }

            // Message with glass container
            VStack(alignment: .leading, spacing: 8) {
                Text("MESSAGE")
                    .sectionHeaderStyle()

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $message)
                        .font(DesignSystem.Typography.callout)
                        .scrollContentBackground(.hidden)
                        .frame(height: 100)

                    if message.isEmpty {
                        Text(selectedType.placeholder)
                            .font(DesignSystem.Typography.callout)
                            .foregroundColor(.secondary.opacity(0.5))
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
                .padding(12)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))

                HStack {
                    Spacer()
                    Text("\(message.count)/2000")
                        .font(DesignSystem.Typography.monoSmall)
                        .foregroundColor(message.count > 2000 ? DesignSystem.Colors.error : DesignSystem.Colors.textTertiary)
                }
            }

            // Email with glass styling
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Text("EMAIL")
                        .sectionHeaderStyle()
                    Text("(optional)")
                        .font(DesignSystem.Typography.micro)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }

                TextField("your@email.com", text: $email)
                    .textFieldStyle(.plain)
                    .font(DesignSystem.Typography.callout)
                    .padding(12)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
            }

            // System info toggle with glass background
            HStack {
                Toggle(isOn: $includeSystemInfo) {
                    HStack(spacing: 8) {
                        Image(systemName: "cpu")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Include system info")
                                .font(DesignSystem.Typography.callout)
                            Text("macOS version, app version")
                                .font(DesignSystem.Typography.micro)
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                        }
                    }
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(DesignSystem.Colors.accent)
            }
            .padding(12)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))

            // Submit button with gradient glass effect
            Button {
                submitFeedback()
            } label: {
                HStack(spacing: 8) {
                    if feedbackService.isSubmitting {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 12))
                    }
                    Text(feedbackService.isSubmitting ? "Sending..." : "Send Feedback")
                        .font(DesignSystem.Typography.bodyMedium)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                        .fill(
                            canSubmit
                                ? DesignSystem.Colors.accentGradient
                                : LinearGradient(colors: [Color.gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
                        )
                )
                .shadow(
                    color: canSubmit ? DesignSystem.Colors.accent.opacity(0.3) : .clear,
                    radius: isHoveringSubmit ? 12 : 6,
                    y: 4
                )
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)
            .onHover { hovering in
                withAnimation(DesignSystem.Animations.quick) {
                    isHoveringSubmit = hovering
                }
            }
            .scaleEffect(isHoveringSubmit && canSubmit ? 1.01 : 1.0)
            .animation(DesignSystem.Animations.glass, value: isHoveringSubmit)
        }
        .padding(24)
    }

    private var canSubmit: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        message.count <= 2000 &&
        !feedbackService.isSubmitting
    }

    private func submitFeedback() {
        Task {
            do {
                _ = try await feedbackService.submitFeedback(
                    type: selectedType,
                    message: message.trimmingCharacters(in: .whitespacesAndNewlines),
                    email: email.isEmpty ? nil : email,
                    includeSystemInfo: includeSystemInfo
                )
                withAnimation {
                    showSuccess = true
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Feedback Type Button

struct FeedbackTypeButton: View {
    let type: FeedbackType
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            Label(type.rawValue, systemImage: type.icon)
                .font(DesignSystem.Typography.captionMedium)
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundColor(isSelected ? .white : DesignSystem.Colors.textPrimary)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(DesignSystem.Colors.accentGradient)
                            .shadow(color: DesignSystem.Colors.accent.opacity(0.3), radius: 4, y: 2)
                    } else {
                        Capsule()
                            .fill(Color.primary.opacity(isHovered ? 0.1 : 0.05))
                    }
                }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(DesignSystem.Animations.quick) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Supporting Views

struct FeedbackButton: View {
    @State private var showFeedback = false

    var body: some View {
        Button { showFeedback = true } label: {
            Label("Send Feedback", systemImage: "bubble.left")
        }
        .sheet(isPresented: $showFeedback) {
            FeedbackView()
        }
    }
}

struct CompactFeedbackButton: View {
    @State private var showFeedback = false
    @State private var isHovered = false

    var body: some View {
        Button { showFeedback = true } label: {
            Image(systemName: "bubble.left")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isHovered ? DesignSystem.Colors.accent : .secondary)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(DesignSystem.Animations.quick) {
                isHovered = hovering
            }
        }
        .help("Send Feedback")
        .sheet(isPresented: $showFeedback) {
            FeedbackView()
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
            totalHeight = currentY + lineHeight
        }

        return (CGSize(width: totalWidth, height: totalHeight), positions)
    }
}

#Preview {
    FeedbackView()
}

#Preview("Embedded") {
    EmbeddedFeedbackView()
        .frame(width: 500, height: 600)
}
