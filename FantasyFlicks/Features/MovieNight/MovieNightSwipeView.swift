//
//  MovieNightSwipeView.swift
//  FantasyFlicks
//
//  The core Tinder-style swiping experience for Movie Night
//

import SwiftUI

struct MovieNightSwipeView: View {
    @ObservedObject var viewModel: MovieNightViewModel
    @State private var selectedMovieForDetail: FFMovie?
    /// When set, triggers a programmatic fly-off animation on the top card so
    /// tapping the check or X buttons shows the SKIP/WATCH stamp exactly like
    /// a real swipe does.
    @State private var pendingProgrammaticSwipe: SwipeDirection?

    var body: some View {
        ZStack {
            FFColors.backgroundDark.ignoresSafeArea()

            if viewModel.isLoading && viewModel.deckMovies.isEmpty {
                loadingView
            } else if viewModel.hasFinishedSwiping {
                waitingView
            } else {
                swipeContent
            }
        }
        .navigationTitle("Swipe!")
        .navigationBarTitleDisplayMode(.inline)
        // A Movie Night session should only be exited via the dedicated
        // controls — accidental swipes here would drop the user back into
        // the lobby mid-session. Hiding the back button plus the binding
        // setter in MovieNightEntryView (which refuses to reset the phase)
        // makes both the system back button and edge-swipe inert.
        .navigationBarBackButtonHidden(true)
        .disableInteractivePopGesture()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !viewModel.deckMovies.isEmpty {
                    // Clamp to the deck size so we never display something
                    // nonsensical like "40/25" if state gets out of sync.
                    let total = viewModel.deckMovies.count
                    let current = min(viewModel.currentCardIndex, total)
                    Text("\(current)/\(total)")
                        .font(FFTypography.labelMedium)
                        .foregroundColor(FFColors.textSecondary)
                }
            }
        }
        .sheet(item: $selectedMovieForDetail) { movie in
            NavigationStack {
                movieDetailSheet(movie: movie)
            }
        }
    }

    // MARK: - Swipe Content

    private var swipeContent: some View {
        VStack(spacing: 0) {
            // Progress bar
            progressBar
                .padding(.bottom, FFSpacing.sm)

            // Card stack — takes up available space
            CardStackView(
                movies: viewModel.deckMovies,
                currentIndex: viewModel.currentCardIndex,
                providers: viewModel.movieProviders,
                seenMovies: viewModel.seenMovieIds,
                watchlistMovies: SeenMoviesService.shared.watchlist,
                programmaticSwipe: $pendingProgrammaticSwipe,
                onSwipe: { direction in
                    Task { await viewModel.swipe(direction: direction) }
                },
                onToggleSeen: { tmdbId in
                    viewModel.toggleSeenIt(tmdbId: tmdbId)
                    if let movie = viewModel.deckMovies.first(where: { $0.tmdbId == tmdbId }) {
                        SeenMoviesService.shared.toggleSeen(movie)
                    } else {
                        SeenMoviesService.shared.toggleSeen(tmdbId: tmdbId)
                    }
                },
                onToggleWatchlist: { tmdbId in
                    if let movie = viewModel.deckMovies.first(where: { $0.tmdbId == tmdbId }) {
                        SeenMoviesService.shared.toggleWatchlist(movie)
                    } else {
                        SeenMoviesService.shared.toggleWatchlist(tmdbId: tmdbId)
                    }
                },
                onTapDetail: { movie in
                    selectedMovieForDetail = movie
                }
            )
            .padding(.horizontal, FFSpacing.lg)

            Spacer(minLength: FFSpacing.sm)

            // Action buttons
            actionButtons
                .padding(.bottom, FFSpacing.sm)

            // Participant progress
            participantProgressView
                .padding(.bottom, FFSpacing.sm)
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(FFColors.backgroundElevated)
                    .frame(height: 4)

                Capsule()
                    .fill(FFColors.goldGradientHorizontal)
                    .frame(width: geo.size.width * viewModel.swipeProgressFraction, height: 4)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.swipeProgressFraction)
            }
        }
        .frame(height: 4)
        .padding(.horizontal)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: FFSpacing.xl) {
            // Undo
            actionButton(
                icon: "arrow.uturn.backward",
                color: FFColors.textSecondary,
                size: 40
            ) {
                Task { await viewModel.undoLastSwipe() }
            }
            .opacity(viewModel.currentCardIndex > 0 ? 1 : 0.3)
            .disabled(viewModel.currentCardIndex == 0)

            // Skip (left swipe) — fires the stamp then advances
            actionButton(
                icon: "xmark",
                color: FFColors.ruby,
                size: 56
            ) {
                triggerProgrammaticSwipe(.left)
            }

            // Watchlist toggle for the current card
            actionButton(
                icon: currentMovieIsOnWatchlist ? "bookmark.fill" : "bookmark",
                color: currentMovieIsOnWatchlist ? FFColors.goldPrimary : FFColors.textTertiary,
                size: 40
            ) {
                if let movie = currentMovie {
                    SeenMoviesService.shared.toggleWatchlist(movie)
                }
            }

            // Want to watch (right swipe) — fires the stamp then advances
            actionButton(
                icon: "checkmark",
                color: FFColors.success,
                size: 56
            ) {
                triggerProgrammaticSwipe(.right)
            }
        }
        .padding(.horizontal, FFSpacing.xl)
    }

    /// Kick off the fly-off animation on the top card then let the view model
    /// advance once the animation is mostly complete. Matches what a real
    /// drag-swipe produces, including the SKIP/WATCH stamp.
    private func triggerProgrammaticSwipe(_ direction: SwipeDirection) {
        guard currentMovie != nil else { return }
        pendingProgrammaticSwipe = direction
    }

    private func actionButton(icon: String, color: Color, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundColor(color)
                .frame(width: size, height: size)
                .background {
                    Circle()
                        .fill(FFColors.backgroundElevated)
                        .overlay {
                            Circle()
                                .stroke(color.opacity(0.3), lineWidth: 2)
                        }
                }
                .shadow(color: color.opacity(0.15), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(ButtonPressEffect())
    }

    // MARK: - Participant Progress

    private var participantProgressView: some View {
        HStack(spacing: FFSpacing.md) {
            if let session = viewModel.session {
                ForEach(session.participantIds, id: \.self) { userId in
                    let swipeCount = viewModel.participantProgress[userId] ?? 0
                    let total = viewModel.deckMovies.count
                    let isDone = swipeCount >= total && total > 0
                    let name = session.participantNames[userId] ?? "?"

                    VStack(spacing: 3) {
                        Circle()
                            .fill(isDone ? FFColors.success : FFColors.backgroundElevated2)
                            .frame(width: 28, height: 28)
                            .overlay {
                                if isDone {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                } else {
                                    Text(String(name.prefix(1)).uppercased())
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(FFColors.textSecondary)
                                }
                            }

                        Text(total > 0 ? "\(swipeCount)/\(total)" : "0")
                            .font(.system(size: 10))
                            .foregroundColor(FFColors.textTertiary)
                    }
                }
            }
        }
    }

    // MARK: - Loading / Waiting States

    private var loadingView: some View {
        FullScreenLoadingView(message: "Building your deck…")
    }

    private var waitingView: some View {
        VStack(spacing: FFSpacing.xl) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(FFColors.success)

            Text("You're done!")
                .font(FFTypography.headlineLarge)
                .foregroundColor(FFColors.textPrimary)

            if viewModel.allParticipantsFinished {
                Text("Computing results…")
                    .font(FFTypography.bodyMedium)
                    .foregroundColor(FFColors.textSecondary)

                ProgressView()
                    .tint(FFColors.goldPrimary)
            } else {
                Text("Waiting for others to finish swiping…")
                    .font(FFTypography.bodyMedium)
                    .foregroundColor(FFColors.textSecondary)

                if let session = viewModel.session {
                    VStack(spacing: FFSpacing.sm) {
                        ForEach(session.participantIds, id: \.self) { userId in
                            let swipeCount = viewModel.participantProgress[userId] ?? 0
                            let total = viewModel.deckMovies.count
                            let isDone = swipeCount >= total && total > 0
                            let name = session.participantNames[userId] ?? "Player"

                            HStack {
                                Text(name)
                                    .font(FFTypography.labelMedium)
                                    .foregroundColor(FFColors.textPrimary)
                                Spacer()
                                if isDone {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(FFColors.success)
                                } else {
                                    Text("\(swipeCount)/\(total)")
                                        .font(FFTypography.labelSmall)
                                        .foregroundColor(FFColors.textTertiary)
                                }
                            }
                            .padding(.horizontal, FFSpacing.xxl)
                        }
                    }
                }

                // Host / solo users can always force results — don't let anyone
                // get stuck waiting on a flaky connection.
                if viewModel.isHost {
                    GoldButton(
                        title: "See Results Now",
                        icon: "sparkles",
                        style: .primary,
                        size: .medium
                    ) {
                        Task { await viewModel.finishNow() }
                    }
                    .padding(.horizontal, FFSpacing.xxl)
                    .padding(.top, FFSpacing.md)
                }
            }
        }
        .task {
            // If you're solo or everyone's already finished by the time we render
            // this view, transition to results automatically instead of making the
            // host tap a button.
            if viewModel.allParticipantsFinished && viewModel.isHost {
                await viewModel.finishNow()
            }
        }
    }

    // MARK: - Movie Detail Sheet

    private func movieDetailSheet(movie: FFMovie) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FFSpacing.lg) {
                if let backdropURL = movie.backdropURL {
                    CachedAsyncImage(url: backdropURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        FFColors.backgroundElevated
                    }
                    .frame(height: 220)
                    .clipped()
                }

                VStack(alignment: .leading, spacing: FFSpacing.md) {
                    Text(movie.title)
                        .font(FFTypography.headlineLarge)
                        .foregroundColor(FFColors.textPrimary)

                    HStack(spacing: FFSpacing.md) {
                        if let year = movie.year {
                            Text(String(year))
                                .font(FFTypography.labelMedium)
                                .foregroundColor(FFColors.textSecondary)
                        }
                        if movie.voteAverage > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(FFColors.goldPrimary)
                                    .font(.system(size: 14))
                                Text(String(format: "%.1f", movie.voteAverage))
                                    .font(FFTypography.labelMedium)
                                    .foregroundColor(FFColors.goldLight)
                            }
                        }
                        if let runtime = movie.formattedRuntime {
                            Text(runtime)
                                .font(FFTypography.labelSmall)
                                .foregroundColor(FFColors.textTertiary)
                        }
                    }

                    if !movie.genres.isEmpty {
                        HStack(spacing: FFSpacing.sm) {
                            ForEach(movie.genres.prefix(4)) { genre in
                                Text(genre.name)
                                    .font(FFTypography.labelSmall)
                                    .foregroundColor(FFColors.textPrimary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    if !movie.overview.isEmpty {
                        Text(movie.overview)
                            .font(FFTypography.bodyMedium)
                            .foregroundColor(FFColors.textSecondary)
                    }

                    if !movie.cast.isEmpty {
                        VStack(alignment: .leading, spacing: FFSpacing.sm) {
                            Text("Cast")
                                .font(FFTypography.headlineSmall)
                                .foregroundColor(FFColors.textPrimary)

                            ForEach(movie.cast.prefix(5), id: \.id) { member in
                                HStack {
                                    Text(member.name)
                                        .font(FFTypography.bodyMedium)
                                        .foregroundColor(FFColors.textPrimary)
                                    Text("as \(member.character)")
                                        .font(FFTypography.bodySmall)
                                        .foregroundColor(FFColors.textTertiary)
                                }
                            }
                        }
                    }

                    if let providers = viewModel.movieProviders[movie.tmdbId], !providers.isEmpty {
                        VStack(alignment: .leading, spacing: FFSpacing.sm) {
                            Text("Available On")
                                .font(FFTypography.headlineSmall)
                                .foregroundColor(FFColors.textPrimary)

                            HStack(spacing: FFSpacing.md) {
                                ForEach(providers) { provider in
                                    VStack(spacing: 4) {
                                        if let logoURL = provider.logoURL {
                                            CachedAsyncImage(url: logoURL) { image in
                                                image.resizable().aspectRatio(contentMode: .fit)
                                            } placeholder: {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(FFColors.backgroundElevated2)
                                            }
                                            .frame(width: 40, height: 40)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                        Text(provider.name)
                                            .font(FFTypography.caption)
                                            .foregroundColor(FFColors.textTertiary)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .background(FFColors.backgroundDark)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { selectedMovieForDetail = nil }
                    .foregroundColor(FFColors.goldPrimary)
            }
        }
    }

    // MARK: - Helpers

    private var currentMovie: FFMovie? {
        guard viewModel.currentCardIndex < viewModel.deckMovies.count else { return nil }
        return viewModel.deckMovies[viewModel.currentCardIndex]
    }

    private var currentMovieIsOnWatchlist: Bool {
        guard let movie = currentMovie else { return false }
        return SeenMoviesService.shared.isOnWatchlist(tmdbId: movie.tmdbId)
    }
}

// MARK: - Button Press Effect

struct ButtonPressEffect: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
