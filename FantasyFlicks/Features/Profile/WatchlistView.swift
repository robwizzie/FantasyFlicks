//
//  WatchlistView.swift
//  FantasyFlicks
//
//  Want-to-watch movie list
//

import SwiftUI

struct WatchlistView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var seenService = SeenMoviesService.shared
    @State private var searchText = ""
    @State private var searchResults: [FFMovie] = []
    @State private var isSearching = false

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: FFSpacing.xl) {
                        // Count
                        GlassCard(goldTint: true) {
                            HStack(spacing: FFSpacing.md) {
                                Image(systemName: "bookmark.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(FFColors.goldPrimary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(seenService.watchlist.count)")
                                        .font(FFTypography.statMedium)
                                        .foregroundColor(FFColors.textPrimary)
                                    Text("movies on your watchlist")
                                        .font(FFTypography.bodySmall)
                                        .foregroundColor(FFColors.textSecondary)
                                }
                                Spacer()
                            }
                        }
                        .padding(.horizontal)

                        // Search to add
                        VStack(alignment: .leading, spacing: FFSpacing.md) {
                            Text("Add to Watchlist")
                                .font(FFTypography.headlineSmall)
                                .foregroundColor(FFColors.textPrimary)
                                .padding(.horizontal)

                            HStack(spacing: FFSpacing.sm) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(FFColors.textTertiary)
                                TextField("Search for a movie...", text: $searchText)
                                    .font(FFTypography.bodyMedium)
                                    .foregroundColor(FFColors.textPrimary)
                                    .textInputAutocapitalization(.words)
                                    .onSubmit { Task { await search() } }
                                if isSearching {
                                    ProgressView().scaleEffect(0.8).tint(FFColors.goldPrimary)
                                }
                            }
                            .padding(FFSpacing.md)
                            .background(FFColors.backgroundElevated)
                            .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))
                            .padding(.horizontal)

                            ForEach(searchResults) { movie in
                                watchlistRow(movie: movie)
                            }
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
            .onChange(of: searchText) { _, newValue in
                if newValue.count >= 2 {
                    Task {
                        try? await Task.sleep(for: .milliseconds(400))
                        guard searchText == newValue else { return }
                        await search()
                    }
                } else {
                    searchResults = []
                }
            }
        }
    }

    private func watchlistRow(movie: FFMovie) -> some View {
        let isOn = seenService.isOnWatchlist(tmdbId: movie.tmdbId)

        return HStack(spacing: FFSpacing.md) {
            if let posterURL = movie.posterURL {
                CachedAsyncImage(url: posterURL) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: { FFColors.backgroundElevated }
                .frame(width: 40, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(movie.title)
                    .font(FFTypography.labelMedium)
                    .foregroundColor(FFColors.textPrimary)
                    .lineLimit(1)
                if let year = movie.year {
                    Text(String(year))
                        .font(FFTypography.caption)
                        .foregroundColor(FFColors.textTertiary)
                }
            }

            Spacer()

            Button {
                seenService.toggleWatchlist(tmdbId: movie.tmdbId)
            } label: {
                Image(systemName: isOn ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 18))
                    .foregroundColor(isOn ? FFColors.goldPrimary : FFColors.textTertiary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, FFSpacing.xs)
    }

    private func search() async {
        guard !searchText.isEmpty else { return }
        isSearching = true
        do {
            let response = try await TMDBService.shared.searchMovies(query: searchText)
            searchResults = response.results.prefix(10).map { TMDBService.shared.convertToFFMovie($0) }
        } catch { searchResults = [] }
        isSearching = false
    }
}
