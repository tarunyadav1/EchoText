import Foundation
import SwiftUI

/// Position options for the captions overlay
enum CaptionsPosition: String, Codable, CaseIterable, Identifiable {
    case bottomCenter = "bottom"
    case topCenter = "top"
    case custom = "custom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bottomCenter: return "Bottom Center"
        case .topCenter: return "Top Center"
        case .custom: return "Custom (Draggable)"
        }
    }

    var icon: String {
        switch self {
        case .bottomCenter: return "rectangle.bottomhalf.inset.filled"
        case .topCenter: return "rectangle.tophalf.inset.filled"
        case .custom: return "arrow.up.and.down.and.arrow.left.and.right"
        }
    }
}

/// Settings for Realtime Captions overlay
struct CaptionsSettings: Codable, Equatable {
    /// Whether captions overlay is enabled
    var enabled: Bool = false

    /// Font size for caption text (14-48)
    var fontSize: CGFloat = 24

    /// Position of the captions overlay
    var position: CaptionsPosition = .bottomCenter

    /// Background opacity (0.0-1.0)
    var backgroundOpacity: Double = 0.7

    /// Custom position X offset from center (only used when position is .custom)
    var customOffsetX: CGFloat = 0

    /// Custom position Y offset from bottom (only used when position is .custom)
    var customOffsetY: CGFloat = 100

    /// Number of lines to display (1-5)
    var maxLines: Int = 3

    /// Text color option
    var textColorOption: CaptionsTextColor = .white

    /// Show animation when new words appear
    var animateText: Bool = true

    // MARK: - Font Size Range
    static let minFontSize: CGFloat = 14
    static let maxFontSize: CGFloat = 48

    // MARK: - Line Range
    static let minLines: Int = 1
    static let maxLines: Int = 5
}

/// Text color options for captions
enum CaptionsTextColor: String, Codable, CaseIterable, Identifiable {
    case white = "white"
    case yellow = "yellow"
    case cyan = "cyan"
    case accent = "accent"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .white: return "White"
        case .yellow: return "Yellow"
        case .cyan: return "Cyan"
        case .accent: return "Accent"
        }
    }

    var color: Color {
        switch self {
        case .white: return .white
        case .yellow: return Color(red: 0.95, green: 0.78, blue: 0.47) // F3C677 - Gold Crayola
        case .cyan: return Color(red: 0.49, green: 0.83, blue: 0.99)   // 7DD3FC
        case .accent: return Color(red: 0.98, green: 0.34, blue: 0.31) // F9564F - Tart Orange
        }
    }
}
