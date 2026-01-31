//
//  FFTypography.swift
//  FantasyFlicks
//
//  Fantasy Flicks Typography System
//  Premium, cinematic feel with SF Pro Display for headers and SF Pro Text for body
//

import SwiftUI

/// Fantasy Flicks typography system - clean, modern, premium fonts
public struct FFTypography {

    // MARK: - Display Fonts (Headlines, Hero Text)

    /// Extra large display - splash screens, hero sections
    public static let displayLarge = Font.system(size: 48, weight: .bold, design: .default)

    /// Large display - screen titles
    public static let displayMedium = Font.system(size: 36, weight: .bold, design: .default)

    /// Small display - section headers
    public static let displaySmall = Font.system(size: 28, weight: .semibold, design: .default)

    // MARK: - Headlines

    /// Primary headline
    public static let headlineLarge = Font.system(size: 24, weight: .semibold, design: .default)

    /// Secondary headline
    public static let headlineMedium = Font.system(size: 20, weight: .semibold, design: .default)

    /// Tertiary headline
    public static let headlineSmall = Font.system(size: 18, weight: .semibold, design: .default)

    // MARK: - Title Fonts

    /// Large title - card headers
    public static let titleLarge = Font.system(size: 22, weight: .medium, design: .default)

    /// Medium title - list items
    public static let titleMedium = Font.system(size: 18, weight: .medium, design: .default)

    /// Small title - compact elements
    public static let titleSmall = Font.system(size: 16, weight: .medium, design: .default)

    // MARK: - Body Fonts

    /// Large body text - main content
    public static let bodyLarge = Font.system(size: 17, weight: .regular, design: .default)

    /// Medium body text - standard content
    public static let bodyMedium = Font.system(size: 15, weight: .regular, design: .default)

    /// Small body text - secondary content
    public static let bodySmall = Font.system(size: 13, weight: .regular, design: .default)

    // MARK: - Label Fonts

    /// Large label - buttons, tabs
    public static let labelLarge = Font.system(size: 16, weight: .semibold, design: .default)

    /// Medium label - chips, tags
    public static let labelMedium = Font.system(size: 14, weight: .medium, design: .default)

    /// Small label - captions, metadata
    public static let labelSmall = Font.system(size: 12, weight: .medium, design: .default)

    // MARK: - Specialized Fonts

    /// Monospaced font for numbers, stats, scores
    public static let statLarge = Font.system(size: 32, weight: .bold, design: .monospaced)

    /// Medium stat display
    public static let statMedium = Font.system(size: 24, weight: .bold, design: .monospaced)

    /// Small stat display
    public static let statSmall = Font.system(size: 18, weight: .semibold, design: .monospaced)

    /// Caption text
    public static let caption = Font.system(size: 11, weight: .regular, design: .default)

    /// Overline text - section labels
    public static let overline = Font.system(size: 10, weight: .semibold, design: .default)
}

// MARK: - Text Style Modifiers

extension View {
    /// Apply gold gradient text effect
    func goldText() -> some View {
        self
            .foregroundStyle(FFColors.goldGradient)
    }

    /// Apply primary text styling
    func primaryText() -> some View {
        self
            .foregroundColor(FFColors.textPrimary)
    }

    /// Apply secondary text styling
    func secondaryText() -> some View {
        self
            .foregroundColor(FFColors.textSecondary)
    }
}

// MARK: - Convenience Text Styles

struct FFTextStyle: ViewModifier {
    let font: Font
    let color: Color

    func body(content: Content) -> some View {
        content
            .font(font)
            .foregroundColor(color)
    }
}

extension View {
    func ffTextStyle(font: Font, color: Color = FFColors.textPrimary) -> some View {
        modifier(FFTextStyle(font: font, color: color))
    }
}
