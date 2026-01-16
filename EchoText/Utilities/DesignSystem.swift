import SwiftUI

/// Design system with colors, spacing, and animations
enum DesignSystem {
    // MARK: - Colors
    enum Colors {
        // Primary brand colors
        static let primary = Color.accentColor
        static let secondary = Color.secondary

        // Semantic colors
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let info = Color.blue

        // Recording states
        static let recordingActive = Color.red
        static let recordingIdle = Color.secondary
        static let processingActive = Color.orange

        // Background colors
        static let windowBackground = Color(NSColor.windowBackgroundColor)
        static let controlBackground = Color(NSColor.controlBackgroundColor)
        static let textBackground = Color(NSColor.textBackgroundColor)

        // Gradients
        static let brandGradient = LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let recordingGradient = LinearGradient(
            colors: [.red, .orange],
            startPoint: .bottom,
            endPoint: .top
        )
    }

    // MARK: - Spacing
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }

    // MARK: - Corner Radius
    enum CornerRadius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
        static let extraLarge: CGFloat = 16
        static let pill: CGFloat = 999
    }

    // MARK: - Shadows
    enum Shadows {
        static func small(color: Color = .black.opacity(0.1)) -> some View {
            EmptyView().shadow(color: color, radius: 4, y: 2)
        }

        static func medium(color: Color = .black.opacity(0.15)) -> some View {
            EmptyView().shadow(color: color, radius: 8, y: 4)
        }

        static func large(color: Color = .black.opacity(0.2)) -> some View {
            EmptyView().shadow(color: color, radius: 16, y: 8)
        }
    }

    // MARK: - Animations
    enum Animations {
        static let quick = Animation.easeInOut(duration: 0.15)
        static let standard = Animation.easeInOut(duration: 0.25)
        static let slow = Animation.easeInOut(duration: 0.4)

        static let spring = Animation.spring(response: 0.3, dampingFraction: 0.7)
        static let springBouncy = Animation.spring(response: 0.3, dampingFraction: 0.5)

        static let pulse = Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true)
    }

    // MARK: - Typography
    enum Typography {
        static let largeTitle = Font.largeTitle.weight(.bold)
        static let title = Font.title.weight(.semibold)
        static let title2 = Font.title2.weight(.semibold)
        static let title3 = Font.title3.weight(.medium)
        static let headline = Font.headline
        static let body = Font.body
        static let callout = Font.callout
        static let caption = Font.caption
        static let caption2 = Font.caption2

        static let monospaced = Font.system(.body, design: .monospaced)
        static let monospacedCaption = Font.system(.caption, design: .monospaced)
    }
}

// MARK: - View Modifiers
extension View {
    func cardStyle() -> some View {
        self
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.controlBackground)
            .cornerRadius(DesignSystem.CornerRadius.large)
    }

    func floatingWindowStyle() -> some View {
        self
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.extraLarge))
            .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
    }

    func standardPadding() -> some View {
        self.padding(DesignSystem.Spacing.lg)
    }
}

// MARK: - Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(DesignSystem.Colors.primary)
            .foregroundColor(.white)
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(DesignSystem.Colors.controlBackground)
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct RecordButtonStyle: ButtonStyle {
    let isRecording: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 64, height: 64)
            .background(isRecording ? DesignSystem.Colors.recordingActive : DesignSystem.Colors.primary)
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(DesignSystem.Animations.quick, value: configuration.isPressed)
    }
}
