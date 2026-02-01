//
//  OnboardingView.swift
//  FantasyFlicks
//
//  Welcome and authentication screen for new users
//  Premium onboarding experience with movie showcase
//

import SwiftUI
import AuthenticationServices
import GoogleSignIn

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
                        Capsule()
                            .fill(index == currentPage ? FFColors.goldPrimary : FFColors.textTertiary.opacity(0.4))
                            .frame(width: index == currentPage ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }
                .padding(.top, 60)

                // Content
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    movieShowcasePage.tag(1)
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

            // Animated gradient glow
            VStack {
                EllipticalGradient(
                    colors: [
                        FFColors.goldPrimary.opacity(0.15),
                        FFColors.goldDark.opacity(0.08),
                        Color.clear
                    ],
                    center: .top,
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.7
                )
                .frame(height: 600)
                .blur(radius: 100)

                Spacer()
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Welcome Page

    private var welcomePage: some View {
        VStack(spacing: FFSpacing.xxl) {
            Spacer()

            // Logo with subtle glow
            ZStack {
                // Glow effect
                Circle()
                    .fill(FFColors.goldPrimary.opacity(0.2))
                    .frame(width: 160, height: 160)
                    .blur(radius: 40)

                Image("icon-no-bg")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 130, height: 130)
            }

            VStack(spacing: FFSpacing.lg) {
                Text("Fantasy Flicks")
                    .font(FFTypography.hero)
                    .tracking(1)
                    .foregroundStyle(FFColors.goldGradient)

                Text("Draft movies. Compete with friends.\nWin bragging rights.")
                    .font(FFTypography.elegantSubtitle)
                    .foregroundColor(FFColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Spacer()

            // Features preview
            VStack(spacing: FFSpacing.md) {
                FeatureChip(icon: "film.stack", text: "Draft Movies")
                FeatureChip(icon: "trophy.fill", text: "Compete & Win")
                FeatureChip(icon: "person.3.fill", text: "Play with Friends")
            }

            Spacer()

            // Next button
            PremiumButton(title: "Get Started") {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    currentPage = 1
                }
            }
            .padding(.horizontal, FFSpacing.xl)
            .padding(.bottom, FFSpacing.xxl)
        }
    }

    // MARK: - Movie Showcase Page

    private var movieShowcasePage: some View {
        VStack(spacing: FFSpacing.lg) {
            Spacer()

            VStack(spacing: FFSpacing.sm) {
                Text("Now Playing")
                    .font(FFTypography.overline)
                    .foregroundColor(FFColors.goldPrimary)
                    .tracking(2)
                    .textCase(.uppercase)

                Text("Discover & Draft")
                    .font(FFTypography.displaySmall)
                    .foregroundStyle(FFColors.goldGradient)
            }

            // Movie Carousel
            MovieCarousel()
                .frame(height: 340)

            VStack(spacing: FFSpacing.sm) {
                Text("Score points based on real box office performance")
                    .font(FFTypography.bodyMedium)
                    .foregroundColor(FFColors.textSecondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: FFSpacing.xl) {
                    StatPreview(value: "$1.2B", label: "Top Score")
                    StatPreview(value: "52", label: "Movies")
                    StatPreview(value: "10K+", label: "Players")
                }
                .padding(.top, FFSpacing.md)
            }
            .padding(.horizontal, FFSpacing.xl)

            Spacer()

            // Next button
            PremiumButton(title: "Continue") {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    currentPage = 2
                }
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
                Text("Welcome")
                    .font(FFTypography.displaySmall)
                    .foregroundStyle(FFColors.goldGradient)

                Text("Sign in to save your progress\nand compete with friends")
                    .font(FFTypography.bodyMedium)
                    .foregroundColor(FFColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            Spacer()

            VStack(spacing: FFSpacing.md) {
                // Apple Sign In - Custom styled button
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
                .frame(height: 56)
                .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.large))
                .overlay(
                    RoundedRectangle(cornerRadius: FFCornerRadius.large)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )

                // Google Sign In - Custom styled to match Apple
                GoogleSignInButtonStyled {
                    Task {
                        try? await authService.signInWithGoogle()
                    }
                }
            }
            .padding(.horizontal, FFSpacing.xl)

            // Divider
            HStack(spacing: FFSpacing.md) {
                Rectangle()
                    .fill(FFColors.textTertiary.opacity(0.3))
                    .frame(height: 1)
                Text("secure authentication")
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textTertiary)
                    .textCase(.uppercase)
                    .tracking(1)
                Rectangle()
                    .fill(FFColors.textTertiary.opacity(0.3))
                    .frame(height: 1)
            }
            .padding(.horizontal, FFSpacing.xl)
            .padding(.top, FFSpacing.lg)

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
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: FFSpacing.lg) {
                // Custom gold spinner
                FFDrippingGoldLoader()

                Text("Signing in...")
                    .font(FFTypography.bodyMedium)
                    .foregroundColor(FFColors.textPrimary)
            }
            .padding(FFSpacing.xxl)
            .background {
                RoundedRectangle(cornerRadius: FFCornerRadius.xl)
                    .fill(FFColors.backgroundElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: FFCornerRadius.xl)
                            .stroke(FFColors.goldPrimary.opacity(0.2), lineWidth: 1)
                    )
            }
        }
    }
}

// MARK: - Feature Chip

struct FeatureChip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: FFSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(FFColors.goldGradient)

            Text(text)
                .font(FFTypography.labelSmall)
                .foregroundColor(FFColors.textSecondary)
        }
        .padding(.horizontal, FFSpacing.lg)
        .padding(.vertical, FFSpacing.sm)
        .background(
            Capsule()
                .fill(FFColors.backgroundElevated)
                .overlay(
                    Capsule()
                        .stroke(FFColors.goldPrimary.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Stat Preview

struct StatPreview: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(FFTypography.titleMedium)
                .foregroundStyle(FFColors.goldGradient)

            Text(label)
                .font(FFTypography.caption)
                .foregroundColor(FFColors.textTertiary)
        }
    }
}

// MARK: - Premium Button

struct PremiumButton: View {
    let title: String
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(FFTypography.labelLarge)
                .foregroundColor(FFColors.backgroundDark)
                .frame(maxWidth: .infinity)
                .padding(.vertical, FFSpacing.lg)
                .background(FFColors.goldGradientHorizontal)
                .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.large))
                .overlay(
                    RoundedRectangle(cornerRadius: FFCornerRadius.large)
                        .stroke(FFColors.goldLight.opacity(0.5), lineWidth: 1)
                )
                .shadow(color: FFColors.goldPrimary.opacity(0.3), radius: 12, y: 4)
        }
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.2), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Google Sign In Button (Styled to match Apple)

struct GoogleSignInButtonStyled: View {
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: FFSpacing.md) {
                // Google Logo
                GoogleLogo()
                    .frame(width: 20, height: 20)

                Text("Sign in with Google")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.black)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.large))
            .overlay(
                RoundedRectangle(cornerRadius: FFCornerRadius.large)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.2), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Google Logo

struct GoogleLogo: View {
    var body: some View {
        // Google "G" logo using paths
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)

            ZStack {
                // Blue
                Path { path in
                    path.move(to: CGPoint(x: size * 0.98, y: size * 0.5))
                    path.addLine(to: CGPoint(x: size * 0.98, y: size * 0.42))
                    path.addLine(to: CGPoint(x: size * 0.52, y: size * 0.42))
                    path.addLine(to: CGPoint(x: size * 0.52, y: size * 0.58))
                    path.addLine(to: CGPoint(x: size * 0.82, y: size * 0.58))
                    path.addCurve(
                        to: CGPoint(x: size * 0.5, y: size * 0.9),
                        control1: CGPoint(x: size * 0.78, y: size * 0.76),
                        control2: CGPoint(x: size * 0.66, y: size * 0.9)
                    )
                }
                .fill(Color(red: 66/255, green: 133/255, blue: 244/255))

                // Green
                Path { path in
                    path.move(to: CGPoint(x: size * 0.5, y: size * 0.9))
                    path.addCurve(
                        to: CGPoint(x: size * 0.14, y: size * 0.64),
                        control1: CGPoint(x: size * 0.3, y: size * 0.9),
                        control2: CGPoint(x: size * 0.14, y: size * 0.78)
                    )
                    path.addLine(to: CGPoint(x: size * 0.02, y: size * 0.64))
                    path.addCurve(
                        to: CGPoint(x: size * 0.5, y: size * 1.0),
                        control1: CGPoint(x: size * 0.02, y: size * 0.84),
                        control2: CGPoint(x: size * 0.24, y: size * 1.0)
                    )
                }
                .fill(Color(red: 52/255, green: 168/255, blue: 83/255))

                // Yellow
                Path { path in
                    path.move(to: CGPoint(x: size * 0.14, y: size * 0.36))
                    path.addCurve(
                        to: CGPoint(x: size * 0.14, y: size * 0.64),
                        control1: CGPoint(x: size * 0.06, y: size * 0.44),
                        control2: CGPoint(x: size * 0.06, y: size * 0.56)
                    )
                    path.addLine(to: CGPoint(x: size * 0.02, y: size * 0.64))
                    path.addCurve(
                        to: CGPoint(x: size * 0.02, y: size * 0.36),
                        control1: CGPoint(x: -size * 0.02, y: size * 0.54),
                        control2: CGPoint(x: -size * 0.02, y: size * 0.46)
                    )
                }
                .fill(Color(red: 251/255, green: 188/255, blue: 5/255))

                // Red
                Path { path in
                    path.move(to: CGPoint(x: size * 0.5, y: size * 0.1))
                    path.addCurve(
                        to: CGPoint(x: size * 0.82, y: size * 0.28),
                        control1: CGPoint(x: size * 0.66, y: size * 0.1),
                        control2: CGPoint(x: size * 0.76, y: size * 0.16)
                    )
                    path.addLine(to: CGPoint(x: size * 0.68, y: size * 0.4))
                    path.addCurve(
                        to: CGPoint(x: size * 0.5, y: size * 0.26),
                        control1: CGPoint(x: size * 0.64, y: size * 0.32),
                        control2: CGPoint(x: size * 0.58, y: size * 0.26)
                    )
                    path.addCurve(
                        to: CGPoint(x: size * 0.14, y: size * 0.36),
                        control1: CGPoint(x: size * 0.34, y: size * 0.26),
                        control2: CGPoint(x: size * 0.2, y: size * 0.3)
                    )
                    path.addLine(to: CGPoint(x: size * 0.02, y: size * 0.36))
                    path.addCurve(
                        to: CGPoint(x: size * 0.5, y: size * 0.0),
                        control1: CGPoint(x: size * 0.08, y: size * 0.14),
                        control2: CGPoint(x: size * 0.28, y: size * 0.0)
                    )
                }
                .fill(Color(red: 234/255, green: 67/255, blue: 53/255))
            }
        }
    }
}

// MARK: - Movie Carousel

struct MovieCarousel: View {
    @State private var movies: [OnboardingMovie] = OnboardingMovie.sampleMovies
    @State private var currentIndex: Int = 2
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let cardWidth: CGFloat = 140
            let cardSpacing: CGFloat = 16

            ZStack {
                ForEach(Array(movies.enumerated()), id: \.element.id) { index, movie in
                    let offset = CGFloat(index - currentIndex)
                    let xOffset = offset * (cardWidth + cardSpacing) + dragOffset

                    // Calculate scale and opacity based on distance from center
                    let distance = abs(xOffset)
                    let maxDistance = cardWidth * 2
                    let scale = max(0.7, 1 - (distance / maxDistance) * 0.3)
                    let opacity = max(0.4, 1 - (distance / maxDistance) * 0.6)

                    MoviePosterCard(movie: movie, isCenter: index == currentIndex)
                        .frame(width: cardWidth, height: 220)
                        .scaleEffect(scale)
                        .opacity(opacity)
                        .offset(x: xOffset)
                        .zIndex(index == currentIndex ? 10 : Double(5 - abs(index - currentIndex)))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentIndex)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: dragOffset)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation.width
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 50
                        if value.translation.width < -threshold && currentIndex < movies.count - 1 {
                            currentIndex += 1
                        } else if value.translation.width > threshold && currentIndex > 0 {
                            currentIndex -= 1
                        }
                        dragOffset = 0
                    }
            )
        }
        .onAppear {
            startAutoScroll()
        }
    }

    private func startAutoScroll() {
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                currentIndex = (currentIndex + 1) % movies.count
            }
        }
    }
}

// MARK: - Movie Poster Card

struct MoviePosterCard: View {
    let movie: OnboardingMovie
    let isCenter: Bool
    @State private var isShimmering = false

    var body: some View {
        VStack(spacing: FFSpacing.sm) {
            // Poster
            ZStack {
                RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                    .fill(
                        LinearGradient(
                            colors: movie.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Film icon overlay
                Image(systemName: "film")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.3))

                // Shimmer effect for center card
                if isCenter {
                    RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                        .fill(
                            LinearGradient(
                                colors: [
                                    .clear,
                                    .white.opacity(0.2),
                                    .clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: isShimmering ? 200 : -200)
                        .animation(
                            .linear(duration: 2).repeatForever(autoreverses: false),
                            value: isShimmering
                        )
                        .mask(RoundedRectangle(cornerRadius: FFCornerRadius.medium))
                }

                // Gold border for center
                if isCenter {
                    RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                        .stroke(FFColors.goldPrimary.opacity(0.6), lineWidth: 2)
                }
            }
            .frame(height: 180)
            .shadow(
                color: isCenter ? FFColors.goldPrimary.opacity(0.4) : .black.opacity(0.3),
                radius: isCenter ? 16 : 8,
                y: isCenter ? 8 : 4
            )

            // Title
            VStack(spacing: 2) {
                Text(movie.title)
                    .font(FFTypography.movieTitle)
                    .foregroundColor(isCenter ? FFColors.textPrimary : FFColors.textSecondary)
                    .lineLimit(1)

                Text(movie.releaseDate)
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textTertiary)
            }
        }
        .onAppear {
            if isCenter {
                isShimmering = true
            }
        }
        .onChange(of: isCenter) { _, newValue in
            isShimmering = newValue
        }
    }
}

// MARK: - Onboarding Movie Model

struct OnboardingMovie: Identifiable {
    let id = UUID()
    let title: String
    let releaseDate: String
    let gradientColors: [Color]

    static let sampleMovies: [OnboardingMovie] = [
        OnboardingMovie(
            title: "Cosmic Voyage",
            releaseDate: "Feb 2026",
            gradientColors: [Color(hex: "1a1a2e"), Color(hex: "16213e"), Color(hex: "0f3460")]
        ),
        OnboardingMovie(
            title: "The Last Kingdom",
            releaseDate: "Mar 2026",
            gradientColors: [Color(hex: "2d132c"), Color(hex: "801336"), Color(hex: "c72c41")]
        ),
        OnboardingMovie(
            title: "Neon Dreams",
            releaseDate: "Apr 2026",
            gradientColors: [Color(hex: "0d0628"), Color(hex: "1a1a40"), Color(hex: "4a0080")]
        ),
        OnboardingMovie(
            title: "Ocean's Secret",
            releaseDate: "May 2026",
            gradientColors: [Color(hex: "0a192f"), Color(hex: "172a45"), Color(hex: "1f4068")]
        ),
        OnboardingMovie(
            title: "Golden Hour",
            releaseDate: "Jun 2026",
            gradientColors: [Color(hex: "1a1a1a"), Color(hex: "3d3d3d"), Color(hex: "4a3728")]
        )
    ]
}

// MARK: - Feature Row (kept for compatibility)

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
