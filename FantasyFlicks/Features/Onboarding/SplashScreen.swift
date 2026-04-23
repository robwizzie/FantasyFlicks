//
//  SplashScreen.swift
//  FantasyFlicks
//
//  Shown on cold start while the Firebase auth state resolves.
//  Prevents the onboarding screen from flashing for already-signed-in users.
//

import SwiftUI

struct SplashScreen: View {
    @State private var logoScale: CGFloat = 0.85
    @State private var logoOpacity: Double = 0
    @State private var glowPulse = false

    var body: some View {
        ZStack {
            // Background
            FFColors.backgroundDark.ignoresSafeArea()

            // Ambient top glow
            VStack {
                EllipticalGradient(
                    colors: [
                        FFColors.goldPrimary.opacity(0.25),
                        FFColors.goldDark.opacity(0.08),
                        Color.clear
                    ],
                    center: .center,
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.5
                )
                .frame(height: 500)
                .blur(radius: 60)
                Spacer()
            }
            .ignoresSafeArea()

            // Logo + pulsing glow behind it
            ZStack {
                Circle()
                    .fill(FFColors.goldPrimary.opacity(0.25))
                    .frame(width: 180, height: 180)
                    .blur(radius: 40)
                    .scaleEffect(glowPulse ? 1.1 : 0.9)
                    .opacity(glowPulse ? 0.8 : 0.5)

                Image("icon-no-bg")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 140, height: 140)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    .shadow(color: FFColors.goldPrimary.opacity(0.4), radius: 24, x: 0, y: 0)
            }

            // Subtitle at bottom
            VStack {
                Spacer()
                VStack(spacing: FFSpacing.xs) {
                    Text("Fantasy Flicks")
                        .font(FFTypography.headlineSmall)
                        .foregroundStyle(FFColors.goldGradient)
                    Text("Swipe. Match. Watch.")
                        .font(FFTypography.labelSmall)
                        .foregroundColor(FFColors.textTertiary)
                        .tracking(1.5)
                }
                .opacity(logoOpacity)
                .padding(.bottom, FFSpacing.xxl * 2)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }
}

#Preview {
    SplashScreen()
}
