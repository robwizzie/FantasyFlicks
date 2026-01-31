//
//  HomeView.swift
//  FantasyFlicks
//
//  Main home screen showcasing the premium design system
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var showNotifications = false
    @State private var animateHero = false
    @State private var scrollOffset: CGFloat = 0

    // User leagues (placeholder until backend integration)
    private let activeLeagues: [FFLeague] = []

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                backgroundView

                // Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: FFSpacing.xxl) {
                        // API Token setup banner (if not configured)
                        if !APIConfiguration.TMDB.hasValidToken {
                            tokenSetupBanner
                        }

                        // Hero section with logo
                        heroSection

                        // Active draft alert (if any)
                        activeDraftBanner

                        // Quick actions
                        quickActionsSection

                        // Your leagues
                        yourLeaguesSection

                        // Upcoming movies carousel (real data)
                        upcomingMoviesSection

                        // Now playing movies (real data)
                        if !viewModel.nowPlayingMovies.isEmpty {
                            nowPlayingSection
                        }

                        // Bottom padding
                        Spacer(minLength: 100)
                    }
                    .padding(.top, FFSpacing.lg)
                }
                .refreshable {
                    await viewModel.refresh()
                }

                // Loading overlay for initial load
                if viewModel.isLoading && viewModel.upcomingMovies.isEmpty {
                    loadingOverlay
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Image("icon-no-bg")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 36)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNotifications = true
                    } label: {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 18))
                            .foregroundColor(FFColors.goldPrimary)
                    }
                }
            }
            .sheet(isPresented: $showNotifications) {
                NotificationsSheet()
            }
            .task {
                await viewModel.fetchHomeData()
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") { viewModel.error = nil }
            } message: {
                Text(viewModel.error ?? "")
            }
        }
    }

    private var loadingOverlay: some View {
        VStack(spacing: FFSpacing.lg) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(FFColors.goldPrimary)
            Text("Loading movies...")
                .font(FFTypography.bodyMedium)
                .foregroundColor(FFColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FFColors.backgroundDark.opacity(0.8))
    }

    // MARK: - Token Setup Banner

    private var tokenSetupBanner: some View {
        VStack(alignment: .leading, spacing: FFSpacing.md) {
            HStack(spacing: FFSpacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(FFColors.ruby)
                Text("TMDB API Token Required")
                    .font(FFTypography.labelMedium)
                    .foregroundColor(FFColors.textPrimary)
            }

            Text("To see real movie data, add your TMDB API token:")
                .font(FFTypography.bodySmall)
                .foregroundColor(FFColors.textSecondary)

            VStack(alignment: .leading, spacing: FFSpacing.xs) {
                Text("1. Go to themoviedb.org/settings/api")
                Text("2. Copy your API Read Access Token")
                Text("3. Open APIConfiguration.swift")
                Text("4. Paste it where indicated")
            }
            .font(FFTypography.caption)
            .foregroundColor(FFColors.textTertiary)
        }
        .padding(FFSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: FFCornerRadius.large)
                .fill(FFColors.backgroundElevated)
                .overlay {
                    RoundedRectangle(cornerRadius: FFCornerRadius.large)
                        .stroke(FFColors.ruby.opacity(0.3), lineWidth: 1)
                }
        }
        .padding(.horizontal)
    }

    // MARK: - Background

    private var backgroundView: some View {
        ZStack {
            FFColors.backgroundDark.ignoresSafeArea()

            // Subtle gradient glow at top
            VStack {
                EllipticalGradient(
                    colors: [
                        FFColors.goldPrimary.opacity(0.15),
                        FFColors.goldDark.opacity(0.05),
                        Color.clear
                    ],
                    center: .top,
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.5
                )
                .frame(height: 400)
                .blur(radius: 60)

                Spacer()
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: FFSpacing.lg) {
            // Welcome message
            VStack(spacing: FFSpacing.sm) {
                Text("Welcome back!")
                    .font(FFTypography.bodyMedium)
                    .foregroundColor(FFColors.textSecondary)

                Text("Fantasy Film League")
                    .font(FFTypography.displaySmall)
                    .foregroundStyle(FFColors.goldGradient)
            }
            .opacity(animateHero ? 1 : 0)
            .offset(y: animateHero ? 0 : 20)

            // Stats overview
            HStack(spacing: FFSpacing.xl) {
                StatBubble(value: "3", label: "Leagues", icon: "trophy.fill")
                StatBubble(value: "12", label: "Movies", icon: "film.fill")
                StatBubble(value: "#2", label: "Best Rank", icon: "medal.fill")
            }
            .opacity(animateHero ? 1 : 0)
            .offset(y: animateHero ? 0 : 30)
        }
        .padding(.horizontal)
        .onAppear {
            withAnimation(FFAnimations.smooth.delay(0.2)) {
                animateHero = true
            }
        }
    }

    // MARK: - Active Draft Banner

    private var activeDraftBanner: some View {
        Group {
            // Show if there's an active draft
            let activeLeague = activeLeagues.first { $0.draftStatus == .inProgress }
            if activeLeague != nil {
                Button {
                    // Navigate to draft
                } label: {
                    HStack(spacing: FFSpacing.md) {
                        // Live indicator
                        HStack(spacing: 6) {
                            Circle()
                                .fill(FFColors.ruby)
                                .frame(width: 8, height: 8)
                                .pulse(color: FFColors.ruby)

                            Text("LIVE")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(FFColors.ruby)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(FFColors.ruby.opacity(0.2))
                        .clipShape(Capsule())

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Draft in Progress")
                                .font(FFTypography.labelMedium)
                                .foregroundColor(FFColors.textPrimary)

                            Text("Sleeper Hits - Your turn to pick!")
                                .font(FFTypography.caption)
                                .foregroundColor(FFColors.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(FFColors.goldPrimary)
                    }
                    .padding(FFSpacing.md)
                    .background {
                        RoundedRectangle(cornerRadius: FFCornerRadius.large)
                            .fill(FFColors.backgroundElevated)
                            .overlay {
                                RoundedRectangle(cornerRadius: FFCornerRadius.large)
                                    .stroke(FFColors.ruby.opacity(0.3), lineWidth: 1)
                            }
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: FFSpacing.md) {
            Text("Quick Actions")
                .font(FFTypography.headlineSmall)
                .foregroundColor(FFColors.textPrimary)
                .padding(.horizontal)

            HStack(spacing: FFSpacing.md) {
                QuickActionCard(
                    icon: "plus.circle.fill",
                    title: "Create League",
                    color: FFColors.goldPrimary
                ) {
                    // Create league action
                }

                QuickActionCard(
                    icon: "person.badge.plus",
                    title: "Join League",
                    color: FFColors.goldLight
                ) {
                    // Join league action
                }

                QuickActionCard(
                    icon: "magnifyingglass",
                    title: "Browse Movies",
                    color: FFColors.ruby
                ) {
                    // Browse movies action
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Your Leagues

    private var yourLeaguesSection: some View {
        VStack(alignment: .leading, spacing: FFSpacing.md) {
            HStack {
                Text("Your Leagues")
                    .font(FFTypography.headlineSmall)
                    .foregroundColor(FFColors.textPrimary)

                Spacer()

                Button {
                    // See all leagues
                } label: {
                    HStack(spacing: 4) {
                        Text("See All")
                            .font(FFTypography.labelMedium)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(FFColors.goldPrimary)
                }
            }
            .padding(.horizontal)

            if activeLeagues.isEmpty {
                JoinLeagueCard(onCreateTap: {}, onJoinTap: {})
                    .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: FFSpacing.md) {
                        ForEach(activeLeagues.prefix(3)) { league in
                            LeagueCard(league: league, compact: true)
                                .frame(width: 300)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Upcoming Movies (Real TMDB Data)

    private var upcomingMoviesSection: some View {
        VStack(alignment: .leading, spacing: FFSpacing.md) {
            HStack {
                Text("Upcoming Releases")
                    .font(FFTypography.headlineSmall)
                    .foregroundColor(FFColors.textPrimary)

                Spacer()

                if viewModel.isLoadingUpcoming {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(FFColors.goldPrimary)
                }
            }
            .padding(.horizontal)

            if viewModel.upcomingMovies.isEmpty && !viewModel.isLoadingUpcoming {
                emptyStateCard(message: "No upcoming movies found")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: FFSpacing.md) {
                        ForEach(viewModel.upcomingMovies) { movie in
                            MoviePosterCard(movie: movie, size: .medium) {
                                // Navigate to movie detail
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Now Playing Movies (Real TMDB Data)

    private var nowPlayingSection: some View {
        VStack(alignment: .leading, spacing: FFSpacing.md) {
            HStack {
                Text("Now Playing")
                    .font(FFTypography.headlineSmall)
                    .foregroundColor(FFColors.textPrimary)

                Spacer()

                if viewModel.isLoadingNowPlaying {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(FFColors.goldPrimary)
                }
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FFSpacing.md) {
                    ForEach(viewModel.nowPlayingMovies) { movie in
                        MoviePosterCard(movie: movie, size: .medium) {
                            // Navigate to movie detail
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func emptyStateCard(message: String) -> some View {
        HStack {
            Spacer()
            VStack(spacing: FFSpacing.sm) {
                Image(systemName: "film")
                    .font(.system(size: 32))
                    .foregroundColor(FFColors.textTertiary)
                Text(message)
                    .font(FFTypography.bodyMedium)
                    .foregroundColor(FFColors.textSecondary)
            }
            .padding(.vertical, FFSpacing.xxl)
            Spacer()
        }
        .padding(.horizontal)
    }
}

// MARK: - Stat Bubble

struct StatBubble: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: FFSpacing.sm) {
            ZStack {
                Circle()
                    .fill(FFColors.goldPrimary.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(FFColors.goldGradient)
            }

            VStack(spacing: 2) {
                Text(value)
                    .font(FFTypography.titleMedium)
                    .foregroundColor(FFColors.textPrimary)

                Text(label)
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textSecondary)
            }
        }
    }
}

// MARK: - Quick Action Card

struct QuickActionCard: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: FFSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                        .fill(color.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(color)
                }

                Text(title)
                    .font(FFTypography.labelSmall)
                    .foregroundColor(FFColors.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, FFSpacing.lg)
            .background {
                RoundedRectangle(cornerRadius: FFCornerRadius.large)
                    .fill(FFColors.backgroundElevated.opacity(0.6))
                    .overlay {
                        RoundedRectangle(cornerRadius: FFCornerRadius.large)
                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                    }
            }
        }
        .buttonStyle(.plain)
        .pressEffect()
    }
}

// MARK: - Notifications Sheet

struct NotificationsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: FFSpacing.md) {
                        ForEach(FFNotification.sampleNotifications) { notification in
                            NotificationRow(notification: notification)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(FFColors.goldPrimary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Notification Row

struct NotificationRow: View {
    let notification: FFNotification

    var body: some View {
        HStack(alignment: .top, spacing: FFSpacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: notification.icon)
                    .font(.system(size: 16))
                    .foregroundColor(accentColor)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(FFTypography.labelMedium)
                    .foregroundColor(notification.isRead ? FFColors.textSecondary : FFColors.textPrimary)

                Text(notification.message)
                    .font(FFTypography.bodySmall)
                    .foregroundColor(FFColors.textSecondary)
                    .lineLimit(2)

                Text(notification.timeAgo)
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textTertiary)
            }

            Spacer()

            // Unread indicator
            if !notification.isRead {
                Circle()
                    .fill(FFColors.goldPrimary)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(FFSpacing.md)
        .background {
            RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                .fill(notification.isRead ? Color.clear : FFColors.backgroundElevated.opacity(0.5))
        }
    }

    private var accentColor: Color {
        switch notification.type {
        case .yourTurnToPick, .draftStartingSoon: return FFColors.ruby
        case .achievementUnlocked, .draftCompleted: return FFColors.goldPrimary
        default: return FFColors.textSecondary
        }
    }
}

// MARK: - Preview

#Preview {
    HomeView()
        .ffTheme()
}
