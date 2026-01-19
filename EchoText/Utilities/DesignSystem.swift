import SwiftUI
import AppKit

/// EchoText Design System for macOS 26+ (Tahoe)
/// Combines native Apple Liquid Glass with Murmur-inspired warmth
enum DesignSystem {
    // MARK: - Colors
    enum Colors {
        // Backgrounds - translucent glass (appearance-adaptive)
        static let background = Color(nsColor: .windowBackgroundColor)
        static let backgroundSecondary = Color.clear
        static let backgroundTertiary = Color.clear

        // Glass surfaces (appearance-adaptive)
        static let glassLight = Color.primary.opacity(0.08)
        static let glassMedium = Color.primary.opacity(0.06)
        static let glassDark = Color.primary.opacity(0.04)
        static let glassUltraLight = Color.primary.opacity(0.03)

        // Surfaces - for cards and containers (appearance-adaptive)
        static let surface = Color.primary.opacity(0.05)
        static let surfaceHover = Color.primary.opacity(0.08)
        static let surfaceActive = Color.primary.opacity(0.12)
        static let surfaceGlass = Color.clear

        // Text - system colors for automatic light/dark adaptation
        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary
        static let textTertiary = Color.secondary.opacity(0.7)
        static let textMuted = Color.secondary.opacity(0.5)

        // Accent - Tart Orange (primary brand color)
        static let accent = Color(hex: "F9564F")
        static let accentHover = Color(hex: "E84840")
        static let accentSubtle = Color(hex: "F9564F").opacity(0.1)
        static let accentMuted = Color(hex: "F9564F").opacity(0.06)
        static let accentGlass = Color(hex: "F9564F").opacity(0.15)

        // Voice/Audio accent colors (warm brand palette)
        static let voicePrimary = Color(hex: "B33F62")      // Irresistible - main voice accent
        static let voiceSecondary = Color(hex: "F3C677")    // Gold Crayola - secondary
        static let voiceGlow = Color(hex: "B33F62").opacity(0.4)

        // Brand palette accents
        static let spectralPurple = Color(hex: "7B1E7A")    // Patriarch
        static let spectralPink = Color(hex: "B33F62")      // Irresistible
        static let spectralCyan = Color(hex: "F3C677")      // Gold Crayola

        // Semantic colors using brand palette
        // Success: Gold Crayola (#F3C677)
        static let success = Color(hex: "F3C677")
        static let successGlow = Color(hex: "F3C677").opacity(0.4)
        static let successGlass = Color(hex: "F3C677").opacity(0.12)
        // Warning: Tart Orange (#F9564F) - attention-grabbing
        static let warning = Color(hex: "F9564F")
        static let warningGlow = Color(hex: "F9564F").opacity(0.4)
        static let warningGlass = Color(hex: "F9564F").opacity(0.12)
        // Error: Irresistible (#B33F62) - strong but on-brand
        static let error = Color(hex: "B33F62")
        static let errorGlow = Color(hex: "B33F62").opacity(0.4)
        static let errorGlass = Color(hex: "B33F62").opacity(0.12)
        static let info = Color(hex: "F9564F")

        // Recording - using brand palette (Irresistible for recording, accent for processing)
        static let recordingActive = Color(hex: "B33F62")     // Irresistible - voice/recording
        static let recordingPulse = Color(hex: "B33F62").opacity(0.2)
        static let recordingGlass = Color(hex: "B33F62").opacity(0.1)
        static let recordingGlow = Color(hex: "B33F62").opacity(0.5)
        static let processingActive = Color(hex: "F3C677")    // Gold Crayola
        static let processingGlow = Color(hex: "F3C677").opacity(0.4)

        // Speaker Colors - using brand palette with variations for identification
        static let speakerColors: [Color] = [
            Color(hex: "F9564F"),  // Tart Orange (brand accent)
            Color(hex: "7B1E7A"),  // Patriarch (purple)
            Color(hex: "F3C677"),  // Gold Crayola
            Color(hex: "B33F62"),  // Irresistible
            Color(hex: "0C0A3E"),  // Russian Violet (dark)
            Color(hex: "D85A53"),  // Tart Orange (lighter)
            Color(hex: "9A2E8E"),  // Patriarch (lighter)
            Color(hex: "E6B060"),  // Gold (darker)
            Color(hex: "C75075"),  // Irresistible (lighter)
            Color(hex: "4B1E5F"),  // Russian Violet (lighter)
        ]

        /// Get speaker color by index (cycles through available colors)
        static func speakerColor(at index: Int) -> Color {
            speakerColors[index % speakerColors.count]
        }

        /// Get speaker color with reduced opacity for backgrounds
        static func speakerColorBackground(at index: Int) -> Color {
            speakerColor(at: index).opacity(0.15)
        }

        // Borders - subtle glass edges (appearance-adaptive)
        static let border = Color.primary.opacity(0.08)
        static let borderHover = Color.primary.opacity(0.12)
        static let borderFocus = Color(hex: "F9564F").opacity(0.4)
        static let borderGlass = Color.primary.opacity(0.15)

        // Gradients - warm brand palette
        static let warmGradient = LinearGradient(
            colors: [Color(hex: "F9564F"), Color(hex: "F3C677")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let softAccent = LinearGradient(
            colors: [Color(hex: "B33F62").opacity(0.1), Color(hex: "F9564F").opacity(0.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let accentGradient = LinearGradient(
            colors: [Color(hex: "F9564F"), Color(hex: "B33F62")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let spectralGradient = LinearGradient(
            colors: [
                Color(hex: "F9564F").opacity(0.6),
                Color(hex: "B33F62").opacity(0.4),
                Color(hex: "7B1E7A").opacity(0.3)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let glassGradient = LinearGradient(
            colors: [
                Color.primary.opacity(0.08),
                Color.primary.opacity(0.04)
            ],
            startPoint: .top,
            endPoint: .bottom
        )

        static let recordingGradient = LinearGradient(
            colors: [Color(hex: "B33F62"), Color(hex: "D05A7A")],
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

    // MARK: - Corner Radius (larger for Liquid Glass)
    enum CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let extraLarge: CGFloat = 20
        static let pill: CGFloat = 999
    }

    // MARK: - Shadows (softer for glass effect)
    enum Shadows {
        static let subtle = Color.black.opacity(0.05)
        static let medium = Color.black.opacity(0.1)
        static let strong = Color.black.opacity(0.15)
        static let glow = Colors.accent.opacity(0.2)
        static let glass = Color.black.opacity(0.04)
    }

    // MARK: - Animations (Enhanced with Murmur patterns)
    enum Animations {
        // Quick interactions
        static let quick = Animation.spring(duration: 0.2, bounce: 0.2)
        static let standard = Animation.easeInOut(duration: 0.25)
        static let smooth = Animation.easeInOut(duration: 0.3)
        static let slow = Animation.easeInOut(duration: 0.4)

        // Button interactions
        static let buttonPress = Animation.spring(duration: 0.15, bounce: 0.3)
        static let buttonRelease = Animation.spring(duration: 0.3, bounce: 0.4)

        // Panel transitions
        static let panelSlide = Animation.spring(duration: 0.4, bounce: 0.2)
        static let panelFade = Animation.easeOut(duration: 0.25)

        // Spring variations
        static let spring = Animation.spring(response: 0.35, dampingFraction: 0.7)
        static let springBouncy = Animation.spring(response: 0.4, dampingFraction: 0.6)
        static let glass = Animation.spring(response: 0.3, dampingFraction: 0.8)

        // Ambient/breathing animations
        static let breathing = Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)
        static let pulse = Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)
        static let gentlePulse = Animation.easeInOut(duration: 0.7).repeatForever(autoreverses: true)

        // Toast animations
        static let toastIn = Animation.spring(duration: 0.5, bounce: 0.3)
        static let toastOut = Animation.easeIn(duration: 0.25)
    }

    // MARK: - Typography
    enum Typography {
        // Display - for hero text and large headings
        static let displayLarge = Font.system(size: 32, weight: .semibold, design: .rounded)
        static let displayMedium = Font.system(size: 26, weight: .semibold, design: .rounded)

        // Titles - for section headings
        static let title = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let title2 = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let title3 = Font.system(size: 15, weight: .semibold, design: .rounded)

        // Headlines - for card headers and labels
        static let headline = Font.system(size: 14, weight: .semibold, design: .rounded)
        static let headlineMedium = Font.system(size: 14, weight: .medium, design: .rounded)

        // Section headers - for form sections (e.g., "Required", "Recommended")
        static let sectionHeader = Font.system(size: 11, weight: .semibold, design: .rounded)

        // Body - for main content
        static let body = Font.system(size: 14, weight: .regular)
        static let bodyMedium = Font.system(size: 14, weight: .medium)
        static let bodySemibold = Font.system(size: 14, weight: .semibold)

        // Callout - for secondary descriptions
        static let callout = Font.system(size: 13, weight: .regular)
        static let calloutMedium = Font.system(size: 13, weight: .medium)

        // Caption - for tertiary info and labels
        static let caption = Font.system(size: 12, weight: .regular)
        static let captionMedium = Font.system(size: 12, weight: .medium)
        static let captionSemibold = Font.system(size: 12, weight: .semibold)

        // Micro - for very small labels
        static let micro = Font.system(size: 10, weight: .medium)

        // Monospaced - for code and shortcuts
        static let mono = Font.system(size: 13, weight: .medium, design: .monospaced)
        static let monoLarge = Font.system(size: 16, weight: .semibold, design: .monospaced)
        static let monoSmall = Font.system(size: 11, weight: .medium, design: .monospaced)
    }

    // MARK: - Line Spacing
    enum LineSpacing {
        static let tight: CGFloat = 2
        static let normal: CGFloat = 4
        static let relaxed: CGFloat = 6
        static let loose: CGFloat = 8
    }

    // MARK: - Glass Materials
    enum Materials {
        static let ultraThin = Material.ultraThinMaterial
        static let thin = Material.thinMaterial
        static let regular = Material.regularMaterial
        static let thick = Material.thickMaterial
        static let ultraThick = Material.ultraThickMaterial
    }
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Visual Effects for Liquid Glass

/// Custom NSVisualEffectView subclass that passes through mouse events
class PassthroughVisualEffectView: NSVisualEffectView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        // Return nil to pass through all mouse events to views behind
        return nil
    }
}

struct GlassBackgroundView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    init(material: NSVisualEffectView.Material = .hudWindow, blendingMode: NSVisualEffectView.BlendingMode = .behindWindow) {
        self.material = material
        self.blendingMode = blendingMode
    }

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = PassthroughVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

struct DarkVisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Native Liquid Glass Button Styles (macOS 26+)

/// Primary Liquid Glass button style using native glassEffect
struct LiquidGlassButtonStyle: ButtonStyle {
    var style: ButtonVariant = .primary

    enum ButtonVariant {
        case primary, secondary, ghost, danger
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.bodyMedium)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .foregroundColor(foregroundColor)
            .modifier(GlassButtonBackground(style: style, isPressed: configuration.isPressed))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(DesignSystem.Animations.glass, value: configuration.isPressed)
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary, .ghost:
            return DesignSystem.Colors.textPrimary
        case .danger:
            return .white
        }
    }
}

/// Background modifier for glass buttons
struct GlassButtonBackground: ViewModifier {
    let style: LiquidGlassButtonStyle.ButtonVariant
    let isPressed: Bool

    func body(content: Content) -> some View {
        switch style {
        case .primary:
            content
                .background(isPressed ? DesignSystem.Colors.accentHover : DesignSystem.Colors.accent)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        case .secondary:
            content
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        case .ghost:
            content
                .background(isPressed ? DesignSystem.Colors.surfaceActive : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        case .danger:
            content
                .glassEffect(.regular.tint(DesignSystem.Colors.error).interactive(), in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        }
    }
}

struct WisprButtonStyle: ButtonStyle {
    var style: ButtonVariant = .secondary

    enum ButtonVariant {
        case primary, secondary, ghost, danger
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.bodyMedium)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(backgroundColor(isPressed: configuration.isPressed))
            .foregroundColor(foregroundColor)
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(DesignSystem.Animations.quick, value: configuration.isPressed)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        switch style {
        case .primary:
            return isPressed ? DesignSystem.Colors.accentHover : DesignSystem.Colors.accent
        case .secondary:
            return isPressed ? DesignSystem.Colors.surfaceActive : DesignSystem.Colors.surfaceHover
        case .ghost:
            return isPressed ? DesignSystem.Colors.surfaceActive : Color.clear
        case .danger:
            return isPressed ? DesignSystem.Colors.error.opacity(0.8) : DesignSystem.Colors.error
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary, .danger:
            return .white
        case .secondary, .ghost:
            return DesignSystem.Colors.textPrimary
        }
    }
}

/// Liquid Glass icon button style
struct WisprIconButtonStyle: ButtonStyle {
    var size: CGFloat = 32
    var isActive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.38, weight: .medium))
            .frame(width: size, height: size)
            .foregroundColor(isActive ? .white : DesignSystem.Colors.textSecondary)
            .modifier(IconButtonBackground(isActive: isActive, isPressed: configuration.isPressed))
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(DesignSystem.Animations.quick, value: configuration.isPressed)
    }
}

struct IconButtonBackground: ViewModifier {
    let isActive: Bool
    let isPressed: Bool

    func body(content: Content) -> some View {
        if isActive {
            content
                .glassEffect(.regular.tint(DesignSystem.Colors.accent).interactive(), in: .circle)
        } else {
            content
                .glassEffect(.regular.interactive(), in: .circle)
        }
    }
}

/// Native Liquid Glass button style
struct GlassButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 12

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.bodyMedium)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .foregroundColor(DesignSystem.Colors.textPrimary)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.15 : 0.08))
            )
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(DesignSystem.Animations.glass, value: configuration.isPressed)
    }
}

struct PrimaryGradientButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 12

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.bodyMedium)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(DesignSystem.Colors.accentGradient)
            )
            .foregroundColor(.white)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(DesignSystem.Animations.glass, value: configuration.isPressed)
    }
}

// MARK: - Sidebar Item Style
struct SidebarItemModifier: ViewModifier {
    var isSelected: Bool
    @State private var isHovered: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .fill(backgroundColor)
            )
            .foregroundColor(isSelected ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
            .contentShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
            .onHover { hovering in
                withAnimation(DesignSystem.Animations.quick) {
                    isHovered = hovering
                }
            }
    }

    private var backgroundColor: Color {
        if isSelected {
            return DesignSystem.Colors.accentSubtle
        } else if isHovered {
            return DesignSystem.Colors.surfaceHover
        }
        return Color.clear
    }
}

// MARK: - Native Liquid Glass View Extensions (macOS 26+)

extension View {
    /// Native Liquid Glass card - the primary container style
    func liquidGlassCard(cornerRadius: CGFloat = DesignSystem.CornerRadius.large) -> some View {
        self
            .padding(DesignSystem.Spacing.lg)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
    }

    /// Interactive Liquid Glass card with press effects
    func liquidGlassCardInteractive(cornerRadius: CGFloat = DesignSystem.CornerRadius.large) -> some View {
        self
            .padding(DesignSystem.Spacing.lg)
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: cornerRadius))
    }

    /// Tinted Liquid Glass card
    func liquidGlassTinted(_ color: Color, cornerRadius: CGFloat = DesignSystem.CornerRadius.large) -> some View {
        self
            .padding(DesignSystem.Spacing.lg)
            .glassEffect(.regular.tint(color), in: RoundedRectangle(cornerRadius: cornerRadius))
    }

    /// Clear Liquid Glass for high transparency
    func liquidGlassClear(cornerRadius: CGFloat = DesignSystem.CornerRadius.large) -> some View {
        self
            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: cornerRadius))
    }

    /// Liquid Glass pill/capsule shape
    func liquidGlassPill() -> some View {
        self
            .glassEffect(.regular, in: .capsule)
    }

    /// Interactive Liquid Glass pill
    func liquidGlassPillInteractive() -> some View {
        self
            .glassEffect(.regular.interactive(), in: .capsule)
    }

    /// Liquid Glass circle
    func liquidGlassCircle() -> some View {
        self
            .glassEffect(.regular, in: .circle)
    }

    /// Interactive Liquid Glass circle button
    func liquidGlassCircleInteractive() -> some View {
        self
            .glassEffect(.regular.interactive(), in: .circle)
    }

    /// Legacy glass card - fallback using material
    func glassCard(cornerRadius: CGFloat = DesignSystem.CornerRadius.large) -> some View {
        self
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
    }

    /// Solid card for content areas - now uses glass effect
    func solidCard(cornerRadius: CGFloat = DesignSystem.CornerRadius.large) -> some View {
        self
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: DesignSystem.Shadows.subtle, radius: 8, y: 2)
    }

    func wisprCard() -> some View {
        self
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
            .shadow(color: DesignSystem.Shadows.subtle, radius: 6, y: 2)
    }

    func wisprBackground() -> some View {
        self.background(DesignSystem.Colors.background)
    }

    func sidebarItemStyle(isSelected: Bool) -> some View {
        self.modifier(SidebarItemModifier(isSelected: isSelected))
    }

    func glassBackground(cornerRadius: CGFloat = 12, opacity: Double = 0.05) -> some View {
        self
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
    }

    func cardStyle() -> some View {
        self
            .padding(DesignSystem.Spacing.lg)
            .wisprCard()
    }

    /// Floating window style with native Liquid Glass
    func floatingWindowStyle() -> some View {
        self
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.extraLarge))
            .shadow(color: DesignSystem.Shadows.medium, radius: 24, y: 8)
    }

    func standardPadding() -> some View {
        self.padding(DesignSystem.Spacing.lg)
    }

    /// Glass morphism border effect (appearance-adaptive)
    func glassBorder(cornerRadius: CGFloat = DesignSystem.CornerRadius.large) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.primary.opacity(0.15),
                            Color.primary.opacity(0.08),
                            Color.primary.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    /// Description text style with relaxed line spacing
    func descriptionStyle() -> some View {
        self
            .font(.system(size: 13))
            .foregroundColor(DesignSystem.Colors.textSecondary)
            .lineSpacing(DesignSystem.LineSpacing.normal)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Secondary description with tighter spacing
    func secondaryDescriptionStyle() -> some View {
        self
            .font(.system(size: 12))
            .foregroundColor(DesignSystem.Colors.textTertiary)
            .lineSpacing(DesignSystem.LineSpacing.tight)
    }

    /// Section header style (e.g., "REQUIRED", "RECOMMENDED")
    func sectionHeaderStyle() -> some View {
        self
            .font(DesignSystem.Typography.sectionHeader)
            .foregroundColor(DesignSystem.Colors.textTertiary)
            .tracking(0.5)
            .textCase(.uppercase)
    }

    /// Background extension for navigation
    func backgroundExtensionEffect(_ status: GlassEffectStatus = .enabled) -> some View {
        self.modifier(BackgroundExtensionModifier(status: status))
    }
}

enum GlassEffectStatus {
    case enabled, disabled
}

struct BackgroundExtensionModifier: ViewModifier {
    let status: GlassEffectStatus
    func body(content: Content) -> some View {
        content // Simplified for simulated environment
    }
}

/// A container that shares glass sampling across multiple elements
struct EchoGlassEffectContainer<Content: View>: View {
    let spacing: CGFloat
    let content: Content

    init(spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        VStack(spacing: spacing) {
            content
        }
        .glassEffect()
    }
}

// MARK: - Hover Card Modifier

struct HoverCardModifier: ViewModifier {
    @State private var isHovered = false
    var cornerRadius: CGFloat = DesignSystem.CornerRadius.large

    func body(content: Content) -> some View {
        content
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(isHovered ? DesignSystem.Colors.accent.opacity(0.2) : Color.clear, lineWidth: 1)
            )
            .shadow(
                color: isHovered ? DesignSystem.Shadows.medium : DesignSystem.Shadows.subtle,
                radius: isHovered ? 16 : 10,
                y: isHovered ? 6 : 4
            )
            .scaleEffect(isHovered ? 1.005 : 1.0)
            .animation(DesignSystem.Animations.quick, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// MARK: - Hover Row Modifier

struct HoverRowModifier: ViewModifier {
    @State private var isHovered = false
    var cornerRadius: CGFloat = DesignSystem.CornerRadius.medium

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(isHovered ? Color.primary.opacity(0.05) : Color.clear)
            )
            .animation(DesignSystem.Animations.quick, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// MARK: - Interactive Button Modifier

struct InteractiveModifier: ViewModifier {
    @State private var isHovered = false
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .brightness(isHovered ? 0.03 : 0)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(DesignSystem.Animations.quick, value: isHovered)
            .animation(DesignSystem.Animations.quick, value: isPressed)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// MARK: - Polish View Extensions

extension View {
    /// Card with hover lift effect
    func hoverCard(cornerRadius: CGFloat = DesignSystem.CornerRadius.large) -> some View {
        self.modifier(HoverCardModifier(cornerRadius: cornerRadius))
    }

    /// Row with hover background
    func hoverRow(cornerRadius: CGFloat = DesignSystem.CornerRadius.medium) -> some View {
        self.modifier(HoverRowModifier(cornerRadius: cornerRadius))
    }

    /// Interactive element with hover/press states
    func interactive() -> some View {
        self.modifier(InteractiveModifier())
    }

    /// Subtle inner shadow for depth
    func innerShadow(cornerRadius: CGFloat = DesignSystem.CornerRadius.large) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
                .blur(radius: 1)
                .offset(y: 1)
                .mask(RoundedRectangle(cornerRadius: cornerRadius))
        )
    }

    /// Gradient background overlay
    func subtleGradientBackground() -> some View {
        self.background(
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .windowBackgroundColor).opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - Legacy Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.bodyMedium)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(DesignSystem.Colors.accent)
            .foregroundColor(.white)
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.bodyMedium)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(.ultraThinMaterial)
            .foregroundColor(DesignSystem.Colors.textPrimary)
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}

struct RecordButtonStyle: ButtonStyle {
    let isRecording: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 60, height: 60)
            .background(
                Circle()
                    .fill(isRecording ? DesignSystem.Colors.recordingActive : DesignSystem.Colors.accent)
            )
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(DesignSystem.Animations.spring, value: configuration.isPressed)
    }
}

// MARK: - Murmur-Inspired View Modifiers

extension View {
    /// Animated button press effect
    func pressable(isPressed: Bool) -> some View {
        self.scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(isPressed ? DesignSystem.Animations.buttonPress : DesignSystem.Animations.buttonRelease, value: isPressed)
    }

    /// Soft glow effect for interactive elements
    func softGlow(_ color: Color, radius: CGFloat = 8, isActive: Bool = true) -> some View {
        self.shadow(color: isActive ? color.opacity(0.4) : .clear, radius: radius, y: 0)
    }

    /// Card style with material background and subtle border (Murmur-inspired)
    func murmurCard(cornerRadius: CGFloat = DesignSystem.CornerRadius.medium) -> some View {
        self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
    }

    /// Breathing animation for ambient effects
    func breathing(isActive: Bool = true) -> some View {
        self.modifier(BreathingModifier(isActive: isActive))
    }

    /// Shimmer effect for loading states
    func shimmer(isActive: Bool = true) -> some View {
        self.modifier(ShimmerModifier(isActive: isActive))
    }
}

// MARK: - Breathing Modifier

struct BreathingModifier: ViewModifier {
    let isActive: Bool
    @State private var scale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                if isActive {
                    withAnimation(DesignSystem.Animations.breathing) {
                        scale = 1.02
                    }
                }
            }
            .onChange(of: isActive) { _, active in
                if active {
                    withAnimation(DesignSystem.Animations.breathing) {
                        scale = 1.02
                    }
                } else {
                    withAnimation(DesignSystem.Animations.quick) {
                        scale = 1.0
                    }
                }
            }
    }
}

// MARK: - Shimmer Modifier

struct ShimmerModifier: ViewModifier {
    let isActive: Bool
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                if isActive {
                    GeometryReader { geometry in
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.2), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geometry.size.width * 0.5)
                        .offset(x: phase * geometry.size.width * 1.5 - geometry.size.width * 0.25)
                        .blendMode(.overlay)
                    }
                    .mask(content)
                    .onAppear {
                        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                            phase = 1
                        }
                    }
                }
            }
    }
}

// MARK: - Keyboard Shortcut Hint

struct KeyboardHint: View {
    let keys: String

    var body: some View {
        Text(keys)
            .font(.caption2)
            .fontWeight(.medium)
            .fontDesign(.monospaced)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Murmur-Inspired Button Styles

struct EchoButtonStyle: ButtonStyle {
    let variant: Variant

    enum Variant {
        case primary
        case secondary
        case ghost
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background {
                switch variant {
                case .primary:
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                        .fill(DesignSystem.Colors.accentGradient)
                case .secondary:
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                        .fill(.regularMaterial)
                case .ghost:
                    Color.clear
                }
            }
            .foregroundStyle(variant == .primary ? .white : .primary)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(DesignSystem.Animations.buttonPress, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == EchoButtonStyle {
    static var echoPrimary: EchoButtonStyle { EchoButtonStyle(variant: .primary) }
    static var echoSecondary: EchoButtonStyle { EchoButtonStyle(variant: .secondary) }
    static var echoGhost: EchoButtonStyle { EchoButtonStyle(variant: .ghost) }
}

// MARK: - Glass Effect Container (macOS 26+)

/// Container that provides a glass effect background for its content
struct GlassEffectContainer<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
    }
}
