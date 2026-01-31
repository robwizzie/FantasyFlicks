//
//  GlassCard.swift
//  FantasyFlicks
//
//  Reusable glass-morphism card component
//

import SwiftUI

/// A premium glass-morphism card with customizable styling
struct GlassCard<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat
    var padding: CGFloat
    var shadowRadius: CGFloat
    var goldTint: Bool

    init(
        cornerRadius: CGFloat = FFCornerRadius.xl,
        padding: CGFloat = FFSpacing.lg,
        shadowRadius: CGFloat = 15,
        goldTint: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.shadowRadius = shadowRadius
        self.goldTint = goldTint
    }

    var body: some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
            }
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        goldTint
                            ? LinearGradient(
                                colors: [
                                    FFColors.goldPrimary.opacity(0.1),
                                    FFColors.backgroundElevated.opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [
                                    FFColors.backgroundElevated.opacity(0.8),
                                    FFColors.backgroundElevated.opacity(0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                goldTint ? FFColors.goldLight.opacity(0.4) : Color.white.opacity(0.2),
                                goldTint ? FFColors.goldPrimary.opacity(0.1) : Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: Color.black.opacity(0.2), radius: shadowRadius, x: 0, y: 8)
    }
}

// MARK: - Compact Glass Card

/// A smaller glass card variant for list items
struct CompactGlassCard<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat

    init(
        cornerRadius: CGFloat = FFCornerRadius.large,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        content
            .padding(FFSpacing.md)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(FFColors.backgroundElevated.opacity(0.6))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - Feature Card

/// A larger featured card for highlights
struct FeatureCard<Content: View>: View {
    let content: Content
    var backgroundImage: URL?

    init(
        backgroundImage: URL? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.backgroundImage = backgroundImage
    }

    var body: some View {
        content
            .padding(FFSpacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack {
                    // Background image if provided
                    if let url = backgroundImage {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            FFColors.backgroundElevated
                        }
                    } else {
                        FFColors.backgroundElevated
                    }

                    // Gradient overlay for readability
                    LinearGradient(
                        colors: [
                            FFColors.backgroundDark.opacity(0.9),
                            FFColors.backgroundDark.opacity(0.6),
                            FFColors.backgroundDark.opacity(0.4)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )

                    // Gold accent glow
                    LinearGradient(
                        colors: [
                            FFColors.goldPrimary.opacity(0.15),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: FFCornerRadius.xxl)
                    .stroke(
                        LinearGradient(
                            colors: [
                                FFColors.goldLight.opacity(0.3),
                                FFColors.goldPrimary.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.xxl))
            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}

// MARK: - Previews

#Preview("Glass Card") {
    ZStack {
        FFColors.backgroundDark.ignoresSafeArea()

        VStack(spacing: FFSpacing.xl) {
            GlassCard {
                VStack(alignment: .leading, spacing: FFSpacing.sm) {
                    Text("Glass Card")
                        .font(FFTypography.headlineMedium)
                        .foregroundColor(FFColors.textPrimary)
                    Text("This is a beautiful glass-morphism card")
                        .font(FFTypography.bodyMedium)
                        .foregroundColor(FFColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GlassCard(goldTint: true) {
                VStack(alignment: .leading, spacing: FFSpacing.sm) {
                    Text("Gold Tinted")
                        .font(FFTypography.headlineMedium)
                        .foregroundColor(FFColors.goldPrimary)
                    Text("Premium gold accent styling")
                        .font(FFTypography.bodyMedium)
                        .foregroundColor(FFColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            CompactGlassCard {
                HStack {
                    Text("Compact Card")
                        .font(FFTypography.titleSmall)
                        .foregroundColor(FFColors.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(FFColors.textSecondary)
                }
            }
        }
        .padding()
    }
}
