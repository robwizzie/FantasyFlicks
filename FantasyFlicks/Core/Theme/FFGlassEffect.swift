//
//  FFGlassEffect.swift
//  FantasyFlicks
//
//  iOS 18 Liquid Glass / Glassmorphism Effects
//  Premium, cinematic visual effects matching the app icon aesthetic
//

import SwiftUI

// MARK: - Glass Effect Modifier

/// iOS 18 liquid glass effect with customizable properties
struct FFGlassEffect: ViewModifier {
    let cornerRadius: CGFloat
    let opacity: Double
    let blur: CGFloat
    let borderWidth: CGFloat
    let borderOpacity: Double

    init(
        cornerRadius: CGFloat = 20,
        opacity: Double = 0.1,
        blur: CGFloat = 10,
        borderWidth: CGFloat = 1,
        borderOpacity: Double = 0.2
    ) {
        self.cornerRadius = cornerRadius
        self.opacity = opacity
        self.blur = blur
        self.borderWidth = borderWidth
        self.borderOpacity = borderOpacity
    }

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .opacity(opacity * 10) // Adjust for material
            }
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(FFColors.backgroundElevated.opacity(opacity))
                    .blur(radius: blur)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(borderOpacity),
                                Color.white.opacity(borderOpacity * 0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: borderWidth
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - Gold Glass Effect

/// Glass effect with gold tint - premium variant
struct FFGoldGlassEffect: ViewModifier {
    let cornerRadius: CGFloat
    let intensity: Double

    init(cornerRadius: CGFloat = 20, intensity: Double = 0.15) {
        self.cornerRadius = cornerRadius
        self.intensity = intensity
    }

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
            }
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                FFColors.goldPrimary.opacity(intensity),
                                FFColors.goldDark.opacity(intensity * 0.5)
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
                                FFColors.goldLight.opacity(0.4),
                                FFColors.goldPrimary.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - Ruby Glass Effect

/// Glass effect with ruby tint - for alerts and special highlights
struct FFRubyGlassEffect: ViewModifier {
    let cornerRadius: CGFloat
    let intensity: Double

    init(cornerRadius: CGFloat = 20, intensity: Double = 0.15) {
        self.cornerRadius = cornerRadius
        self.intensity = intensity
    }

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
            }
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                FFColors.ruby.opacity(intensity),
                                FFColors.rubyDark.opacity(intensity * 0.5)
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
                                FFColors.rubyLight.opacity(0.4),
                                FFColors.ruby.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - Floating Glass Card Effect

/// Elevated glass card with shadow
struct FFFloatingGlassEffect: ViewModifier {
    let cornerRadius: CGFloat

    init(cornerRadius: CGFloat = 24) {
        self.cornerRadius = cornerRadius
    }

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
            }
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(FFColors.backgroundElevated.opacity(0.8))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}

// MARK: - View Extensions

extension View {
    /// Apply standard glass effect
    func glassEffect(
        cornerRadius: CGFloat = 20,
        opacity: Double = 0.1,
        blur: CGFloat = 10
    ) -> some View {
        modifier(FFGlassEffect(cornerRadius: cornerRadius, opacity: opacity, blur: blur))
    }

    /// Apply gold-tinted glass effect
    func goldGlassEffect(
        cornerRadius: CGFloat = 20,
        intensity: Double = 0.15
    ) -> some View {
        modifier(FFGoldGlassEffect(cornerRadius: cornerRadius, intensity: intensity))
    }

    /// Apply ruby-tinted glass effect
    func rubyGlassEffect(
        cornerRadius: CGFloat = 20,
        intensity: Double = 0.15
    ) -> some View {
        modifier(FFRubyGlassEffect(cornerRadius: cornerRadius, intensity: intensity))
    }

    /// Apply floating glass card effect with shadow
    func floatingGlassEffect(cornerRadius: CGFloat = 24) -> some View {
        modifier(FFFloatingGlassEffect(cornerRadius: cornerRadius))
    }
}

// MARK: - Inner Glow Effect

struct FFInnerGlowEffect: ViewModifier {
    let color: Color
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(color, lineWidth: 2)
                    .blur(radius: radius)
                    .mask(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [.black, .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
            }
    }
}

extension View {
    /// Apply inner glow effect
    func innerGlow(color: Color = FFColors.goldPrimary, radius: CGFloat = 4) -> some View {
        modifier(FFInnerGlowEffect(color: color, radius: radius))
    }
}
