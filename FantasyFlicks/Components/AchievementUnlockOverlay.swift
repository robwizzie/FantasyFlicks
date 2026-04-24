//
//  AchievementUnlockOverlay.swift
//  FantasyFlicks
//
//  Celebratory overlay that animates in when a new achievement unlocks.
//  Listens to AchievementService.shared.pendingCelebrations and displays the
//  first queued definition at a time.
//

import SwiftUI

struct AchievementUnlockOverlay: View {
    @StateObject private var service = AchievementService.shared
    @State private var appearScale: CGFloat = 0.4
    @State private var appearOpacity: Double = 0
    @State private var sparkle: Bool = false

    private var current: AchievementDefinition? {
        service.pendingCelebrations.first
    }

    var body: some View {
        ZStack {
            if let def = current {
                Color.black.opacity(0.72)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { dismiss(def) }

                VStack(spacing: FFSpacing.lg) {
                    // Sparkle burst
                    ZStack {
                        ForEach(0..<12) { i in
                            Image(systemName: "sparkle")
                                .font(.system(size: 14))
                                .foregroundStyle(FFColors.goldGradient)
                                .offset(
                                    x: cos(Double(i) * .pi / 6) * (sparkle ? 90 : 20),
                                    y: sin(Double(i) * .pi / 6) * (sparkle ? 90 : 20)
                                )
                                .opacity(sparkle ? 0 : 1)
                                .scaleEffect(sparkle ? 0.4 : 1.0)
                        }

                        Circle()
                            .fill(FFColors.goldPrimary.opacity(0.2))
                            .frame(width: 140, height: 140)
                            .blur(radius: 28)

                        Circle()
                            .fill(FFColors.goldGradient)
                            .frame(width: 96, height: 96)

                        Image(systemName: def.icon)
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundColor(FFColors.backgroundDark)
                    }
                    .scaleEffect(appearScale)

                    VStack(spacing: FFSpacing.xs) {
                        Text("ACHIEVEMENT UNLOCKED")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .tracking(2)
                            .foregroundColor(FFColors.goldPrimary)

                        Text(def.name)
                            .font(FFTypography.displaySmall)
                            .foregroundColor(FFColors.textPrimary)

                        Text(def.description)
                            .font(FFTypography.bodyMedium)
                            .foregroundColor(FFColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, FFSpacing.xl)
                    }
                    .opacity(appearOpacity)

                    GoldButton(title: "Nice!", style: .primary, size: .medium) {
                        dismiss(def)
                    }
                    .padding(.horizontal, FFSpacing.xxl)
                    .opacity(appearOpacity)
                }
                .padding(FFSpacing.xxl)
                .transition(.opacity)
                .onAppear { animateIn() }
            }
        }
        .animation(.easeOut(duration: 0.25), value: service.pendingCelebrations.count)
        // Only intercept touches when there's actually something to dismiss.
        // Otherwise we'd block taps across the whole app invisibly.
        .allowsHitTesting(current != nil)
    }

    private func animateIn() {
        appearScale = 0.4
        appearOpacity = 0
        sparkle = false

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            appearScale = 1.0
        }
        withAnimation(.easeOut(duration: 0.35).delay(0.15)) {
            appearOpacity = 1
        }
        withAnimation(.easeOut(duration: 0.9).delay(0.2)) {
            sparkle = true
        }
    }

    private func dismiss(_ def: AchievementDefinition) {
        withAnimation(.easeOut(duration: 0.2)) {
            appearOpacity = 0
            appearScale = 0.6
        }
        // Give the animation a moment to fade, then remove from queue
        Task {
            try? await Task.sleep(for: .milliseconds(220))
            service.dequeueCelebration(def)
        }
    }
}
