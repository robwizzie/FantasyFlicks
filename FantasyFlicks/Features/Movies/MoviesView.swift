//
//  MoviesView.swift
//  FantasyFlicks
//
//  Movies tab - browse and search movies
//

import SwiftUI

struct MoviesView: View {
    @StateObject private var viewModel = MoviesViewModel()
    @StateObject private var listsService = MovieListsService.shared
    @State private var searchText = ""
    @State private var showFilters = false
    @State private var selectedMovie: FFMovie?
    @State private var selectedMode: BrowseMode = .collections
    @State private var showDiscover = false
    @State private var showCreateList = false
    @State private var openListId: String?

    enum BrowseMode: String, CaseIterable, Identifiable {
        case collections = "Collections"
        case years = "By Year"
        var id: String { rawValue }
    }

    private let years = Array((1970...2027).reversed())
    private let genres = [
        (28, "Action"),
        (12, "Adventure"),
        (16, "Animation"),
        (35, "Comedy"),
        (18, "Drama"),
        (14, "Fantasy"),
        (27, "Horror"),
        (878, "Sci-Fi"),
        (53, "Thriller")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: FFSpacing.xl) {
                        // Always-visible Discover call-to-action — primary
                        // onboarding path for new users ("swipe to tell us
                        // what you've seen").
                        discoverHero

                        if !searchText.isEmpty {
                            searchResultsSection
                        } else {
                            modeSwitcher

                            switch selectedMode {
                            case .collections:
                                collectionsSection
                            case .years:
                                yearsSection
                            }
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.vertical)
                }
                .refreshable {
                    await viewModel.fetchMovies()
                }

                // Loading overlay
                if viewModel.isLoading && viewModel.movies.isEmpty && selectedMode == .years {
                    loadingOverlay
                }
            }
            .navigationTitle("Movies")
            .searchable(text: $searchText, prompt: "Search movies")
            .onChange(of: searchText) { _, newValue in
                Task {
                    if newValue.isEmpty {
                        viewModel.clearSearch()
                    } else {
                        try? await Task.sleep(nanoseconds: 300_000_000) // Debounce
                        if searchText == newValue {
                            await viewModel.searchMovies(query: newValue)
                        }
                    }
                }
            }
            .task {
                if viewModel.movies.isEmpty {
                    await viewModel.fetchMovies()
                }
            }
            .sheet(item: $selectedMovie) { movie in
                NavigationStack {
                    MovieDetailView(movie: movie)
                }
            }
            .navigationDestination(isPresented: $showDiscover) {
                DiscoverSwipeView()
            }
            .navigationDestination(isPresented: Binding(
                get: { openListId != nil },
                set: { if !$0 { openListId = nil } }
            )) {
                if let id = openListId {
                    MovieListDetailView(listId: id)
                }
            }
            .sheet(isPresented: $showCreateList) {
                CreateMovieListSheet { newList in
                    openListId = newList.id
                }
            }
        }
    }

    // MARK: - Mode switcher

    private var modeSwitcher: some View {
        Picker("Mode", selection: $selectedMode) {
            ForEach(BrowseMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    // MARK: - Discover hero

    private var discoverHero: some View {
        Button { showDiscover = true } label: {
            HStack(spacing: FFSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                        .fill(FFColors.goldPrimary.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.system(size: 22))
                        .foregroundColor(FFColors.goldPrimary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Discover")
                        .font(FFTypography.titleSmall)
                        .foregroundColor(FFColors.textPrimary)
                    Text("Endless swipes to build your account")
                        .font(FFTypography.caption)
                        .foregroundColor(FFColors.textTertiary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(FFColors.goldPrimary)
            }
            .padding(FFSpacing.md)
            .background {
                RoundedRectangle(cornerRadius: FFCornerRadius.large)
                    .fill(FFColors.backgroundElevated.opacity(0.6))
                    .overlay {
                        RoundedRectangle(cornerRadius: FFCornerRadius.large)
                            .stroke(FFColors.goldPrimary.opacity(0.3), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    // MARK: - Collections

    private var collectionsSection: some View {
        VStack(alignment: .leading, spacing: FFSpacing.md) {
            HStack {
                Text("Collections")
                    .font(FFTypography.headlineSmall)
                    .foregroundColor(FFColors.textPrimary)
                Spacer()
                Button {
                    showCreateList = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill").font(.system(size: 12))
                        Text("New")
                    }
                    .font(FFTypography.labelSmall)
                    .foregroundColor(FFColors.goldPrimary)
                }
            }
            .padding(.horizontal)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: FFSpacing.md),
                GridItem(.flexible(), spacing: FFSpacing.md)
            ], spacing: FFSpacing.md) {
                ForEach(listsService.allVisibleLists) { list in
                    Button {
                        openListId = list.id
                    } label: {
                        CollectionTile(list: list)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Years

    private var yearsSection: some View {
        VStack(spacing: FFSpacing.xl) {
            yearSelector
            genreFilter
            if let featured = viewModel.featuredMovie {
                FeaturedMovieCard(movie: featured) {
                    selectedMovie = featured
                }
                .id(featured.id)
                .padding(.horizontal)
            }
            movieGrid
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

    private var yearSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FFSpacing.sm) {
                ForEach(years, id: \.self) { year in
                    Button {
                        Task {
                            await viewModel.changeYear(year)
                        }
                    } label: {
                        Text(String(year))
                            .font(FFTypography.labelMedium)
                            .foregroundColor(viewModel.selectedYear == year ? FFColors.backgroundDark : FFColors.textSecondary)
                            .padding(.horizontal, FFSpacing.lg)
                            .padding(.vertical, FFSpacing.sm)
                            .background {
                                if viewModel.selectedYear == year {
                                    Capsule().fill(FFColors.goldGradientHorizontal)
                                } else {
                                    Capsule()
                                        .fill(FFColors.backgroundElevated)
                                        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    private var genreFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FFSpacing.sm) {
                FilterChip(title: "All", isSelected: viewModel.selectedGenre == nil) {
                    viewModel.selectedGenre = nil
                }

                ForEach(genres, id: \.0) { genre in
                    FilterChip(title: genre.1, isSelected: viewModel.selectedGenre == genre.0) {
                        viewModel.selectedGenre = genre.0
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: FFSpacing.md) {
            HStack {
                Text("Search Results")
                    .font(FFTypography.headlineSmall)
                    .foregroundColor(FFColors.textPrimary)

                if viewModel.isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(FFColors.goldPrimary)
                }
            }
            .padding(.horizontal)

            if viewModel.searchResults.isEmpty && !viewModel.isSearching {
                HStack {
                    Spacer()
                    VStack(spacing: FFSpacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundColor(FFColors.textTertiary)
                        Text("No movies found")
                            .font(FFTypography.bodyMedium)
                            .foregroundColor(FFColors.textSecondary)
                    }
                    .padding(.vertical, FFSpacing.xxl)
                    Spacer()
                }
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: FFSpacing.md),
                    GridItem(.flexible(), spacing: FFSpacing.md),
                    GridItem(.flexible(), spacing: FFSpacing.md)
                ], spacing: FFSpacing.lg) {
                    ForEach(viewModel.searchResults) { movie in
                        MoviePosterCard(movie: movie, size: .small) {
                            selectedMovie = movie
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var movieGrid: some View {
        VStack(alignment: .leading, spacing: FFSpacing.md) {
            HStack {
                Text("\(String(viewModel.selectedYear)) Movies")
                    .font(FFTypography.headlineSmall)
                    .foregroundColor(FFColors.textPrimary)

                Spacer()

                if viewModel.isLoading && !viewModel.movies.isEmpty {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(FFColors.goldPrimary)
                }
            }
            .padding(.horizontal)

            if viewModel.filteredMovies().isEmpty && !viewModel.isLoading {
                HStack {
                    Spacer()
                    VStack(spacing: FFSpacing.sm) {
                        Image(systemName: "film")
                            .font(.system(size: 32))
                            .foregroundColor(FFColors.textTertiary)
                        Text("No movies found for this filter")
                            .font(FFTypography.bodyMedium)
                            .foregroundColor(FFColors.textSecondary)
                    }
                    .padding(.vertical, FFSpacing.xxl)
                    Spacer()
                }
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: FFSpacing.md),
                    GridItem(.flexible(), spacing: FFSpacing.md),
                    GridItem(.flexible(), spacing: FFSpacing.md)
                ], spacing: FFSpacing.lg) {
                    ForEach(viewModel.filteredMovies()) { movie in
                        MoviePosterCard(movie: movie, size: .small) {
                            selectedMovie = movie
                        }
                        .onAppear {
                            // Trigger load more when reaching last few items
                            let movies = viewModel.filteredMovies()
                            if let index = movies.firstIndex(where: { $0.id == movie.id }),
                               index >= movies.count - 3 {
                                Task {
                                    await viewModel.loadMoreMovies()
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)

                // Loading indicator for infinite scroll
                if viewModel.isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(FFColors.goldPrimary)
                        Spacer()
                    }
                    .padding(.vertical, FFSpacing.lg)
                }
            }
        }
    }
}

// MARK: - Collection Tile

/// Spotify-playlist style tile for a movie collection.
struct CollectionTile: View {
    let list: MovieList
    @StateObject private var seenService = SeenMoviesService.shared

    private var coverURL: URL? {
        if let path = list.coverPosterPath {
            return URL(string: "\(APIConfiguration.TMDB.imageBaseURL)/\(APIConfiguration.TMDB.PosterSize.medium.rawValue)\(path)")
        }
        if let firstId = list.movieIds.first {
            return seenService.cachedMovie(for: firstId)?.posterURL
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                if let url = coverURL {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                            .fill(FFColors.backgroundElevated)
                    }
                } else {
                    RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                        .fill(LinearGradient(
                            colors: [FFColors.goldPrimary.opacity(0.35), FFColors.backgroundElevated],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .overlay {
                            Image(systemName: list.isCurated ? "sparkles" : "rectangle.stack.fill")
                                .font(.system(size: 28))
                                .foregroundColor(FFColors.goldLight)
                        }
                }
            }
            .aspectRatio(1.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            }

            Text(list.name)
                .font(FFTypography.labelMedium)
                .foregroundColor(FFColors.textPrimary)
                .lineLimit(1)

            Text("\(list.movieIds.count) \(list.movieIds.count == 1 ? "movie" : "movies")")
                .font(FFTypography.caption)
                .foregroundColor(FFColors.textTertiary)
                .lineLimit(1)
        }
    }
}

// MARK: - Movie Detail View

struct MovieDetailView: View {
    /// Internal navigation stack. Tapping a recommendation pushes; the back
    /// button pops. Avoids the "infinite nested sheets" problem where drilling
    /// into recommendations stacks up modal after modal.
    @State private var movieStack: [FFMovie]

    @StateObject private var seenService = SeenMoviesService.shared
    @State private var showReviewSheet = false
    @State private var recommendations: [FFMovie] = []
    @State private var friendReviews: [MovieReviewItem] = []
    @State private var publicReviews: [MovieReviewItem] = []
    @State private var reviewsScope: ReviewsScope = .friends

    init(movie: FFMovie) {
        _movieStack = State(initialValue: [movie])
    }

    enum ReviewsScope: String, CaseIterable { case friends = "Friends", all = "All" }

    /// The movie currently being displayed.
    private var movie: FFMovie { movieStack.last ?? movieStack[0] }
    private var canGoBack: Bool { movieStack.count > 1 }

    private var isSeen: Bool { seenService.isSeen(tmdbId: movie.tmdbId) }
    private var isOnWatchlist: Bool { seenService.isOnWatchlist(tmdbId: movie.tmdbId) }

    var body: some View {
        ZStack {
            FFColors.backgroundDark.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    MovieHeroImage(movie: movie)
                        .frame(height: 250)
                        .clipped()
                        .overlay {
                            LinearGradient(
                                colors: [.clear, FFColors.backgroundDark],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }

                    // Content
                    VStack(alignment: .leading, spacing: FFSpacing.xl) {
                        // Title section
                        HStack(alignment: .bottom, spacing: FFSpacing.lg) {
                            // Poster
                            if let posterURL = movie.posterURL {
                                CachedAsyncImage(url: posterURL) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    FFColors.backgroundElevated
                                }
                                .frame(width: 100, height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))
                                .shadow(color: .black.opacity(0.3), radius: 10)
                                .offset(y: -60)
                            }

                            VStack(alignment: .leading, spacing: FFSpacing.sm) {
                                Text(movie.title)
                                    .font(FFTypography.headlineLarge)
                                    .foregroundColor(FFColors.textPrimary)

                                HStack(spacing: FFSpacing.md) {
                                    if let year = movie.year {
                                        Text(String(year))
                                            .font(FFTypography.labelSmall)
                                            .foregroundColor(FFColors.textSecondary)
                                    }

                                    if let runtime = movie.formattedRuntime {
                                        Text(runtime)
                                            .font(FFTypography.labelSmall)
                                            .foregroundColor(FFColors.textSecondary)
                                    }

                                    if let cert = movie.certification {
                                        Text(cert)
                                            .font(FFTypography.labelSmall)
                                            .foregroundColor(FFColors.textSecondary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 4)
                                                    .stroke(FFColors.textSecondary, lineWidth: 1)
                                            }
                                    }
                                }
                            }

                            Spacer()
                        }
                        .padding(.horizontal)

                        // Action tiles — three equal-width buttons
                        VStack(spacing: FFSpacing.md) {
                            HStack(spacing: FFSpacing.sm) {
                                actionTile(
                                    icon: isSeen ? "eye.fill" : "eye",
                                    label: isSeen ? "Watched" : "Watch",
                                    isActive: isSeen
                                ) {
                                    seenService.toggleSeen(movie)
                                }

                                actionTile(
                                    icon: isOnWatchlist ? "bookmark.fill" : "bookmark",
                                    label: "Watchlist",
                                    isActive: isOnWatchlist
                                ) {
                                    seenService.toggleWatchlist(movie)
                                }

                                actionTile(
                                    icon: "square.and.pencil",
                                    label: "Log",
                                    isActive: false
                                ) {
                                    showReviewSheet = true
                                }
                            }

                            // Star rating row (shown when watched)
                            if isSeen {
                                VStack(spacing: FFSpacing.xs) {
                                    Text("Your Rating")
                                        .font(FFTypography.labelSmall)
                                        .foregroundColor(FFColors.textTertiary)
                                    StarRatingView(tmdbId: movie.tmdbId, compact: false)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, FFSpacing.sm)
                                .background {
                                    RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                                        .fill(FFColors.goldPrimary.opacity(0.08))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                                                .stroke(FFColors.goldPrimary.opacity(0.2), lineWidth: 1)
                                        }
                                }
                                .transition(.scale(scale: 0.95).combined(with: .opacity))
                            }
                        }
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isSeen)
                        .padding(.horizontal)
                        .sheet(isPresented: $showReviewSheet) {
                            ReviewSheet(movie: movie)
                        }

                        // Overview
                        VStack(alignment: .leading, spacing: FFSpacing.sm) {
                            Text("Overview")
                                .font(FFTypography.headlineSmall)
                                .foregroundColor(FFColors.textPrimary)

                            Text(movie.overview)
                                .font(FFTypography.bodyMedium)
                                .foregroundColor(FFColors.textSecondary)
                        }
                        .padding(.horizontal)

                        // Genres
                        if !movie.genres.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: FFSpacing.sm) {
                                    ForEach(movie.genres) { genre in
                                        Text(genre.name)
                                            .font(FFTypography.labelSmall)
                                            .foregroundColor(FFColors.goldPrimary)
                                            .padding(.horizontal, FFSpacing.md)
                                            .padding(.vertical, FFSpacing.sm)
                                            .background {
                                                Capsule()
                                                    .fill(FFColors.goldPrimary.opacity(0.15))
                                            }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }

                        // Cast
                        if !movie.cast.isEmpty {
                            VStack(alignment: .leading, spacing: FFSpacing.md) {
                                Text("Cast")
                                    .font(FFTypography.headlineSmall)
                                    .foregroundColor(FFColors.textPrimary)
                                    .padding(.horizontal)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: FFSpacing.md) {
                                        ForEach(movie.topBilledCast) { cast in
                                            VStack(spacing: FFSpacing.sm) {
                                                Circle()
                                                    .fill(FFColors.backgroundElevated)
                                                    .frame(width: 60, height: 60)
                                                    .overlay {
                                                        Image(systemName: "person.fill")
                                                            .foregroundColor(FFColors.textTertiary)
                                                    }

                                                VStack(spacing: 2) {
                                                    Text(cast.name)
                                                        .font(FFTypography.labelSmall)
                                                        .foregroundColor(FFColors.textPrimary)
                                                        .lineLimit(1)

                                                    Text(cast.character)
                                                        .font(FFTypography.caption)
                                                        .foregroundColor(FFColors.textTertiary)
                                                        .lineLimit(1)
                                                }
                                            }
                                            .frame(width: 80)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }

                        // Reviews section
                        reviewsSection

                        // You might also like
                        recommendationsSection

                        Spacer(minLength: 100)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task(id: movie.tmdbId) {
            await loadRecommendations()
            await loadReviews()
        }
        .toolbar {
            // Internal back button when the user has drilled into a recommendation.
            // Pops the stack back to the previous movie without adding another sheet.
            if canGoBack {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            _ = movieStack.popLast()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(FFColors.goldPrimary)
                    }
                }
            }
        }
    }

    // MARK: - Reviews section

    @ViewBuilder
    private var reviewsSection: some View {
        let currentReviews: [MovieReviewItem] = (reviewsScope == .friends) ? friendReviews : publicReviews
        if !friendReviews.isEmpty || !publicReviews.isEmpty {
            VStack(alignment: .leading, spacing: FFSpacing.md) {
                HStack {
                    Text("Reviews")
                        .font(FFTypography.headlineSmall)
                        .foregroundColor(FFColors.textPrimary)
                    Spacer()
                    Picker("Scope", selection: $reviewsScope) {
                        ForEach(ReviewsScope.allCases, id: \.self) { scope in
                            Text(scope.rawValue).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }
                .padding(.horizontal)

                if currentReviews.isEmpty {
                    Text(reviewsScope == .friends ? "None of your friends have reviewed this yet." : "No public reviews yet.")
                        .font(FFTypography.caption)
                        .foregroundColor(FFColors.textTertiary)
                        .padding(.horizontal)
                } else {
                    VStack(spacing: FFSpacing.sm) {
                        ForEach(currentReviews) { review in
                            reviewRow(review)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private func reviewRow(_ review: MovieReviewItem) -> some View {
        VStack(alignment: .leading, spacing: FFSpacing.sm) {
            HStack(spacing: FFSpacing.sm) {
                // Avatar
                ZStack {
                    Circle().fill(FFColors.goldGradient).frame(width: 32, height: 32)
                    if let icon = review.userAvatarIcon {
                        Image(systemName: icon).font(.system(size: 14)).foregroundColor(FFColors.backgroundDark)
                    } else {
                        Text(review.userName.prefix(1).uppercased())
                            .font(FFTypography.labelMedium).foregroundColor(FFColors.backgroundDark)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(review.userName)
                        .font(FFTypography.labelMedium).foregroundColor(FFColors.textPrimary)
                    HStack(spacing: 6) {
                        if let rating = review.rating {
                            StarRatingDisplay(rating: rating, size: 10)
                        }
                        if review.isRewatch {
                            Text("rewatch")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(FFColors.goldPrimary)
                        }
                        Text(review.watchedDate, style: .date)
                            .font(FFTypography.caption)
                            .foregroundColor(FFColors.textTertiary)
                    }
                }

                Spacer()
            }

            if !review.reviewText.isEmpty {
                Text(review.reviewText)
                    .font(FFTypography.bodySmall)
                    .foregroundColor(FFColors.textSecondary)
                    .lineLimit(5)
            }
        }
        .padding(FFSpacing.md)
        .background {
            RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                .fill(FFColors.backgroundElevated.opacity(0.5))
                .overlay {
                    RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                }
        }
    }

    // MARK: - Recommendations section

    @ViewBuilder
    private var recommendationsSection: some View {
        if !recommendations.isEmpty {
            VStack(alignment: .leading, spacing: FFSpacing.md) {
                Text("You Might Also Like")
                    .font(FFTypography.headlineSmall)
                    .foregroundColor(FFColors.textPrimary)
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: FFSpacing.md) {
                        ForEach(recommendations.prefix(10)) { rec in
                            Button {
                                // Swap the current movie in place instead of
                                // opening another sheet. Adds to the internal
                                // stack so "Back" takes the user to this movie.
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    movieStack.append(rec)
                                }
                            } label: {
                                recommendationCard(rec)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private func recommendationCard(_ movie: FFMovie) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let url = movie.posterURL {
                CachedAsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8).fill(FFColors.backgroundElevated)
                }
                .frame(width: 110, height: 165)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(FFColors.backgroundElevated)
                    .frame(width: 110, height: 165)
                    .overlay {
                        Image(systemName: "film").foregroundColor(FFColors.textTertiary)
                    }
            }
            Text(movie.title)
                .font(FFTypography.caption)
                .foregroundColor(FFColors.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: 110, alignment: .leading)
        }
    }

    // MARK: - Async loaders

    private func loadRecommendations() async {
        do {
            let response = try await TMDBService.shared.getRecommendations(movieId: movie.tmdbId, page: 1)
            recommendations = response.results.map { TMDBService.shared.convertToFFMovie($0) }
        } catch {
            recommendations = []
        }
    }

    private func loadReviews() async {
        friendReviews = await MovieReviewsService.shared.friendReviews(for: movie.tmdbId)
        publicReviews = await MovieReviewsService.shared.publicReviews(for: movie.tmdbId, limit: 50)
    }

    private func actionTile(icon: String, label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(isActive ? FFColors.goldPrimary : FFColors.textSecondary)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isActive ? FFColors.goldPrimary : FFColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, FFSpacing.md)
            .background {
                RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                    .fill(isActive ? FFColors.goldPrimary.opacity(0.12) : FFColors.backgroundElevated.opacity(0.6))
                    .overlay {
                        RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                            .stroke(
                                isActive ? FFColors.goldPrimary.opacity(0.35) : Color.white.opacity(0.08),
                                lineWidth: 1
                            )
                    }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Movie Hero Image

/// Hero image for the movie detail view.
/// Tries the backdrop first (if distinct from the poster). If the backdrop
/// fails to load, falls back to a blurred + darkened poster so the hero
/// area always renders something nice instead of a flat gray rectangle.
struct MovieHeroImage: View {
    let movie: FFMovie

    @State private var image: UIImage?
    @State private var usingPosterFallback = false
    @State private var isLoading = true

    private var primaryURL: URL? {
        // Use the backdrop only if it's a distinct image from the poster.
        // (TMDB sometimes returns the same path for both; treat that as "no backdrop".)
        guard let backdropPath = movie.backdropPath else { return nil }
        if let posterPath = movie.posterPath, posterPath == backdropPath {
            return nil
        }
        return movie.backdropURL
    }

    private var posterURL: URL? { movie.posterURL }

    var body: some View {
        Group {
            if let image {
                if usingPosterFallback {
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .blur(radius: 20)
                            .saturation(1.1)
                        Color.black.opacity(0.35)
                    }
                } else {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
            } else {
                // While loading, or if both URLs are nil, show an elevated background
                FFColors.backgroundElevated
                    .overlay {
                        if isLoading {
                            InlineLoader(size: 20)
                        } else {
                            Image(systemName: "film")
                                .font(.system(size: 36))
                                .foregroundColor(FFColors.textTertiary)
                        }
                    }
            }
        }
        .task(id: movie.tmdbId) {
            await loadHero()
        }
    }

    private func loadHero() async {
        isLoading = true
        image = nil
        usingPosterFallback = false

        // Try the backdrop first
        if let primaryURL,
           let loaded = await ImageCache.shared.image(for: primaryURL) {
            image = loaded
            isLoading = false
            return
        }

        // Fall back to the poster (rendered blurred as the hero)
        if let posterURL,
           let loaded = await ImageCache.shared.image(for: posterURL) {
            image = loaded
            usingPosterFallback = true
            isLoading = false
            return
        }

        isLoading = false
    }
}

// MARK: - Preview

#Preview {
    MoviesView()
        .ffTheme()
}
