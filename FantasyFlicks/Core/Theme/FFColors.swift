//
//  FFColors.swift
//  FantasyFlicks
//
//  Fantasy Flicks Color System
//  Extracted from the app icon's gold film strip, crown, and ruby gem aesthetic
//

import SwiftUI

/// Fantasy Flicks color palette - matches the premium gold and ruby app icon theme
public struct FFColors {

    // MARK: - Gold Palette (Primary Brand Colors)

    /// Main accent color - rich metallic gold
    /// Use for: Primary buttons, highlights, important UI elements
    public static let goldPrimary = Color(hex: "D4A636")

    /// Lighter gold for gradients and secondary highlights
    /// Use for: Gradient tops, hover states, secondary accents
    public static let goldLight = Color(hex: "E8C55A")

    /// Darker gold for shadows and depth
    /// Use for: Pressed states, shadows, depth effects
    public static let goldDark = Color(hex: "A67C22")

    // MARK: - Ruby Accent

    /// Ruby red accent - the gem from the crown
    /// Use for: Alerts, badges, special highlights, live indicators
    public static let ruby = Color(hex: "C41E3A")

    /// Lighter ruby for gradients
    public static let rubyLight = Color(hex: "E63950")

    /// Darker ruby for pressed states
    public static let rubyDark = Color(hex: "9A1830")

    // MARK: - Background Colors

    /// Primary app background - deep cinematic dark
    public static let backgroundDark = Color(hex: "1C1E26")

    /// Elevated surfaces - cards, modals, glass surfaces
    public static let backgroundElevated = Color(hex: "2A2D38")

    /// Even more elevated for layered modals
    public static let backgroundElevated2 = Color(hex: "363A48")

    // MARK: - Text Colors

    /// Primary text - pure white for maximum readability
    public static let textPrimary = Color(hex: "FFFFFF")

    /// Secondary text - muted for less important information
    public static let textSecondary = Color(hex: "A0A3B1")

    /// Tertiary text - even more muted
    public static let textTertiary = Color(hex: "6B6E7A")

    // MARK: - Semantic Colors

    /// Success state - winning, positive scores
    public static let success = Color(hex: "4CAF50")

    /// Warning state - draft timer running low
    public static let warning = Color(hex: "FFC107")

    /// Error state - failed actions
    public static let error = Color(hex: "F44336")

    /// Info state - neutral information
    public static let info = Color(hex: "2196F3")

    // MARK: - Gradient Presets

    /// Primary gold gradient - mimics the metallic shine of the logo
    public static let goldGradient = LinearGradient(
        colors: [goldLight, goldPrimary, goldDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Horizontal gold gradient for buttons
    public static let goldGradientHorizontal = LinearGradient(
        colors: [goldLight, goldPrimary],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Vertical gold gradient for headers
    public static let goldGradientVertical = LinearGradient(
        colors: [goldLight, goldDark],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Ruby gradient for special accents
    public static let rubyGradient = LinearGradient(
        colors: [rubyLight, ruby, rubyDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Background gradient for depth
    public static let backgroundGradient = LinearGradient(
        colors: [backgroundDark, backgroundElevated.opacity(0.5)],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Glass overlay gradient
    public static let glassGradient = LinearGradient(
        colors: [
            Color.white.opacity(0.15),
            Color.white.opacity(0.05)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Dripping Gold Effect Colors (for animations)

    /// Colors for the dripping gold loading animation inspired by the logo
    public static let drippingGoldColors: [Color] = [
        goldLight,
        goldPrimary,
        goldDark,
        Color(hex: "B8922E")
    ]
}

// MARK: - Color Extension for Hex Support

extension Color {
    /// Initialize a Color from a hex string
    /// Supports formats: "RRGGBB" or "#RRGGBB"
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
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

// MARK: - ShapeStyle Extensions for Easy Gradient Access

extension ShapeStyle where Self == LinearGradient {
    /// Quick access to the gold gradient
    static var ffGold: LinearGradient { FFColors.goldGradient }

    /// Quick access to the ruby gradient
    static var ffRuby: LinearGradient { FFColors.rubyGradient }
}
