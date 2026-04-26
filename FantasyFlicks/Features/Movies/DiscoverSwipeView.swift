//
//  DiscoverSwipeView.swift
//  FantasyFlicks
//
//  Endless swipe-to-discover that fuels a user's own account. Right swipe
//  = "I want to watch this" (adds to watchlist), left swipe = skip, and the
//  "Seen" corner pill marks a card as already watched. Feeds never run out
//  — the view fetches more TMDB pages as the user swipes through.
//

import SwiftUI

struct DiscoverSwipeView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var seenService = SeenMoviesService.shared

    @State private var movies: [FFMovie] = []
    @State private var currentIndex: Int = 0
    @State private var nextPage: Int = 1
    @State private var isLoading = false
    @State private var showFilters = false
    @State private var filters = DiscoverFilters()
    @State private var pendingProgrammaticSwipe: SwipeDirection?
    @State private var selectedDetail: FFMovie?

    var body: some View {
        ZStack {
            FFColors.backgroundDark.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal)
                    .padding(.top, FFSpacing.md)

                if movies.isEmpty && isLoading {
                    Spacer()
                    ProgressView().tint(FFColors.goldPrimary)
                    Spacer()
                } else if movies.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    CardStackView(
                        movies: movies,
                        currentIndex: currentIndex,
                        providers: [:],
                        seenMovies: seenService.seenTmdbIds,
                        watchlistMovies: seenService.watchlist,
                        programmaticSwipe: $pendingProgrammaticSwipe,
                        onSwipe: { direction in
                            handleSwipe(direction)
                        },
                        onToggleSeen: { tmdbId in
                            if let movie = movies.first(where: { $0.tmdbId == tmdbId }) {
                                seenService.toggleSeen(movie)
                            }
                        },
                        onToggleWatchlist: { tmdbId in
                            if let movie = movies.first(where: { $0.tmdbId == tmdbId }) {
                                seenService.toggleWatchlist(movie)
                            }
                        },
                        onTapDetail: { movie in selectedDetail = movie }
                    )
                    .padding(.horizontal, FFSpacing.lg)
                    .padding(.vertical, FFSpacing.md)

                    actionButtons
                        .padding(.bottom, FFSpacing.md)
                }
            }
        }
        .navigationTitle("Discover")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showFilters = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(FFColors.goldPrimary)
                }
            }
        }
        .sheet(isPresented: $showFilters) {
            DiscoverFiltersSheet(filters: $filters) {
                Task { await reload() }
            }
        }
        .sheet(item: $selectedDetail) { movie in
            NavigationStack { MovieDetailView(movie: movie) }
        }
        .task {
            if movies.isEmpty { await loadMore() }
        }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Keep swiping to fill your account")
                .font(FFTypography.caption)
                .foregroundColor(FFColors.textTertiary)
            HStack {
                Text("Swipe right to save · Left to skip · Tap ✓ if you've seen it")
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textSecondary)
                Spacer()
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: FFSpacing.xl) {
            actionButton(icon: "xmark", color: FFColors.ruby, size: 56) {
                pendingProgrammaticSwipe = .left
            }

            actionButton(
                icon: currentMovieIsSeen ? "eye.fill" : "eye",
                color: currentMovieIsSeen ? FFColors.goldPrimary : FFColors.textTertiary,
                size: 44
            ) {
                guard let movie = currentMovie else { return }
                seenService.toggleSeen(movie)
            }

            actionButton(icon: "checkmark", color: FFColors.success, size: 56) {
                pendingProgrammaticSwipe = .right
            }
        }
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
                        .overlay { Circle().stroke(color.opacity(0.3), lineWidth: 2) }
                }
        }
        .buttonStyle(ButtonPressEffect())
    }

    private var emptyState: some View {
        VStack(spacing: FFSpacing.lg) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(FFColors.goldPrimary)
            Text("No more movies matching your filters")
                .font(FFTypography.titleMedium)
                .foregroundColor(FFColors.textSecondary)
            Button {
                showFilters = true
            } label: {
                Text("Adjust Filters")
                    .font(FFTypography.labelMedium)
                    .foregroundColor(FFColors.goldPrimary)
                    .padding(.horizontal, FFSpacing.lg)
                    .padding(.vertical, 8)
                    .background(FFColors.goldPrimary.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .padding()
    }

    // MARK: - Helpers

    private var currentMovie: FFMovie? {
        guard currentIndex < movies.count else { return nil }
        return movies[currentIndex]
    }

    private var currentMovieIsSeen: Bool {
        guard let movie = currentMovie else { return false }
        return seenService.seenTmdbIds.contains(movie.tmdbId)
    }

    private func handleSwipe(_ direction: SwipeDirection) {
        guard let movie = currentMovie else { return }
        if direction == .right {
            // Add to watchlist unless already marked seen — in which case
            // leave it be (they already have an opinion).
            if !seenService.seenTmdbIds.contains(movie.tmdbId) {
                seenService.addToWatchlist(movie)
            }
        }
        currentIndex += 1
        // Fetch ahead before the deck dries up.
        if currentIndex >= movies.count - 5 {
            Task { await loadMore() }
        }
    }

    private func reload() async {
        movies = []
        currentIndex = 0
        nextPage = 1
        await loadMore()
    }

    private func loadMore() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        let pageToFetch = nextPage
        do {
            let response = try await TMDBService.shared.discoverForMovieNight(
                filters: filters.asMovieNightFilters(),
                page: pageToFetch
            )
            let newMovies = response.results
                .filter { !seenIds.contains($0.id) && !alreadyInDeck($0.id) }
                .map { TMDBService.shared.convertToFFMovie($0) }
            movies.append(contentsOf: newMovies)
            nextPage = pageToFetch + 1
        } catch {
            // Silently swallow — feed can recover on the next swipe.
        }
    }

    private var seenIds: Set<Int> {
        // Only filter things already in seen when the user opted to hide them.
        filters.excludeSeen ? seenService.seenTmdbIds : []
    }

    private func alreadyInDeck(_ tmdbId: Int) -> Bool {
        movies.contains { $0.tmdbId == tmdbId }
    }
}

// MARK: - Filters

struct DiscoverFilters {
    var genreIds: Set<Int> = []
    var minRating: Double = 6.0
    var minimumYear: Int? = nil
    var excludeSeen: Bool = true

    func asMovieNightFilters() -> MovieNightFilters {
        MovieNightFilters(
            genreIds: Array(genreIds),
            watchProviderIds: [],
            watchRegion: "US",
            minVoteAverage: minRating,
            includeNowPlaying: true,
            includeTrending: true,
            deckSize: 100,
            excludeSeenMode: excludeSeen ? .mineOnly : .none,
            minimumYear: minimumYear,
            excludeShorts: true
        )
    }
}

// MARK: - Filters Sheet

struct DiscoverFiltersSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filters: DiscoverFilters
    let onApply: () -> Void

    private let genreOptions: [(id: Int, name: String)] = [
        (28, "Action"), (12, "Adventure"), (16, "Animation"),
        (35, "Comedy"), (18, "Drama"), (14, "Fantasy"),
        (27, "Horror"), (10749, "Romance"), (878, "Sci-Fi"),
        (53, "Thriller"), (10752, "War"), (37, "Western"),
        (80, "Crime"), (99, "Documentary"), (36, "History"),
        (9648, "Mystery"), (10402, "Music"), (10751, "Family")
    ]

    private let yearPresets: [(label: String, minYear: Int?)] = [
        ("Any year", nil), ("2020+", 2020), ("2010+", 2010),
        ("2000+", 2000), ("1990+", 1990), ("1970+", 1970)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: FFSpacing.xl) {
                        genresSection
                        yearSection
                        ratingSection
                        toggleSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(FFColors.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") {
                        onApply()
                        dismiss()
                    }
                    .foregroundColor(FFColors.goldPrimary)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var genresSection: some View {
        VStack(alignment: .leading, spacing: FFSpacing.sm) {
            Text("Genres")
                .font(FFTypography.headlineSmall)
                .foregroundColor(FFColors.textPrimary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: FFSpacing.sm) {
                ForEach(genreOptions, id: \.id) { genre in
                    Button {
                        if filters.genreIds.contains(genre.id) {
                            filters.genreIds.remove(genre.id)
                        } else {
                            filters.genreIds.insert(genre.id)
                        }
                    } label: {
                        Text(genre.name)
                            .font(FFTypography.labelSmall)
                            .foregroundColor(filters.genreIds.contains(genre.id) ? FFColors.backgroundDark : FFColors.textPrimary)
                            .padding(.horizontal, FFSpacing.md)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(filters.genreIds.contains(genre.id) ? FFColors.goldPrimary : FFColors.backgroundElevated)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var yearSection: some View {
        VStack(alignment: .leading, spacing: FFSpacing.sm) {
            Text("Release Year")
                .font(FFTypography.headlineSmall)
                .foregroundColor(FFColors.textPrimary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FFSpacing.sm) {
                    ForEach(yearPresets, id: \.label) { preset in
                        Button {
                            filters.minimumYear = preset.minYear
                        } label: {
                            Text(preset.label)
                                .font(FFTypography.labelSmall)
                                .foregroundColor(filters.minimumYear == preset.minYear ? FFColors.backgroundDark : FFColors.textPrimary)
                                .padding(.horizontal, FFSpacing.md)
                                .padding(.vertical, 8)
                                .background(filters.minimumYear == preset.minYear ? FFColors.goldPrimary : FFColors.backgroundElevated)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: FFSpacing.sm) {
            HStack {
                Text("Minimum TMDB rating")
                    .font(FFTypography.headlineSmall)
                    .foregroundColor(FFColors.textPrimary)
                Spacer()
                Text(String(format: "%.1f+", filters.minRating))
                    .font(FFTypography.labelMedium)
                    .foregroundColor(FFColors.goldPrimary)
            }
            Slider(value: $filters.minRating, in: 0...9, step: 0.5)
                .tint(FFColors.goldPrimary)
        }
    }

    private var toggleSection: some View {
        VStack(alignment: .leading, spacing: FFSpacing.sm) {
            Toggle(isOn: $filters.excludeSeen) {
                Text("Skip movies I've already seen")
                    .font(FFTypography.bodyMedium)
                    .foregroundColor(FFColors.textPrimary)
            }
            .tint(FFColors.goldPrimary)
        }
    }
}
