import Foundation
import SwiftUI

/// Theme options for Focus Mode
enum FocusModeTheme: String, Codable, CaseIterable, Identifiable {
    case midnight    // Dark blue-black (#0C0A3E)
    case charcoal    // Pure dark gray (#1C1C1E)
    case deepPurple  // Brand purple (#2D1B4E)
    case warmNight   // Warm dark (#1A1512)

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .midnight: return "Midnight"
        case .charcoal: return "Charcoal"
        case .deepPurple: return "Deep Purple"
        case .warmNight: return "Warm Night"
        }
    }

    var backgroundColor: Color {
        switch self {
        case .midnight: return Color(hex: "0C0A3E")
        case .charcoal: return Color(hex: "1C1C1E")
        case .deepPurple: return Color(hex: "2D1B4E")
        case .warmNight: return Color(hex: "1A1512")
        }
    }

    var textColor: Color {
        switch self {
        case .midnight: return Color(hex: "E8E6F2")
        case .charcoal: return Color(hex: "F5F5F7")
        case .deepPurple: return Color(hex: "EDE7F6")
        case .warmNight: return Color(hex: "F5E6D3")
        }
    }

    var secondaryTextColor: Color {
        textColor.opacity(0.6)
    }

    var cursorColor: Color {
        switch self {
        case .midnight: return DesignSystem.Colors.accent
        case .charcoal: return Color.white
        case .deepPurple: return DesignSystem.Colors.voicePrimary
        case .warmNight: return DesignSystem.Colors.voiceSecondary
        }
    }
}

/// Font options for Focus Mode
enum FocusModeFont: String, Codable, CaseIterable, Identifiable {
    case system      // SF Pro
    case mono        // SF Mono
    case serif       // New York
    case rounded     // SF Rounded

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "SF Pro"
        case .mono: return "SF Mono"
        case .serif: return "New York"
        case .rounded: return "SF Rounded"
        }
    }

    func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch self {
        case .system:
            return .system(size: size, weight: weight, design: .default)
        case .mono:
            return .system(size: size, weight: weight, design: .monospaced)
        case .serif:
            return .system(size: size, weight: weight, design: .serif)
        case .rounded:
            return .system(size: size, weight: weight, design: .rounded)
        }
    }
}

/// Settings for Focus Mode
struct FocusModeSettings: Codable, Equatable {
    var theme: FocusModeTheme = .midnight
    var font: FocusModeFont = .system
    var fontSize: CGFloat = 24
    var lineHeight: CGFloat = 1.8
    var showWordCount: Bool = true
    var showDuration: Bool = true
    var showHints: Bool = true

    // Font size range
    static let minFontSize: CGFloat = 16
    static let maxFontSize: CGFloat = 48

    // Line height range
    static let minLineHeight: CGFloat = 1.2
    static let maxLineHeight: CGFloat = 2.5
}
