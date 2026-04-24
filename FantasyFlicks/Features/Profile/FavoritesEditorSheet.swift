//
//  FavoritesEditorSheet.swift
//  FantasyFlicks
//
//  Letterboxd-style favorites editor. Users pick up to 4 pinned movies
//  from their existing watched/watchlist/ratings lists or by searching
//  TMDB. Order is preserved as the user taps.
//

import SwiftUI

struct FavoritesEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ProfileViewModel

    @StateObject private var seenService = SeenMoviesService.shared

    @State private var selectedIds: [Int]
    @State private var searchText: String = ""
    @State private var searchResults: [FFMovie] = []
    @State private var isSearching = false
    @State private var isSaving = false

    init(viewModel: ProfileViewModel, initialIds: [Int]) {
        self.viewModel = viewModel
        _selectedIds = State(initialValue: Array(initialIds.prefix(4)))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: FFSpacing.xl) {
                        selectionStrip
                        searchField
                        pickerList
                        Spacer(minLength: 80)
                    }
                    .padding(.vertical, FFSpacing.md)
                }
            }
            .navigationTitle("Pinned Favorites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(FFColors.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView().tint(FFColors.goldPrimary)
                        } else {
                            Text("Save").fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(FFColors.goldPrimary)
                    .disabled(isSaving)
                }
            }
            .task {
                await seenService.hydrateMissingMetadata(tmdbIds: Set(selectedIds), limit: 4)
            }
            .onChange(of: searchText) { _, newValue in
                Task {
                    if newValue.trimmingCharacters(in: .whitespaces).isEmpty {
                        searchResults = []
                        return
                    }
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    if searchText == newValue {
                        await runSearch(query: newValue)
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private var selectionStrip: some View {
        VStack(alignment: .leading, spacing: FFSpacing.sm) {
            HStack {
                Text("Your Picks")
                    .font(FFTypography.headlineSmall)
                    .foregroundColor(FFColors.textPrimary)
                Spacer()
                Text("\(selectedIds.count)/4")
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textTertiary)
            }
            .padding(.horizontal)

            HStack(spacing: FFSpacing.sm) {
                ForEach(0..<4, id: \.self) { slot in
                    if slot < selectedIds.count {
                        selectedTile(tmdbId: selectedIds[slot])
                    } else {
                        emptyTile
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func selectedTile(tmdbId: Int) -> some View {
        Button {
            withAnimation { selectedIds.removeAll { $0 == tmdbId } }
        } label: {
            Group {
                if let posterURL = seenService.cachedMovie(for: tmdbId)?.posterURL {
                    CachedAsyncImage(url: posterURL) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(FFColors.backgroundElevated)
                            .shimmer()
                    }
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(FFColors.backgroundElevated)
                        .overlay {
                            Image(systemName: "film")
                                .foregroundColor(FFColors.textTertiary)
                        }
                }
            }
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .topTrailing) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .background(Circle().fill(Color.black.opacity(0.55)))
                    .padding(4)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(FFColors.goldPrimary, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
    }

    private var emptyTile: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(FFColors.backgroundElevated.opacity(0.4))
            .overlay {
                Image(systemName: "plus")
                    .font(.system(size: 22))
                    .foregroundColor(FFColors.textTertiary)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        style: StrokeStyle(lineWidth: 1, dash: [4])
                    )
                    .foregroundColor(FFColors.textTertiary.opacity(0.4))
            }
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .frame(maxWidth: .infinity)
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(FFColors.textTertiary)
            TextField("Search TMDB…", text: $searchText)
                .textFieldStyle(.plain)
                .foregroundColor(FFColors.textPrimary)
                .autocorrectionDisabled()
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
        }
        .padding(FFSpacing.md)
        .background {
            RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                .fill(FFColors.backgroundElevated)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var pickerList: some View {
        let query = searchText.trimmingCharacters(in: .whitespaces)

        if !query.isEmpty {
            VStack(alignment: .leading, spacing: FFSpacing.sm) {
                HStack {
                    Text("Results")
                        .font(FFTypography.labelMedium)
                        .foregroundColor(FFColors.textSecondary)
                    Spacer()
                    if isSearching {
                        InlineLoader(size: 12)
                    }
                }
                .padding(.horizontal)

                if searchResults.isEmpty && !isSearching {
                    Text("No matches yet — keep typing.")
                        .font(FFTypography.caption)
                        .foregroundColor(FFColors.textTertiary)
                        .padding(.horizontal)
                } else {
                    LazyVStack(spacing: FFSpacing.sm) {
                        ForEach(searchResults) { movie in
                            pickerRow(for: movie)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: FFSpacing.md) {
                Text("From your lists")
                    .font(FFTypography.headlineSmall)
                    .foregroundColor(FFColors.textPrimary)
                    .padding(.horizontal)

                let ids = myMovieSuggestions()
                if ids.isEmpty {
                    Text("Search above to find movies to pin.")
                        .font(FFTypography.caption)
                        .foregroundColor(FFColors.textTertiary)
                        .padding(.horizontal)
                } else {
                    LazyVStack(spacing: FFSpacing.sm) {
                        ForEach(ids, id: \.self) { tmdbId in
                            if let cached = seenService.cachedMovie(for: tmdbId) {
                                pickerRow(for: cached.toFFMovie())
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private func pickerRow(for movie: FFMovie) -> some View {
        let isSelected = selectedIds.contains(movie.tmdbId)
        let canSelect = isSelected || selectedIds.count < 4

        return Button {
            toggleSelection(movie)
        } label: {
            HStack(spacing: FFSpacing.md) {
                Group {
                    if let url = movie.posterURL {
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
                .frame(width: 44, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 2) {
                    Text(movie.title)
                        .font(FFTypography.titleSmall)
                        .foregroundColor(FFColors.textPrimary)
                        .lineLimit(1)
                    if let year = movie.year {
                        Text(String(year))
                            .font(FFTypography.caption)
                            .foregroundColor(FFColors.textTertiary)
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? FFColors.goldPrimary : (canSelect ? FFColors.textSecondary : FFColors.textTertiary.opacity(0.5)))
            }
            .padding(FFSpacing.sm)
            .background {
                RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                    .fill(FFColors.backgroundElevated.opacity(isSelected ? 0.8 : 0.4))
            }
        }
        .buttonStyle(.plain)
        .disabled(!canSelect)
        .opacity(canSelect ? 1 : 0.55)
    }

    // MARK: - Logic

    private func toggleSelection(_ movie: FFMovie) {
        if let idx = selectedIds.firstIndex(of: movie.tmdbId) {
            selectedIds.remove(at: idx)
        } else if selectedIds.count < 4 {
            selectedIds.append(movie.tmdbId)
            // Cache so the tile renders immediately.
            seenService.cacheMovie(movie)
        }
    }

    private func runSearch(query: String) async {
        isSearching = true
        defer { isSearching = false }
        do {
            let response = try await TMDBService.shared.searchMovies(query: query, page: 1)
            searchResults = response.results.map { TMDBService.shared.convertToFFMovie($0) }
        } catch {
            searchResults = []
        }
    }

    /// Suggest picks from what we already know about — user's diary, watched, ratings,
    /// and watchlist. Surfacing these first makes the common case (favoriting something
    /// you've already logged) a single tap.
    private func myMovieSuggestions() -> [Int] {
        var seen: Set<Int> = []
        var ordered: [Int] = []

        // Highest-rated first.
        let byRating = seenService.ratings
            .sorted { $0.value > $1.value }
            .map { $0.key }
        for id in byRating where seen.insert(id).inserted {
            ordered.append(id)
        }
        for entry in seenService.diary where seen.insert(entry.tmdbId).inserted {
            ordered.append(entry.tmdbId)
        }
        for id in seenService.seenTmdbIds where seen.insert(id).inserted {
            ordered.append(id)
        }
        for id in seenService.watchlist where seen.insert(id).inserted {
            ordered.append(id)
        }
        return Array(ordered.prefix(50))
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        let ok = await viewModel.updateFavoriteMovies(selectedIds)
        if ok { dismiss() }
    }
}
