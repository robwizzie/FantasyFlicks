//
//  HomeView.swift
//  FantasyFlicks
//
//  Main home screen showcasing the premium design system
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @StateObject private var seenService = SeenMoviesService.shared
    @StateObject private var friendsService = FriendsService.shared
    @StateObject private var authService = AuthenticationService.shared
    @ObservedObject private var navigationCoordinator = NavigationCoordinator.shared
    @State private var showNotifications = false
    @State private var animateHero = false
    @State private var scrollOffset: CGFloat = 0
    @State private var selectedMovie: FFMovie?
    @State private var showDraftRoom = false
    @State private var showDiary = false
    @State private var showWatched = false
    @State private var showWatchlist = false
    @State private var showRatings = false
    @State private var showForYou = false

    // User leagues from Firebase
    private var activeLeagues: [FFLeague] { viewModel.userLeagues }

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

                        // First thing a new account sees. Importing a watch
                        // history is what makes everything else work — Movie
                        // Night stops suggesting films they've seen, and
                        // recommendations switch on — so it leads until they
                        // have some data of their own.
                        if seenService.count == 0 {
                            LetterboxdConnectCard(
                                headline: "Start with your watch history",
                                message: "Connect Letterboxd to bring across everything you've watched and rated. Movie Night will stop suggesting films you've already seen, and your recommendations will actually know your taste."
                            )
                            .padding(.horizontal)
                        }

                        // Movie Night hero CTA
                        movieNightHeroSection

                        // Quick access to the user's own movie lists so they
                        // don't have to jump to the Profile tab for every
                        // Diary/Watched/Watchlist/Ratings open.
                        myMoviesHubSection

                        // Personalised picks. Renders nothing until the user
                        // has rated enough films for it to mean something.
                        ForYouRow(
                            onSelect: { selectedMovie = $0 },
                            onSeeAll: { showForYou = true }
                        )

                        // Other modes (Coming Soon)
                        quickActionsSection

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

                // Notifications bell hidden until real notification content exists.
                // Leave the @State and the NotificationsSheet in place so we can
                // re-enable this one line when we're ready.
            }
            .sheet(item: $selectedMovie) { movie in
                NavigationStack {
                    MovieDetailView(movie: movie)
                }
            }
            .sheet(isPresented: $showDiary) { DiaryView() }
            .sheet(isPresented: $showWatched) { WatchedMoviesSheet() }
            .sheet(isPresented: $showWatchlist) { WatchlistView() }
            .sheet(isPresented: $showRatings) { RatingsView() }
            .navigationDestination(isPresented: $showForYou) {
                ForYouView()
            }
            .navigationDestination(isPresented: $showDraftRoom) {
                if let activeDraft = viewModel.activeDraft {
                    if activeDraft.isOscarMode {
                        OscarDraftView(
                            draftId: activeDraft.draftId,
                            leagueId: activeDraft.leagueId,
                            leagueName: activeDraft.leagueName
                        )
                    } else {
                        DraftRoomView(
                            draftId: activeDraft.draftId,
                            leagueName: activeDraft.leagueName
                        )
                    }
                }
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
            VStack(spacing: FFSpacing.xs) {
                Text("Welcome back")
                    .font(FFTypography.bodyMedium)
                    .foregroundColor(FFColors.textSecondary)

                Text(heroGreeting)
                    .font(FFTypography.displaySmall)
                    .foregroundStyle(FFColors.goldGradient)
                    .multilineTextAlignment(.center)

                Text("What are we watching tonight?")
                    .font(FFTypography.bodySmall)
                    .foregroundColor(FFColors.textTertiary)
                    .padding(.top, 4)
            }
            .opacity(animateHero ? 1 : 0)
            .offset(y: animateHero ? 0 : 20)

            // Stats overview
            HStack(spacing: FFSpacing.xl) {
                StatBubble(
                    value: "\(seenService.count)",
                    label: "Watched",
                    icon: "eye.fill"
                )
                StatBubble(
                    value: "\(seenService.watchlist.count)",
                    label: "Watchlist",
                    icon: "bookmark.fill"
                )
                StatBubble(
                    value: "\(friendCount)",
                    label: friendCount == 1 ? "Friend" : "Friends",
                    icon: "person.2.fill"
                )
            }
            .opacity(animateHero ? 1 : 0)
            .offset(y: animateHero ? 0 : 30)
        }
        .padding(.horizontal)
        .task {
            await friendsService.refreshFriendList()
        }
        .onAppear {
            withAnimation(FFAnimations.smooth.delay(0.2)) {
                animateHero = true
            }
        }
    }

    /// "{first name}" or a gracious fallback.
    private var heroGreeting: String {
        if let user = authService.currentUser {
            let fullName = user.displayName.trimmingCharacters(in: .whitespaces)
            if !fullName.isEmpty {
                return fullName.components(separatedBy: .whitespaces).first ?? fullName
            }
            if !user.username.isEmpty {
                return user.username
            }
        }
        return "Movie Lover"
    }

    private var friendCount: Int {
        // Prefer the hydrated list count; fall back to the user's raw friendIds array
        let hydrated = friendsService.friends.count
        if hydrated > 0 { return hydrated }
        return authService.currentUser?.friendIds.count ?? 0
    }

    // MARK: - Active Draft Banner

    private var activeDraftBanner: some View {
        Group {
            if let activeDraft = viewModel.activeDraft {
                Button {
                    showDraftRoom = true
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

                            Text("\(activeDraft.leagueName) - \(activeDraft.isYourTurn ? "Your turn to pick!" : "Round \(activeDraft.currentRound)")")
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

    // MARK: - My Movies Hub (Dashboard)

    private var myMoviesHubSection: some View {
        VStack(alignment: .leading, spacing: FFSpacing.md) {
            HStack {
                Text("My Movies")
                    .font(FFTypography.headlineSmall)
                    .foregroundColor(FFColors.textPrimary)
                Spacer()
                Button {
                    navigationCoordinator.navigateTo(.profile)
                } label: {
                    HStack(spacing: 4) {
                        Text("Profile")
                            .font(FFTypography.labelSmall)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(FFColors.goldPrimary)
                }
            }
            .padding(.horizontal)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: FFSpacing.md),
                GridItem(.flexible(), spacing: FFSpacing.md),
                GridItem(.flexible(), spacing: FFSpacing.md),
                GridItem(.flexible(), spacing: FFSpacing.md)
            ], spacing: FFSpacing.md) {
                myMoviesTile(
                    icon: "book.closed.fill",
                    label: "Diary",
                    count: seenService.diary.count,
                    color: FFColors.goldPrimary
                ) { showDiary = true }

                myMoviesTile(
                    icon: "eye.fill",
                    label: "Watched",
                    count: seenService.count,
                    color: FFColors.success
                ) { showWatched = true }

                myMoviesTile(
                    icon: "bookmark.fill",
                    label: "Watchlist",
                    count: seenService.watchlist.count,
                    color: FFColors.ruby
                ) { showWatchlist = true }

                myMoviesTile(
                    icon: "star.fill",
                    label: "Ratings",
                    count: seenService.ratings.count,
                    color: FFColors.goldLight
                ) { showRatings = true }
            }
            .padding(.horizontal)
        }
    }

    private func myMoviesTile(icon: String, label: String, count: Int, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(color)
                Text("\(count)")
                    .font(FFTypography.titleSmall)
                    .foregroundColor(FFColors.textPrimary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(FFColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, FFSpacing.md)
            .background {
                RoundedRectangle(cornerRadius: FFCornerRadius.large)
                    .fill(FFColors.backgroundElevated.opacity(0.6))
                    .overlay {
                        RoundedRectangle(cornerRadius: FFCornerRadius.large)
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                    }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Movie Night Hero

    private var movieNightHeroSection: some View {
        VStack(spacing: FFSpacing.lg) {
            Button {
                navigationCoordinator.showMovieNightFlow()
            } label: {
                VStack(spacing: FFSpacing.lg) {
                    Image(systemName: "popcorn.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(FFColors.goldGradient)
                        .shadow(color: FFColors.goldPrimary.opacity(0.4), radius: 16, x: 0, y: 0)

                    VStack(spacing: FFSpacing.sm) {
                        Text("Movie Night")
                            .font(FFTypography.headlineLarge)
                            .foregroundColor(FFColors.textPrimary)

                        Text("Swipe to find your next watch")
                            .font(FFTypography.bodyMedium)
                            .foregroundColor(FFColors.textSecondary)
                    }

                    HStack(spacing: FFSpacing.sm) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("Start Movie Night")
                            .font(FFTypography.labelLarge)
                    }
                    .foregroundColor(FFColors.backgroundDark)
                    .padding(.horizontal, FFSpacing.xxl)
                    .padding(.vertical, FFSpacing.md)
                    .background(FFColors.goldGradient)
                    .clipShape(Capsule())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, FFSpacing.xxl)
                .background {
                    RoundedRectangle(cornerRadius: FFCornerRadius.xxl)
                        .fill(FFColors.backgroundElevated.opacity(0.6))
                        .overlay {
                            RoundedRectangle(cornerRadius: FFCornerRadius.xxl)
                                .stroke(FFColors.goldPrimary.opacity(0.3), lineWidth: 1)
                        }
                }
            }
            .buttonStyle(.plain)
            .pressEffect()
            .padding(.horizontal)
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: FFSpacing.md) {
            Text("More Modes")
                .font(FFTypography.headlineSmall)
                .foregroundColor(FFColors.textPrimary)
                .padding(.horizontal)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: FFSpacing.md) {
                QuickActionCard(
                    icon: "clock.fill",
                    title: "My Nights",
                    color: FFColors.ruby
                ) {
                    navigationCoordinator.navigateTo(.movieNights)
                }

                QuickActionCard(
                    icon: "person.2.fill",
                    title: "Friends",
                    color: FFColors.goldPrimary
                ) {
                    navigationCoordinator.navigateTo(.friends)
                }

                QuickActionCard(
                    icon: "magnifyingglass",
                    title: "Browse Movies",
                    color: FFColors.goldDark
                ) {
                    navigationCoordinator.navigateTo(.movies)
                }

                ComingSoonCard(
                    icon: "trophy.fill",
                    title: "Fantasy Leagues",
                    color: FFColors.goldLight
                )
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
                    // Leagues tab removed; this section is no longer called from the body.
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
                JoinLeagueCard(
                    onCreateTap: { },
                    onJoinTap: { }
                )
                    .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: FFSpacing.md) {
                        ForEach(activeLeagues.prefix(3)) { league in
                            NavigationLink {
                                LeagueDetailView(league: league)
                            } label: {
                                LeagueCard(league: league, compact: true)
                                    .frame(width: 300)
                            }
                            .buttonStyle(.plain)
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
                                selectedMovie = movie
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
                            selectedMovie = movie
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

// MARK: - Coming Soon Card

struct ComingSoonCard: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        VStack(spacing: FFSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                    .fill(color.opacity(0.08))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(color.opacity(0.4))
            }

            VStack(spacing: 4) {
                Text(title)
                    .font(FFTypography.labelSmall)
                    .foregroundColor(FFColors.textTertiary)
                    .lineLimit(1)

                Text("Coming Soon")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(FFColors.goldPrimary.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(FFColors.goldPrimary.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FFSpacing.lg)
        .background {
            RoundedRectangle(cornerRadius: FFCornerRadius.large)
                .fill(FFColors.backgroundElevated.opacity(0.3))
                .overlay {
                    RoundedRectangle(cornerRadius: FFCornerRadius.large)
                        .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                }
        }
        .opacity(0.6)
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
