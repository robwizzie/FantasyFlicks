//
//  MatchCelebrationView.swift
//  FantasyFlicks
//
//  Gold confetti celebration overlay for Movie Night unanimous matches
//

import SwiftUI

struct MatchCelebrationView: View {
    let movieTitle: String
    let posterURL: URL?
    let onDismiss: () -> Void

    @State private var showContent = false
    @State private var confettiParticles: [ConfettiParticle] = []
    @State private var animateConfetti = false

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            // Confetti layer
            confettiLayer

            // Center content
            VStack(spacing: FFSpacing.xl) {
                // "IT'S A MATCH!" header
                VStack(spacing: FFSpacing.sm) {
                    Image(systemName: "party.popper.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(FFColors.goldGradient)

                    Text("IT'S A MATCH!")
                        .font(FFTypography.hero)
                        .goldText()

                    Text("Everyone wants to watch")
                        .font(FFTypography.bodyMedium)
                        .foregroundColor(FFColors.textSecondary)
                }
                .scaleEffect(showContent ? 1.0 : 0.5)
                .opacity(showContent ? 1.0 : 0)

                // Movie poster
                if let posterURL {
                    CachedAsyncImage(url: posterURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: FFCornerRadius.xl)
                            .fill(FFColors.backgroundElevated)
                    }
                    .frame(width: 180, height: 270)
                    .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.xl))
                    .overlay {
                        RoundedRectangle(cornerRadius: FFCornerRadius.xl)
                            .stroke(FFColors.goldGradient, lineWidth: 3)
                    }
                    .shadow(color: FFColors.goldPrimary.opacity(0.5), radius: 30, x: 0, y: 0)
                    .scaleEffect(showContent ? 1.0 : 0.3)
                    .opacity(showContent ? 1.0 : 0)
                }

                // Movie title
                Text(movieTitle)
                    .font(FFTypography.headlineLarge)
                    .foregroundColor(FFColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, FFSpacing.xxl)
                    .opacity(showContent ? 1.0 : 0)

                // Dismiss button
                GoldButton(title: "Let's Watch!", style: .primary, size: .large) {
                    onDismiss()
                }
                .padding(.horizontal, FFSpacing.xxl)
                .opacity(showContent ? 1.0 : 0)
            }
        }
        .onAppear {
            generateConfetti()
            withAnimation(FFAnimations.heavy) {
                showContent = true
            }
            withAnimation(.linear(duration: 3.0)) {
                animateConfetti = true
            }
            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            // Auto-dismiss after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                onDismiss()
            }
        }
    }

    // MARK: - Confetti

    private var confettiLayer: some View {
        GeometryReader { geo in
            ForEach(confettiParticles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .position(
                        x: particle.x * geo.size.width,
                        y: animateConfetti ? geo.size.height + 50 : -50
                    )
                    .rotationEffect(.degrees(animateConfetti ? particle.rotation : 0))
                    .opacity(animateConfetti ? 0 : 1)
                    .animation(
                        .easeIn(duration: particle.duration)
                            .delay(particle.delay),
                        value: animateConfetti
                    )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func generateConfetti() {
        let colors: [Color] = [
            FFColors.goldPrimary,
            FFColors.goldLight,
            FFColors.goldDark,
            FFColors.ruby,
            FFColors.rubyLight,
            .white
        ]

        confettiParticles = (0..<60).map { i in
            ConfettiParticle(
                id: i,
                x: CGFloat.random(in: 0...1),
                color: colors.randomElement()!,
                size: CGFloat.random(in: 4...10),
                rotation: Double.random(in: 0...720),
                duration: Double.random(in: 2.0...3.5),
                delay: Double.random(in: 0...0.8)
            )
        }
    }
}

// MARK: - Confetti Particle

struct ConfettiParticle: Identifiable {
    let id: Int
    let x: CGFloat
    let color: Color
    let size: CGFloat
    let rotation: Double
    let duration: Double
    let delay: Double
}

// MARK: - Preview

#Preview {
    MatchCelebrationView(
        movieTitle: "Dune: Part Two",
        posterURL: nil,
        onDismiss: {}
    )
}
