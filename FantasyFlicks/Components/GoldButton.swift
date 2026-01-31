//
//  GoldButton.swift
//  FantasyFlicks
//
//  Premium gold gradient button component
//

import SwiftUI

/// Button style variants
enum FFButtonStyle {
    case primary      // Gold gradient fill
    case secondary    // Gold outline
    case ruby         // Ruby accent fill
    case ghost        // Transparent with text color
}

/// Button size variants
enum FFButtonSize {
    case small
    case medium
    case large

    var height: CGFloat {
        switch self {
        case .small: return 36
        case .medium: return 48
        case .large: return 56
        }
    }

    var font: Font {
        switch self {
        case .small: return FFTypography.labelMedium
        case .medium: return FFTypography.labelLarge
        case .large: return FFTypography.titleSmall
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .small: return FFSpacing.md
        case .medium: return FFSpacing.lg
        case .large: return FFSpacing.xl
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .small: return 14
        case .medium: return 18
        case .large: return 22
        }
    }
}

/// Premium gold button with multiple style variants
struct GoldButton: View {
    let title: String
    var icon: String?
    var iconPosition: IconPosition = .leading
    var style: FFButtonStyle = .primary
    var size: FFButtonSize = .medium
    var isLoading: Bool = false
    var isDisabled: Bool = false
    var fullWidth: Bool = false
    let action: () -> Void

    enum IconPosition {
        case leading, trailing
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: FFSpacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: textColor))
                        .scaleEffect(0.8)
                } else {
                    if let icon = icon, iconPosition == .leading {
                        Image(systemName: icon)
                            .font(.system(size: size.iconSize, weight: .semibold))
                    }

                    Text(title)
                        .font(size.font)

                    if let icon = icon, iconPosition == .trailing {
                        Image(systemName: icon)
                            .font(.system(size: size.iconSize, weight: .semibold))
                    }
                }
            }
            .foregroundColor(textColor)
            .frame(height: size.height)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, size.horizontalPadding)
            .background(backgroundView)
            .overlay(overlayView)
            .clipShape(Capsule())
            .opacity(isDisabled ? 0.5 : 1)
        }
        .disabled(isDisabled || isLoading)
        .pressEffect()
    }

    // MARK: - Computed Properties

    private var textColor: Color {
        switch style {
        case .primary:
            return FFColors.backgroundDark
        case .secondary:
            return FFColors.goldPrimary
        case .ruby:
            return .white
        case .ghost:
            return FFColors.goldPrimary
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .primary:
            Capsule()
                .fill(FFColors.goldGradientHorizontal)
                .shadow(color: FFColors.goldPrimary.opacity(0.3), radius: 8, x: 0, y: 4)
        case .secondary:
            Capsule()
                .fill(FFColors.goldPrimary.opacity(0.1))
        case .ruby:
            Capsule()
                .fill(FFColors.rubyGradient)
                .shadow(color: FFColors.ruby.opacity(0.3), radius: 8, x: 0, y: 4)
        case .ghost:
            Color.clear
        }
    }

    @ViewBuilder
    private var overlayView: some View {
        switch style {
        case .secondary:
            Capsule()
                .stroke(FFColors.goldGradientHorizontal, lineWidth: 2)
        case .ghost:
            Capsule()
                .stroke(FFColors.goldPrimary.opacity(0.3), lineWidth: 1)
        default:
            EmptyView()
        }
    }
}

// MARK: - Icon Button

/// Circular icon button
struct IconButton: View {
    let icon: String
    var size: CGFloat = 44
    var style: FFButtonStyle = .secondary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundColor(foregroundColor)
                .frame(width: size, height: size)
                .background(backgroundView)
                .clipShape(Circle())
        }
        .pressEffect()
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: return FFColors.backgroundDark
        case .secondary: return FFColors.goldPrimary
        case .ruby: return .white
        case .ghost: return FFColors.textSecondary
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .primary:
            Circle().fill(FFColors.goldGradient)
        case .secondary:
            Circle()
                .fill(FFColors.goldPrimary.opacity(0.15))
                .overlay(Circle().stroke(FFColors.goldPrimary.opacity(0.3), lineWidth: 1))
        case .ruby:
            Circle().fill(FFColors.ruby)
        case .ghost:
            Circle().fill(Color.white.opacity(0.1))
        }
    }
}

// MARK: - Previews

#Preview("Gold Buttons") {
    ZStack {
        FFColors.backgroundDark.ignoresSafeArea()

        VStack(spacing: FFSpacing.xl) {
            // Primary buttons
            VStack(spacing: FFSpacing.md) {
                Text("Primary")
                    .font(FFTypography.labelSmall)
                    .foregroundColor(FFColors.textSecondary)

                HStack(spacing: FFSpacing.md) {
                    GoldButton(title: "Small", size: .small) {}
                    GoldButton(title: "Medium", size: .medium) {}
                    GoldButton(title: "Large", size: .large) {}
                }
            }

            // With icons
            VStack(spacing: FFSpacing.md) {
                Text("With Icons")
                    .font(FFTypography.labelSmall)
                    .foregroundColor(FFColors.textSecondary)

                GoldButton(title: "Create League", icon: "plus.circle.fill") {}
                GoldButton(title: "Continue", icon: "arrow.right", iconPosition: .trailing) {}
            }

            // Secondary style
            VStack(spacing: FFSpacing.md) {
                Text("Secondary")
                    .font(FFTypography.labelSmall)
                    .foregroundColor(FFColors.textSecondary)

                GoldButton(title: "Join League", icon: "person.badge.plus", style: .secondary) {}
            }

            // Ruby style
            VStack(spacing: FFSpacing.md) {
                Text("Ruby Accent")
                    .font(FFTypography.labelSmall)
                    .foregroundColor(FFColors.textSecondary)

                GoldButton(title: "Live Draft", icon: "play.fill", style: .ruby) {}
            }

            // Full width
            GoldButton(title: "Get Started", fullWidth: true) {}
                .padding(.horizontal)

            // Icon buttons
            HStack(spacing: FFSpacing.lg) {
                IconButton(icon: "bell.fill", style: .secondary) {}
                IconButton(icon: "gearshape.fill", style: .ghost) {}
                IconButton(icon: "plus", style: .primary) {}
            }
        }
        .padding()
    }
}
