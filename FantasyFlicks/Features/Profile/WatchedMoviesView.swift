//
//  WatchedMoviesView.swift
//  FantasyFlicks
//
//  The user's watched-movies list with search-to-add and Letterboxd import.
//

import SwiftUI
import UniformTypeIdentifiers

struct WatchedMoviesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var seenService = SeenMoviesService.shared
    @State private var showLetterboxdImporter = false
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
        case ratingDesc = "My rating (high)"
        case ratingAsc = "My rating (low)"
    }

    /// Snapshot of the ordered list. Populated once in `.task` so metadata
    /// hydrating later doesn't reshuffle the list mid-scroll.
    @State private var orderedTmdbIds: [Int] = []

    private var showingSearch: Bool {
        searchText.trimmingCharacters(in: .whitespaces).count >= 2
    }

    /// Compute a stable ordering based on the selected sort option. Fallback
    /// tiebreaker is tmdbId so list rows don't jump as async metadata loads.
    private func computeOrdering() -> [Int] {
        let ids = Array(seenService.seenTmdbIds)
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
                let r1 = seenService.ratings[a] ?? -1
                let r2 = seenService.ratings[b] ?? -1
                if r1 != r2 { return r1 > r2 }
                return a < b
            }
        case .ratingAsc:
            return ids.sorted { a, b in
                let r1 = seenService.ratings[a] ?? 99
                let r2 = seenService.ratings[b] ?? 99
                if r1 != r2 { return r1 < r2 }
                return a < b
            }
        }
    }

    /// Filter the ordered list by the in-list search (separate from the
    /// top-of-screen TMDB search, which has a different purpose).
    private var filteredOrderedIds: [Int] {
        let q = listFilter.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return orderedTmdbIds }
        return orderedTmdbIds.filter { id in
            seenService.cachedMovie(for: id)?.title.lowercased().contains(q) ?? false
        }
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
                            statsCard
                            letterboxdCard
                            watchedListSection
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.top, FFSpacing.md)
                }
            }
            .navigationTitle("Watched")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(FFColors.goldPrimary)
                }
            }
            .task {
                orderedTmdbIds = computeOrdering()
                // Only hydrate the first 50 rows up front — the list's row
                // `.onAppear` pulls more as the user scrolls.
                await seenService.hydrateMissingMetadata(
                    tmdbIds: orderedTmdbIds.prefix(50),
                    limit: 50
                )
            }
            .onChange(of: searchText) { _, newValue in
                runSearch(for: newValue)
            }
            .onChange(of: seenService.seenTmdbIds.count) { _, _ in
                // Only re-order when membership changes, not when metadata loads
                orderedTmdbIds = computeOrdering()
            }
            .onChange(of: sortOption) { _, _ in
                orderedTmdbIds = computeOrdering()
            }
            .sheet(item: $selectedMovie) { movie in
                NavigationStack { MovieDetailView(movie: movie) }
            }
            .fileImporter(
                isPresented: $showLetterboxdImporter,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    Task { _ = await seenService.importLetterboxd(from: url) }
                case .failure:
                    break
                }
            }
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: FFSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(FFColors.textTertiary)

            TextField("Search & mark as watched", text: $searchText)
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

    // MARK: - Stats

    private var statsCard: some View {
        GlassCard(goldTint: true) {
            HStack(spacing: FFSpacing.md) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 32))
                    .foregroundColor(FFColors.goldPrimary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(seenService.count)")
                        .font(FFTypography.statMedium)
                        .foregroundColor(FFColors.textPrimary)
                    Text(seenService.count == 1 ? "movie watched" : "movies watched")
                        .font(FFTypography.bodySmall)
                        .foregroundColor(FFColors.textSecondary)
                }

                Spacer()
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Letterboxd card

    private var letterboxdCard: some View {
        GlassCard {
            VStack(spacing: FFSpacing.md) {
                HStack(spacing: FFSpacing.md) {
                    Image(systemName: "square.and.arrow.down.fill")
                        .font(.system(size: 22))
                        .foregroundColor(FFColors.goldPrimary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Import from Letterboxd")
                            .font(FFTypography.titleSmall)
                            .foregroundColor(FFColors.textPrimary)
                        Text("Upload your watched.csv")
                            .font(FFTypography.caption)
                            .foregroundColor(FFColors.textTertiary)
                    }
                    Spacer()
                }

                GoldButton(
                    title: seenService.isImporting ? "Importing…" : "Choose CSV File",
                    icon: "doc.fill",
                    style: .secondary,
                    size: .medium,
                    isLoading: seenService.isImporting,
                    fullWidth: true
                ) {
                    showLetterboxdImporter = true
                }
                .disabled(seenService.isImporting)

                if let count = seenService.lastImportCount, count > 0 {
                    HStack(spacing: FFSpacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(FFColors.success)
                        Text("Imported \(count) movies")
                            .font(FFTypography.labelMedium)
                            .foregroundColor(FFColors.success)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Watched list

    private var watchedListSection: some View {
        VStack(alignment: .leading, spacing: FFSpacing.md) {
            HStack {
                Text("Your Watched Movies")
                    .font(FFTypography.headlineSmall)
                    .foregroundColor(FFColors.textPrimary)
                Spacer()
                if !orderedTmdbIds.isEmpty {
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

            if !orderedTmdbIds.isEmpty {
                listFilterAndSort
            }

            if orderedTmdbIds.isEmpty {
                emptyState(
                    icon: "eye.slash",
                    title: "Nothing watched yet",
                    subtitle: "Search above, import from Letterboxd, or mark movies while swiping"
                )
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
                            if let cached = seenService.cachedMovie(for: tmdbId) {
                                watchedRow(item: cached)
                            } else {
                                loadingRow()
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

    /// Placeholder row while a movie's metadata is still loading.
    private func loadingRow() -> some View {
        HStack(spacing: FFSpacing.md) {
            RoundedRectangle(cornerRadius: 6)
                .fill(FFColors.backgroundElevated)
                .frame(width: 48, height: 72)

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(FFColors.backgroundElevated)
                    .frame(width: 160, height: 14)
                RoundedRectangle(cornerRadius: 4)
                    .fill(FFColors.backgroundElevated)
                    .frame(width: 80, height: 10)
            }
            Spacer()
        }
        .padding(FFSpacing.md)
        .background {
            RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                .fill(FFColors.backgroundElevated.opacity(0.3))
        }
        .shimmer()
    }

    private func watchedRow(item: CachedMovie) -> some View {
        let rating = seenService.rating(for: item.id)

        return Button {
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

                    if let rating {
                        StarRatingDisplay(rating: rating, size: 10)
                    }
                }

                Spacer()

                Button {
                    seenService.markUnseen(tmdbId: item.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(FFColors.ruby.opacity(0.7))
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Search results section

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
        let isSeen = seenService.isSeen(tmdbId: movie.tmdbId)

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

                if isSeen {
                    StarRatingView(tmdbId: movie.tmdbId, compact: true)
                }
            }

            Spacer()

            Button {
                seenService.toggleSeen(movie)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isSeen ? "eye.fill" : "eye")
                        .font(.system(size: 12))
                    Text(isSeen ? "Watched" : "Mark Seen")
                        .font(FFTypography.labelSmall)
                }
                .foregroundColor(isSeen ? FFColors.goldPrimary : FFColors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSeen ? FFColors.goldPrimary.opacity(0.15) : FFColors.backgroundElevated)
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(isSeen ? FFColors.goldPrimary.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 1)
                }
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
