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
import Combine

// MARK: - Onboarding ViewModel

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var upcomingMovies: [TMDBMovie] = []
    @Published var isLoading = false
    @Published var error: String?

    private let tmdbService = TMDBService.shared

    func loadUpcomingBlockbusters() async {
        guard upcomingMovies.isEmpty else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            // Fetch upcoming blockbusters using discover endpoint
            // This gets high-profile theatrical releases sorted by popularity
            let response = try await tmdbService.getUpcomingBlockbusters(page: 1)

            // Filter for movies with posters (already sorted by popularity from API)
            let blockbusters = response.results
                .filter { $0.posterPath != nil }

            // Take top 7 for the carousel
            upcomingMovies = Array(blockbusters.prefix(7))
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct OnboardingView: View {
    @StateObject private var authService = AuthenticationService.shared
    @StateObject private var viewModel = OnboardingViewModel()
    @State private var currentPage = 0
    @State private var visiblePage = 0 // Tracks which page is fully visible (for content loading)

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
                .onChange(of: currentPage) { _, newPage in
                    // Only update visible page when transition completes
                    // This prevents content from appearing mid-swipe
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        visiblePage = newPage
                    }
                }
            }
            .task {
                await viewModel.loadUpcomingBlockbusters()
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
                Text("Coming Soon")
                    .font(FFTypography.overline)
                    .foregroundColor(FFColors.goldPrimary)
                    .tracking(2)
                    .textCase(.uppercase)

                Text("Discover & Draft")
                    .font(FFTypography.displaySmall)
                    .foregroundStyle(FFColors.goldGradient)
            }

            // Movie Carousel - only show content when page is fully visible
            if visiblePage == 1 || currentPage == 1 {
                OnboardingMovieCarousel(movies: viewModel.upcomingMovies)
                    .frame(height: 340)
                    .opacity(visiblePage == 1 ? 1 : 0)
                    .animation(.easeIn(duration: 0.2), value: visiblePage)
            } else {
                // Placeholder to maintain layout
                Color.clear
                    .frame(height: 340)
            }

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

// MARK: - Google Logo (Official SVG)

struct GoogleLogo: View {
    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width, geometry.size.height) / 48.0

            ZStack {
                // Red path (top-right arc)
                Path { path in
                    path.move(to: CGPoint(x: 24 * scale, y: 9.5 * scale))
                    path.addCurve(
                        to: CGPoint(x: 33.21 * scale, y: 13.1 * scale),
                        control1: CGPoint(x: 27.54 * scale, y: 9.5 * scale),
                        control2: CGPoint(x: 30.71 * scale, y: 10.72 * scale)
                    )
                    path.addLine(to: CGPoint(x: 40.06 * scale, y: 6.25 * scale))
                    path.addCurve(
                        to: CGPoint(x: 24 * scale, y: 0),
                        control1: CGPoint(x: 35.9 * scale, y: 2.38 * scale),
                        control2: CGPoint(x: 30.47 * scale, y: 0)
                    )
                    path.addCurve(
                        to: CGPoint(x: 2.56 * scale, y: 13.22 * scale),
                        control1: CGPoint(x: 14.62 * scale, y: 0),
                        control2: CGPoint(x: 6.51 * scale, y: 5.38 * scale)
                    )
                    path.addLine(to: CGPoint(x: 10.54 * scale, y: 19.41 * scale))
                    path.addCurve(
                        to: CGPoint(x: 24 * scale, y: 9.5 * scale),
                        control1: CGPoint(x: 12.43 * scale, y: 13.72 * scale),
                        control2: CGPoint(x: 17.74 * scale, y: 9.5 * scale)
                    )
                    path.closeSubpath()
                }
                .fill(Color(red: 234/255, green: 67/255, blue: 53/255))

                // Blue path (right side with bar)
                Path { path in
                    path.move(to: CGPoint(x: 46.98 * scale, y: 24.55 * scale))
                    path.addCurve(
                        to: CGPoint(x: 46.6 * scale, y: 20 * scale),
                        control1: CGPoint(x: 46.98 * scale, y: 22.98 * scale),
                        control2: CGPoint(x: 46.83 * scale, y: 21.46 * scale)
                    )
                    path.addLine(to: CGPoint(x: 24 * scale, y: 20 * scale))
                    path.addLine(to: CGPoint(x: 24 * scale, y: 29.02 * scale))
                    path.addLine(to: CGPoint(x: 36.94 * scale, y: 29.02 * scale))
                    path.addCurve(
                        to: CGPoint(x: 32.16 * scale, y: 36.2 * scale),
                        control1: CGPoint(x: 36.36 * scale, y: 31.98 * scale),
                        control2: CGPoint(x: 34.68 * scale, y: 34.5 * scale)
                    )
                    path.addLine(to: CGPoint(x: 39.89 * scale, y: 42.2 * scale))
                    path.addCurve(
                        to: CGPoint(x: 46.98 * scale, y: 24.55 * scale),
                        control1: CGPoint(x: 44.4 * scale, y: 38.02 * scale),
                        control2: CGPoint(x: 46.98 * scale, y: 31.91 * scale)
                    )
                    path.closeSubpath()
                }
                .fill(Color(red: 66/255, green: 133/255, blue: 244/255))

                // Yellow path (left side)
                Path { path in
                    path.move(to: CGPoint(x: 10.53 * scale, y: 28.59 * scale))
                    path.addCurve(
                        to: CGPoint(x: 9.77 * scale, y: 24 * scale),
                        control1: CGPoint(x: 10.05 * scale, y: 27.14 * scale),
                        control2: CGPoint(x: 9.77 * scale, y: 25.6 * scale)
                    )
                    path.addCurve(
                        to: CGPoint(x: 10.53 * scale, y: 19.41 * scale),
                        control1: CGPoint(x: 9.77 * scale, y: 22.4 * scale),
                        control2: CGPoint(x: 10.04 * scale, y: 20.86 * scale)
                    )
                    path.addLine(to: CGPoint(x: 2.55 * scale, y: 13.22 * scale))
                    path.addCurve(
                        to: CGPoint(x: 0, y: 24 * scale),
                        control1: CGPoint(x: 0.92 * scale, y: 16.46 * scale),
                        control2: CGPoint(x: 0, y: 20.12 * scale)
                    )
                    path.addCurve(
                        to: CGPoint(x: 2.56 * scale, y: 34.78 * scale),
                        control1: CGPoint(x: 0, y: 27.88 * scale),
                        control2: CGPoint(x: 0.92 * scale, y: 31.54 * scale)
                    )
                    path.addLine(to: CGPoint(x: 10.53 * scale, y: 28.59 * scale))
                    path.closeSubpath()
                }
                .fill(Color(red: 251/255, green: 188/255, blue: 5/255))

                // Green path (bottom)
                Path { path in
                    path.move(to: CGPoint(x: 24 * scale, y: 48 * scale))
                    path.addCurve(
                        to: CGPoint(x: 39.89 * scale, y: 42.19 * scale),
                        control1: CGPoint(x: 30.48 * scale, y: 48 * scale),
                        control2: CGPoint(x: 35.93 * scale, y: 45.87 * scale)
                    )
                    path.addLine(to: CGPoint(x: 32.16 * scale, y: 36.19 * scale))
                    path.addCurve(
                        to: CGPoint(x: 24 * scale, y: 38.49 * scale),
                        control1: CGPoint(x: 30.01 * scale, y: 37.64 * scale),
                        control2: CGPoint(x: 27.24 * scale, y: 38.49 * scale)
                    )
                    path.addCurve(
                        to: CGPoint(x: 10.53 * scale, y: 28.58 * scale),
                        control1: CGPoint(x: 17.74 * scale, y: 38.49 * scale),
                        control2: CGPoint(x: 12.43 * scale, y: 34.27 * scale)
                    )
                    path.addLine(to: CGPoint(x: 2.55 * scale, y: 34.77 * scale))
                    path.addCurve(
                        to: CGPoint(x: 24 * scale, y: 48 * scale),
                        control1: CGPoint(x: 6.51 * scale, y: 42.62 * scale),
                        control2: CGPoint(x: 14.62 * scale, y: 48 * scale)
                    )
                    path.closeSubpath()
                }
                .fill(Color(red: 52/255, green: 168/255, blue: 83/255))
            }
        }
    }
}

// MARK: - Onboarding Movie Carousel

struct OnboardingMovieCarousel: View {
    let movies: [TMDBMovie]
    @State private var currentIndex: Int = 0
    @State private var dragOffset: CGFloat = 0
    @State private var autoScrollTimer: Timer?
    @State private var userHasInteracted = false

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

                    OnboardingMoviePosterCard(movie: movie, isCenter: index == currentIndex)
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
                        // Stop auto-scrolling when user starts swiping
                        if !userHasInteracted {
                            userHasInteracted = true
                            stopAutoScroll()
                        }
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
            // Start in the middle if we have enough movies
            if movies.count > 2 {
                currentIndex = movies.count / 2
            }
            startAutoScroll()
        }
        .onDisappear {
            stopAutoScroll()
        }
    }

    private func startAutoScroll() {
        guard !userHasInteracted else { return }
        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            guard !movies.isEmpty else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                currentIndex = (currentIndex + 1) % movies.count
            }
        }
    }

    private func stopAutoScroll() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
    }
}

// MARK: - Onboarding Movie Poster Card

struct OnboardingMoviePosterCard: View {
    let movie: TMDBMovie
    let isCenter: Bool
    @State private var isShimmering = false

    private var posterURL: URL? {
        guard let path = movie.posterPath else { return nil }
        return URL(string: "\(APIConfiguration.TMDB.imageBaseURL)/\(APIConfiguration.TMDB.PosterSize.medium.rawValue)\(path)")
    }

    private var formattedReleaseDate: String {
        guard let date = movie.releaseDate else { return "Coming Soon" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(spacing: FFSpacing.sm) {
            // Poster
            ZStack {
                // Actual movie poster
                AsyncImage(url: posterURL) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                            .fill(FFColors.backgroundElevated)
                            .overlay {
                                ProgressView()
                                    .tint(FFColors.goldPrimary)
                            }
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 140, height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))
                    case .failure:
                        RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "1a1a2e"), Color(hex: "16213e")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay {
                                Image(systemName: "film")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white.opacity(0.3))
                            }
                    @unknown default:
                        EmptyView()
                    }
                }

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

                Text(formattedReleaseDate)
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
