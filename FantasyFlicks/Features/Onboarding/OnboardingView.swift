//
//  OnboardingView.swift
//  FantasyFlicks
//
//  Welcome and authentication screen for new users
//

import SwiftUI
import AuthenticationServices
import GoogleSignInSwift

struct OnboardingView: View {
    @StateObject private var authService = AuthenticationService.shared
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            // Background
            backgroundView

            VStack(spacing: 0) {
                // Page indicator
                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(index == currentPage ? FFColors.goldPrimary : FFColors.textTertiary)
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top, 60)

                // Content
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    featuresPage.tag(1)
                    signInPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }

            // Loading overlay
            if authService.isLoading {
                loadingOverlay
            }
        }
        .alert("Error", isPresented: .constant(authService.error != nil)) {
            Button("OK") { authService.error = nil }
        } message: {
            Text(authService.error ?? "")
        }
    }

    // MARK: - Background

    private var backgroundView: some View {
        ZStack {
            FFColors.backgroundDark.ignoresSafeArea()

            // Gradient glow
            VStack {
                EllipticalGradient(
                    colors: [
                        FFColors.goldPrimary.opacity(0.2),
                        FFColors.goldDark.opacity(0.1),
                        Color.clear
                    ],
                    center: .top,
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.6
                )
                .frame(height: 500)
                .blur(radius: 80)

                Spacer()
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Welcome Page

    private var welcomePage: some View {
        VStack(spacing: FFSpacing.xxl) {
            Spacer()

            // Logo
            Image("icon-no-bg")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)

            VStack(spacing: FFSpacing.md) {
                Text("Fantasy Flicks")
                    .font(.system(size: 38, weight: .bold, design: .serif))
                    .tracking(0.5)
                    .foregroundStyle(FFColors.goldGradient)

                Text("Draft movies. Compete with friends.\nWin bragging rights.")
                    .font(FFTypography.bodyLarge)
                    .foregroundColor(FFColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Next button
            Button {
                withAnimation {
                    currentPage = 1
                }
            } label: {
                Text("Get Started")
                    .font(FFTypography.labelLarge)
                    .foregroundColor(FFColors.backgroundDark)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FFSpacing.lg)
                    .background(FFColors.goldGradientHorizontal)
                    .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.large))
            }
            .padding(.horizontal, FFSpacing.xl)
            .padding(.bottom, FFSpacing.xxl)
        }
    }

    // MARK: - Features Page

    private var featuresPage: some View {
        VStack(spacing: FFSpacing.xxl) {
            Spacer()

            VStack(spacing: FFSpacing.xxl) {
                FeatureRow(
                    icon: "film.stack",
                    title: "Draft Movies",
                    description: "Build your dream lineup from upcoming releases"
                )

                FeatureRow(
                    icon: "trophy.fill",
                    title: "Compete",
                    description: "Score points based on real box office performance"
                )

                FeatureRow(
                    icon: "person.3.fill",
                    title: "Play with Friends",
                    description: "Create leagues and compete against your friends"
                )
            }
            .padding(.horizontal, FFSpacing.xl)

            Spacer()

            // Next button
            Button {
                withAnimation {
                    currentPage = 2
                }
            } label: {
                Text("Continue")
                    .font(FFTypography.labelLarge)
                    .foregroundColor(FFColors.backgroundDark)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FFSpacing.lg)
                    .background(FFColors.goldGradientHorizontal)
                    .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.large))
            }
            .padding(.horizontal, FFSpacing.xl)
            .padding(.bottom, FFSpacing.xxl)
        }
    }

    // MARK: - Sign In Page

    private var signInPage: some View {
        VStack(spacing: FFSpacing.xxl) {
            Spacer()

            VStack(spacing: FFSpacing.md) {
                Text("Sign In")
                    .font(FFTypography.displaySmall)
                    .foregroundStyle(FFColors.goldGradient)

                Text("Create an account to save your progress\nand play with friends")
                    .font(FFTypography.bodyMedium)
                    .foregroundColor(FFColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            VStack(spacing: FFSpacing.md) {
                // Apple Sign In
                SignInWithAppleButton(
                    onRequest: { request in
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = authService.generateNonce()
                    },
                    onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                                Task {
                                    try? await authService.signInWithApple(credential: appleIDCredential)
                                }
                            }
                        case .failure(let error):
                            authService.error = error.localizedDescription
                        }
                    }
                )
                .signInWithAppleButtonStyle(.white)
                .frame(height: 50)
                .cornerRadius(8)

                // Google Sign In - Official Button
                GoogleSignInButton(scheme: .light, style: .wide) {
                    Task {
                        try? await authService.signInWithGoogle()
                    }
                }
                .frame(height: 50)
                .cornerRadius(8)
            }
            .padding(.horizontal, FFSpacing.xl)

            // Terms
            Text("By continuing, you agree to our Terms of Service and Privacy Policy")
                .font(FFTypography.caption)
                .foregroundColor(FFColors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, FFSpacing.xl)
                .padding(.bottom, FFSpacing.xxl)
        }
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: FFSpacing.lg) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(FFColors.goldPrimary)

                Text("Signing in...")
                    .font(FFTypography.bodyMedium)
                    .foregroundColor(FFColors.textPrimary)
            }
            .padding(FFSpacing.xxl)
            .background {
                RoundedRectangle(cornerRadius: FFCornerRadius.xl)
                    .fill(FFColors.backgroundElevated)
            }
        }
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: FFSpacing.lg) {
            ZStack {
                Circle()
                    .fill(FFColors.goldPrimary.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(FFColors.goldGradient)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(FFTypography.headlineSmall)
                    .foregroundColor(FFColors.textPrimary)

                Text(description)
                    .font(FFTypography.bodySmall)
                    .foregroundColor(FFColors.textSecondary)
            }

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
}
