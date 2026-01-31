//
//  FFAnimations.swift
//  FantasyFlicks
//
//  Smooth animations and transitions
//  Premium, cinematic motion design inspired by the dripping gold logo
//

import SwiftUI

// MARK: - Animation Presets

public struct FFAnimations {

    // MARK: - Standard Animations

    /// Quick, snappy animation for micro-interactions
    public static let quick = Animation.easeOut(duration: 0.2)

    /// Standard animation for most UI transitions
    public static let standard = Animation.easeInOut(duration: 0.3)

    /// Smooth animation for larger transitions
    public static let smooth = Animation.easeInOut(duration: 0.4)

    /// Slow, dramatic animation for hero moments
    public static let dramatic = Animation.easeInOut(duration: 0.6)

    // MARK: - Spring Animations

    /// Bouncy spring for playful interactions
    public static let bouncy = Animation.spring(response: 0.4, dampingFraction: 0.6)

    /// Gentle spring for natural motion
    public static let gentle = Animation.spring(response: 0.5, dampingFraction: 0.8)

    /// Snappy spring for responsive feedback
    public static let snappy = Animation.spring(response: 0.3, dampingFraction: 0.7)

    /// Heavy spring for impactful animations
    public static let heavy = Animation.spring(response: 0.6, dampingFraction: 0.7)

    // MARK: - Specialized Animations

    /// Gold drip animation timing
    public static let drip = Animation.easeIn(duration: 0.8).repeatForever(autoreverses: false)

    /// Shimmer animation for loading states
    public static let shimmer = Animation.linear(duration: 1.5).repeatForever(autoreverses: false)

    /// Pulse animation for live indicators
    public static let pulse = Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)

    /// Glow animation for highlights
    public static let glow = Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)
}

// MARK: - Transition Presets

public struct FFTransitions {

    /// Slide up with fade
    public static let slideUp = AnyTransition.asymmetric(
        insertion: .move(edge: .bottom).combined(with: .opacity),
        removal: .move(edge: .bottom).combined(with: .opacity)
    )

    /// Slide from trailing edge
    public static let slideTrailing = AnyTransition.asymmetric(
        insertion: .move(edge: .trailing).combined(with: .opacity),
        removal: .move(edge: .leading).combined(with: .opacity)
    )

    /// Scale and fade
    public static let scaleAndFade = AnyTransition.scale(scale: 0.9).combined(with: .opacity)

    /// Dramatic scale for hero elements
    public static let heroScale = AnyTransition.scale(scale: 0.5).combined(with: .opacity)
}

// MARK: - Shimmer Effect

struct FFShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            FFColors.goldLight.opacity(0.3),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (geometry.size.width * 2 * phase))
                }
                .mask(content)
            }
            .onAppear {
                withAnimation(FFAnimations.shimmer) {
                    phase = 1
                }
            }
    }
}

// MARK: - Pulse Effect

struct FFPulseEffect: ViewModifier {
    @State private var isPulsing = false
    let color: Color

    func body(content: Content) -> some View {
        content
            .overlay {
                Circle()
                    .stroke(color, lineWidth: 2)
                    .scaleEffect(isPulsing ? 1.5 : 1.0)
                    .opacity(isPulsing ? 0 : 0.8)
            }
            .onAppear {
                withAnimation(FFAnimations.pulse) {
                    isPulsing = true
                }
            }
    }
}

// MARK: - Dripping Gold Loading Animation

struct FFDrippingGoldLoader: View {
    @State private var dropOffsets: [CGFloat] = [0, 0, 0, 0, 0]
    @State private var dropOpacities: [Double] = [1, 1, 1, 1, 1]

    let dropCount = 5
    let dropWidth: CGFloat = 8
    let dropHeight: CGFloat = 20
    let animationHeight: CGFloat = 60

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<dropCount, id: \.self) { index in
                Capsule()
                    .fill(FFColors.goldGradient)
                    .frame(width: dropWidth, height: dropHeight)
                    .offset(y: dropOffsets[index])
                    .opacity(dropOpacities[index])
            }
        }
        .onAppear {
            animateDrops()
        }
    }

    private func animateDrops() {
        for index in 0..<dropCount {
            let delay = Double(index) * 0.15

            withAnimation(
                Animation
                    .easeIn(duration: 0.6)
                    .repeatForever(autoreverses: false)
                    .delay(delay)
            ) {
                dropOffsets[index] = animationHeight
            }

            withAnimation(
                Animation
                    .easeIn(duration: 0.6)
                    .repeatForever(autoreverses: false)
                    .delay(delay + 0.4)
            ) {
                dropOpacities[index] = 0
            }
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Apply shimmer loading effect
    func shimmer() -> some View {
        modifier(FFShimmerEffect())
    }

    /// Apply pulse effect
    func pulse(color: Color = FFColors.goldPrimary) -> some View {
        modifier(FFPulseEffect(color: color))
    }

    /// Animate appearance with standard transition
    func animateAppearance() -> some View {
        self
            .transition(FFTransitions.scaleAndFade)
            .animation(FFAnimations.smooth, value: UUID())
    }
}

// MARK: - Button Press Effect

struct FFButtonPressEffect: ViewModifier {
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(FFAnimations.quick, value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

extension View {
    /// Apply press effect for buttons
    func pressEffect() -> some View {
        modifier(FFButtonPressEffect())
    }
}
