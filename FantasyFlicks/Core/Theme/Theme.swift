//
//  Theme.swift
//  FantasyFlicks
//
//  Main Theme entry point - imports and exposes the entire design system
//

import SwiftUI

// MARK: - Fantasy Flicks Theme

/// Central theme object providing access to all design tokens
public struct FFTheme {
    public static let colors = FFColors.self
    public static let typography = FFTypography.self
    public static let animations = FFAnimations.self
    public static let transitions = FFTransitions.self
}

// MARK: - Environment Values

private struct FFColorSchemeKey: EnvironmentKey {
    static let defaultValue: ColorScheme = .dark
}

extension EnvironmentValues {
    var ffColorScheme: ColorScheme {
        get { self[FFColorSchemeKey.self] }
        set { self[FFColorSchemeKey.self] = newValue }
    }
}

// MARK: - App-Wide Theme Modifier

struct FFThemeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .preferredColorScheme(.dark)
            .tint(FFColors.goldPrimary)
            .environment(\.ffColorScheme, .dark)
    }
}

extension View {
    /// Apply Fantasy Flicks theme to the entire view hierarchy
    func ffTheme() -> some View {
        modifier(FFThemeModifier())
    }
}

// MARK: - Common Spacing

public struct FFSpacing {
    /// Extra small: 4pt
    public static let xs: CGFloat = 4

    /// Small: 8pt
    public static let sm: CGFloat = 8

    /// Medium: 12pt
    public static let md: CGFloat = 12

    /// Large: 16pt
    public static let lg: CGFloat = 16

    /// Extra large: 24pt
    public static let xl: CGFloat = 24

    /// 2x Extra large: 32pt
    public static let xxl: CGFloat = 32

    /// 3x Extra large: 48pt
    public static let xxxl: CGFloat = 48
}

// MARK: - Common Corner Radii

public struct FFCornerRadius {
    /// Small: 8pt - chips, tags
    public static let small: CGFloat = 8

    /// Medium: 12pt - buttons
    public static let medium: CGFloat = 12

    /// Large: 16pt - cards
    public static let large: CGFloat = 16

    /// Extra large: 20pt - modals
    public static let xl: CGFloat = 20

    /// 2x Extra large: 24pt - floating cards
    public static let xxl: CGFloat = 24

    /// Full: for circular elements
    public static let full: CGFloat = 9999
}

// MARK: - Icon Sizes

public struct FFIconSize {
    /// Small: 16pt
    public static let small: CGFloat = 16

    /// Medium: 24pt
    public static let medium: CGFloat = 24

    /// Large: 32pt
    public static let large: CGFloat = 32

    /// Extra large: 48pt
    public static let xl: CGFloat = 48
}
