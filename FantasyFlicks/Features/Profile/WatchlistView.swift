//
//  WatchlistView.swift
//  FantasyFlicks
//
//  Want-to-watch list with search to add and full display of saved items.
//

import SwiftUI

struct WatchlistView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var seenService = SeenMoviesService.shared
    @State private var searchText = ""
    @State private var searchResults: [FFMovie] = []
    @State private var isSearching = false
    @State private var selectedMovie: FFMovie?
    @State private var listFilter = ""
    @State private var sortOption: SortOption = .titleAsc

    enum SortOption: String, CaseIterable {
        case titleAsc = "Title (A–Z)"
        case titleDesc = "Title (Z–A)"
        case yearDesc = "Newest"
        case yearAsc = "Oldest"
        case ratingDesc = "TMDB rating"
    }

    private var showingSearch: Bool {
        searchText.trimmingCharacters(in: .whitespaces).count >= 2
    }

    /// Stable ordering snapshot — see RatingsView / WatchedMoviesView for the same pattern.
    @State private var orderedTmdbIds: [Int] = []

    private func computeOrdering() -> [Int] {
        let ids = Array(seenService.watchlist)
        switch sortOption {
        case .titleAsc:
            return ids.sorted { a, b in
                let t1 = seenService.cachedMovie(for: a)?.title ?? ""
                let t2 = seenService.cachedMovie(for: b)?.title ?? ""
                if t1 != t2 { return t1.localizedCaseInsensitiveCompare(t2) == .orderedAscending }
                return a < b
            }
        case .titleDesc:
            return ids.sorted { a, b in
                let t1 = seenService.cachedMovie(for: a)?.title ?? ""
                let t2 = seenService.cachedMovie(for: b)?.title ?? ""
                if t1 != t2 { return t1.localizedCaseInsensitiveCompare(t2) == .orderedDescending }
                return a > b
            }
        case .yearDesc:
            return ids.sorted { a, b in
                let y1 = seenService.cachedMovie(for: a)?.year ?? 0
                let y2 = seenService.cachedMovie(for: b)?.year ?? 0
                if y1 != y2 { return y1 > y2 }
                return a < b
            }
        case .yearAsc:
            return ids.sorted { a, b in
                let y1 = seenService.cachedMovie(for: a)?.year ?? 9999
                let y2 = seenService.cachedMovie(for: b)?.year ?? 9999
                if y1 != y2 { return y1 < y2 }
                return a < b
            }
        case .ratingDesc:
            return ids.sorted { a, b in
                let v1 = seenService.cachedMovie(for: a)?.voteAverage ?? -1
                let v2 = seenService.cachedMovie(for: b)?.voteAverage ?? -1
                if v1 != v2 { return v1 > v2 }
                return a < b
            }
        }
    }

    private var filteredOrderedIds: [Int] {
        let q = listFilter.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return orderedTmdbIds }
        return orderedTmdbIds.filter { id in
            seenService.cachedMovie(for: id)?.title.lowercased().contains(q) ?? false
        }
    }

    private var watchlistItems: [CachedMovie] {
        orderedTmdbIds.compactMap { seenService.cachedMovie(for: $0) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: FFSpacing.lg) {
                        searchBar

                        if showingSearch {
                            searchResultsSection
                        } else {
                            watchlistSection
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.top, FFSpacing.md)
                }
            }
            .navigationTitle("Watchlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(FFColors.goldPrimary)
                }
            }
            .task {
                orderedTmdbIds = computeOrdering()
                await seenService.hydrateMissingMetadata(
                    tmdbIds: orderedTmdbIds.prefix(50),
                    limit: 50
                )
            }
            .onChange(of: searchText) { _, newValue in
                runSearch(for: newValue)
            }
            .onChange(of: seenService.watchlist.count) { _, _ in
                orderedTmdbIds = computeOrdering()
            }
            .onChange(of: sortOption) { _, _ in
                orderedTmdbIds = computeOrdering()
            }
            .sheet(item: $selectedMovie) { movie in
                NavigationStack { MovieDetailView(movie: movie) }
            }
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: FFSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(FFColors.textTertiary)

            TextField("Search to add a movie", text: $searchText)
                .font(FFTypography.bodyMedium)
                .foregroundColor(FFColors.textPrimary)
                .textInputAutocapitalization(.words)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    searchResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(FFColors.textTertiary)
                }
                .buttonStyle(.plain)
            }

            if isSearching {
                InlineLoader(size: 16)
            }
        }
        .padding(FFSpacing.md)
        .background(FFColors.backgroundElevated)
        .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))
        .overlay {
            RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        }
        .padding(.horizontal)
    }

    // MARK: - Search results

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: FFSpacing.md) {
            HStack {
                Text("Results")
                    .font(FFTypography.labelMedium)
                    .foregroundColor(FFColors.textTertiary)
                Spacer()
                if !searchResults.isEmpty {
                    Text("\(searchResults.count) found")
                        .font(FFTypography.caption)
                        .foregroundColor(FFColors.textTertiary)
                }
            }
            .padding(.horizontal)

            if searchResults.isEmpty && !isSearching {
                emptyState(icon: "magnifyingglass", title: "No results", subtitle: "Try a different title")
            } else {
                VStack(spacing: FFSpacing.sm) {
                    ForEach(searchResults) { movie in
                        searchResultRow(movie: movie)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func searchResultRow(movie: FFMovie) -> some View {
        let isOn = seenService.isOnWatchlist(tmdbId: movie.tmdbId)

        return HStack(spacing: FFSpacing.md) {
            posterThumb(url: movie.posterURL)

            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title)
                    .font(FFTypography.labelMedium)
                    .foregroundColor(FFColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: FFSpacing.sm) {
                    if let year = movie.year {
                        Text(String(year))
                            .font(FFTypography.caption)
                            .foregroundColor(FFColors.textTertiary)
                    }
                    if movie.voteAverage > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundColor(FFColors.goldPrimary)
                            Text(String(format: "%.1f", movie.voteAverage))
                                .font(FFTypography.caption)
                                .foregroundColor(FFColors.goldLight)
                        }
                    }
                }
            }

            Spacer()

            Button {
                seenService.toggleWatchlist(movie)
            } label: {
                Image(systemName: isOn ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 20))
                    .foregroundColor(isOn ? FFColors.goldPrimary : FFColors.textTertiary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
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

    // MARK: - Actual Watchlist

    private var watchlistSection: some View {
        VStack(alignment: .leading, spacing: FFSpacing.md) {
            HStack {
                Text("Your Watchlist")
                    .font(FFTypography.headlineSmall)
                    .foregroundColor(FFColors.textPrimary)

                Spacer()

                if !watchlistItems.isEmpty {
                    Text("\(filteredOrderedIds.count)")
                        .font(FFTypography.labelSmall)
                        .foregroundColor(FFColors.goldPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(FFColors.goldPrimary.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal)

            if !watchlistItems.isEmpty {
                listFilterAndSort
            }

            if watchlistItems.isEmpty {
                emptyState(
                    icon: "bookmark",
                    title: "Nothing saved yet",
                    subtitle: "Search above to add movies to your watchlist"
                )
                LetterboxdConnectCard(
                    headline: "Got a Letterboxd watchlist?",
                    message: "Connect your account, then import watchlist.csv to bring it over."
                )
                .padding(.horizontal)
            } else if filteredOrderedIds.isEmpty {
                emptyState(
                    icon: "line.horizontal.3.decrease.circle",
                    title: "No matches",
                    subtitle: "Try a different filter"
                )
            } else {
                LazyVStack(spacing: FFSpacing.sm) {
                    ForEach(Array(filteredOrderedIds.enumerated()), id: \.element) { index, tmdbId in
                        Group {
                            if let item = seenService.cachedMovie(for: tmdbId) {
                                watchlistRow(item: item)
                            } else {
                                Color.clear.frame(height: 76) // placeholder until hydrated
                            }
                        }
                        .id(tmdbId)
                        .onAppear {
                            if index >= filteredOrderedIds.count - 10 {
                                Task {
                                    await seenService.hydrateMissingMetadata(
                                        tmdbIds: orderedTmdbIds.suffix(from: min(index, orderedTmdbIds.count)),
                                        limit: 30
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var listFilterAndSort: some View {
        HStack(spacing: FFSpacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "line.horizontal.3.decrease")
                    .font(.system(size: 12))
                    .foregroundColor(FFColors.textTertiary)
                TextField("Filter your list", text: $listFilter)
                    .font(FFTypography.labelSmall)
                    .foregroundColor(FFColors.textPrimary)
                    .autocorrectionDisabled()
                if !listFilter.isEmpty {
                    Button { listFilter = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(FFColors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(FFColors.backgroundElevated.opacity(0.6))
            .clipShape(Capsule())

            Menu {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button {
                        sortOption = option
                    } label: {
                        HStack {
                            Text(option.rawValue)
                            if sortOption == option { Image(systemName: "checkmark") }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down").font(.system(size: 10, weight: .bold))
                    Text(sortOption.rawValue).font(FFTypography.labelSmall)
                }
                .foregroundColor(FFColors.goldPrimary)
                .padding(.horizontal, FFSpacing.md)
                .padding(.vertical, 8)
                .background(FFColors.goldPrimary.opacity(0.12))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal)
    }

    private func watchlistRow(item: CachedMovie) -> some View {
        Button {
            selectedMovie = item.toFFMovie()
        } label: {
            HStack(spacing: FFSpacing.md) {
                posterThumb(url: item.posterURL)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(FFTypography.labelMedium)
                        .foregroundColor(FFColors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: FFSpacing.sm) {
                        if let year = item.year {
                            Text(String(year))
                                .font(FFTypography.caption)
                                .foregroundColor(FFColors.textTertiary)
                        }
                        if let vote = item.voteAverage, vote > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(FFColors.goldPrimary)
                                Text(String(format: "%.1f", vote))
                                    .font(FFTypography.caption)
                                    .foregroundColor(FFColors.goldLight)
                            }
                        }
                    }
                }

                Spacer()

                // Mark as seen → removes from watchlist
                Button {
                    seenService.markSeen(item.toFFMovie())
                    seenService.removeFromWatchlist(tmdbId: item.id)
                    orderedTmdbIds = computeOrdering()
                } label: {
                    Image(systemName: "eye")
                        .font(.system(size: 16))
                        .foregroundColor(FFColors.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(FFColors.backgroundElevated2)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                // Remove from watchlist
                Button {
                    seenService.removeFromWatchlist(tmdbId: item.id)
                    orderedTmdbIds = computeOrdering()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(FFColors.ruby.opacity(0.7))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }
            .padding(FFSpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                .fill(FFColors.backgroundElevated.opacity(0.5))
                .overlay {
                    RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                }
        }
    }

    // MARK: - Helpers

    private func posterThumb(url: URL?) -> some View {
        Group {
            if let url {
                CachedAsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(FFColors.backgroundElevated)
                        .shimmer()
                }
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(FFColors.backgroundElevated)
                    .overlay {
                        Image(systemName: "film")
                            .foregroundColor(FFColors.textTertiary)
                    }
            }
        }
        .frame(width: 48, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: FFSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundColor(FFColors.textTertiary)
            Text(title)
                .font(FFTypography.titleSmall)
                .foregroundColor(FFColors.textSecondary)
            Text(subtitle)
                .font(FFTypography.caption)
                .foregroundColor(FFColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FFSpacing.xxl)
        .padding(.horizontal, FFSpacing.xl)
    }

    /// Build a lightweight FFMovie from a cached entry (enough to mark as seen with cache)
    private func ffMovie(from cached: CachedMovie) -> FFMovie {
        FFMovie(
            tmdbId: cached.id,
            title: cached.title,
            overview: "",
            posterPath: cached.posterPath,
            backdropPath: cached.backdropPath,
            voteAverage: cached.voteAverage ?? 0
        )
    }

    private func runSearch(for raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard searchText == raw else { return }
            do {
                let response = try await TMDBService.shared.searchMovies(query: trimmed, page: 1)
                guard searchText == raw else { return }
                searchResults = response.results.prefix(10).map { TMDBService.shared.convertToFFMovie($0) }
            } catch {
                searchResults = []
            }
            isSearching = false
        }
    }
}
