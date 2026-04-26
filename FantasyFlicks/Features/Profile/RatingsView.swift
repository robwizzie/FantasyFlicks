//
//  RatingsView.swift
//  FantasyFlicks
//
//  All rated movies with inline editing
//

import SwiftUI

struct RatingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var seenService = SeenMoviesService.shared
    @State private var sortOption: SortOption = .ratingDesc
    @State private var selectedMovie: FFMovie?
    @State private var listFilter = ""

    /// Snapshot of ordered tmdb IDs. Computed once per (ratings, sort option) change
    /// so the list doesn't reshuffle every time metadata hydrates in — that was
    /// what caused the "auto-scroll" jumping behavior.
    @State private var orderedTmdbIds: [Int] = []

    private var filteredOrderedIds: [Int] {
        let q = listFilter.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return orderedTmdbIds }
        return orderedTmdbIds.filter { id in
            seenService.cachedMovie(for: id)?.title.lowercased().contains(q) ?? false
        }
    }

    enum SortOption: String, CaseIterable {
        case ratingDesc = "Highest rated"
        case ratingAsc = "Lowest rated"
        case titleAsc = "Title (A–Z)"

        var icon: String {
            switch self {
            case .ratingDesc: return "arrow.down"
            case .ratingAsc: return "arrow.up"
            case .titleAsc: return "textformat"
            }
        }
    }

    /// Stable ordering of rated movies. Sort keys don't depend on async-loaded
    /// titles, so rows don't jump as metadata hydrates.
    private func computeOrdering() -> [Int] {
        let ratings = seenService.ratings
        let ids = Array(ratings.keys)
        switch sortOption {
        case .ratingDesc:
            return ids.sorted {
                let a = ratings[$0] ?? 0
                let b = ratings[$1] ?? 0
                if a != b { return a > b }
                return $0 < $1  // stable tiebreak by tmdbId — not by async title
            }
        case .ratingAsc:
            return ids.sorted {
                let a = ratings[$0] ?? 0
                let b = ratings[$1] ?? 0
                if a != b { return a < b }
                return $0 < $1
            }
        case .titleAsc:
            return ids.sorted {
                let t1 = seenService.cachedMovie(for: $0)?.title ?? ""
                let t2 = seenService.cachedMovie(for: $1)?.title ?? ""
                if t1 != t2 { return t1.localizedCaseInsensitiveCompare(t2) == .orderedAscending }
                return $0 < $1
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()

                if seenService.ratings.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: FFSpacing.sm, pinnedViews: []) {
                            sortBar
                                .padding(.top, FFSpacing.md)
                            filterBar
                            ForEach(Array(filteredOrderedIds.enumerated()), id: \.element) { index, tmdbId in
                                row(
                                    tmdbId: tmdbId,
                                    stars: seenService.ratings[tmdbId] ?? 0,
                                    cached: seenService.cachedMovie(for: tmdbId)
                                )
                                .id(tmdbId)
                                .onAppear {
                                    // When the user scrolls within 10 rows of the end,
                                    // hydrate the next 30 movies' metadata.
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
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationTitle("Ratings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(FFColors.goldPrimary)
                }
            }
            .task {
                // Snapshot order first, then hydrate just the first 50 rows.
                // When the user scrolls near the end, the row's `.onAppear` below
                // requests the next chunk.
                orderedTmdbIds = computeOrdering()
                await seenService.hydrateMissingMetadata(
                    tmdbIds: orderedTmdbIds.prefix(50),
                    limit: 50
                )
            }
            .onChange(of: sortOption) { _, _ in
                orderedTmdbIds = computeOrdering()
            }
            .onChange(of: seenService.ratings.count) { _, _ in
                orderedTmdbIds = computeOrdering()
            }
            .sheet(item: $selectedMovie) { movie in
                NavigationStack { MovieDetailView(movie: movie) }
            }
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: FFSpacing.lg) {
            Image(systemName: "star")
                .font(.system(size: 48))
                .foregroundColor(FFColors.textTertiary)
            Text("No ratings yet")
                .font(FFTypography.titleMedium)
                .foregroundColor(FFColors.textSecondary)
            Text("Rate movies from the movie detail view or while swiping")
                .font(FFTypography.bodySmall)
                .foregroundColor(FFColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Filter

    private var filterBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundColor(FFColors.textTertiary)
            TextField("Filter titles", text: $listFilter)
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
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(FFColors.backgroundElevated.opacity(0.6))
        .clipShape(Capsule())
        .padding(.horizontal)
    }

    // MARK: - Sort

    private var sortBar: some View {
        HStack {
            Text("\(seenService.ratings.count) rated")
                .font(FFTypography.labelSmall)
                .foregroundColor(FFColors.textTertiary)

            Spacer()

            Menu {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button {
                        sortOption = option
                    } label: {
                        HStack {
                            Text(option.rawValue)
                            if sortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 10, weight: .bold))
                    Text(sortOption.rawValue)
                        .font(FFTypography.labelSmall)
                }
                .foregroundColor(FFColors.goldPrimary)
                .padding(.horizontal, FFSpacing.md)
                .padding(.vertical, 6)
                .background(FFColors.goldPrimary.opacity(0.12))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Row

    private func row(tmdbId: Int, stars: Double, cached: CachedMovie?) -> some View {
        Button {
            // Open the real movie detail on tap (but NOT when tapping the stars —
            // those have their own buttons which intercept first).
            if let cached {
                selectedMovie = cached.toFFMovie()
            }
        } label: {
            HStack(spacing: FFSpacing.md) {
                if let posterURL = cached?.posterURL {
                    CachedAsyncImage(url: posterURL) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(FFColors.backgroundElevated)
                    }
                    .frame(width: 48, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(FFColors.backgroundElevated)
                        .frame(width: 48, height: 72)
                        .overlay {
                            Image(systemName: "film")
                                .foregroundColor(FFColors.textTertiary)
                        }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(cached?.title ?? "Loading…")
                        .font(FFTypography.labelMedium)
                        .foregroundColor(FFColors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let year = cached?.year {
                        Text(String(year))
                            .font(FFTypography.caption)
                            .foregroundColor(FFColors.textTertiary)
                    }

                    StarRatingView(tmdbId: tmdbId, compact: false)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(FFColors.textTertiary)
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
            .padding(.horizontal)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
