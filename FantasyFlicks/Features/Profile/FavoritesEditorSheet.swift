//
//  FavoritesEditorSheet.swift
//  FantasyFlicks
//
//  Letterboxd-style favorites editor. Users pick up to 4 pinned movies
//  from their existing watched/watchlist/ratings lists or by searching
//  TMDB, drag to reorder them, and optionally pick an alternate poster
//  for any pinned title that has multiple artworks on TMDB.
//

import SwiftUI
import UniformTypeIdentifiers

struct FavoritesEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ProfileViewModel

    @StateObject private var seenService = SeenMoviesService.shared

    @State private var selectedIds: [Int]
    @State private var searchText: String = ""
    @State private var searchResults: [FFMovie] = []
    @State private var isSearching = false
    @State private var isSaving = false
    @State private var posterPickerTarget: Int?

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
                        reorderHint
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
            .sheet(item: Binding(
                get: { posterPickerTarget.map { PosterPickerContext(tmdbId: $0) } },
                set: { posterPickerTarget = $0?.tmdbId }
            )) { context in
                AlternatePosterPickerSheet(tmdbId: context.tmdbId)
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
                        let tmdbId = selectedIds[slot]
                        selectedTile(tmdbId: tmdbId)
                            .onDrag {
                                // Ship the index so the drop zone knows what moved.
                                NSItemProvider(object: "\(slot)" as NSString)
                            }
                            .onDrop(of: [.plainText], delegate: ReorderDropDelegate(
                                destinationIndex: slot,
                                selectedIds: $selectedIds
                            ))
                    } else {
                        emptyTile
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var reorderHint: some View {
        HStack(spacing: 6) {
            Image(systemName: "hand.draw")
                .font(.system(size: 11, weight: .semibold))
            Text("Hold and drag to reorder · Tap the paintbrush to swap poster")
                .font(FFTypography.caption)
        }
        .foregroundColor(FFColors.textTertiary)
        .padding(.horizontal)
    }

    private func selectedTile(tmdbId: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let posterURL = seenService.favoritePosterURL(for: tmdbId) {
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
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(FFColors.goldPrimary, lineWidth: 1.5)
            }

            // Two corner actions: remove and alt-poster picker.
            VStack(spacing: 4) {
                Button {
                    withAnimation { selectedIds.removeAll { $0 == tmdbId } }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .background(Circle().fill(Color.black.opacity(0.55)))
                }
                .buttonStyle(.plain)

                Button {
                    posterPickerTarget = tmdbId
                } label: {
                    Image(systemName: "paintbrush.fill")
                        .font(.system(size: 10))
                        .foregroundColor(FFColors.goldPrimary)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.black.opacity(0.55)))
                }
                .buttonStyle(.plain)
            }
            .padding(4)
        }
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

// MARK: - Reorder Drop Delegate

/// Drop delegate that swaps the dragged slot into the hovered destination.
/// Kept simple — SwiftUI's built-in `.onMove` requires editing inside a List,
/// which doesn't fit the horizontal 4-tile layout.
private struct ReorderDropDelegate: DropDelegate {
    let destinationIndex: Int
    @Binding var selectedIds: [Int]

    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [.plainText]).first else { return false }
        _ = provider.loadObject(ofClass: NSString.self) { item, _ in
            guard let indexString = item as? String,
                  let sourceIndex = Int(indexString),
                  sourceIndex != destinationIndex,
                  sourceIndex < selectedIds.count,
                  destinationIndex < selectedIds.count
            else { return }
            Task { @MainActor in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    let moved = selectedIds.remove(at: sourceIndex)
                    selectedIds.insert(moved, at: destinationIndex)
                }
            }
        }
        return true
    }
}

// MARK: - Alternate Poster Picker

private struct PosterPickerContext: Identifiable {
    let tmdbId: Int
    var id: Int { tmdbId }
}

/// Lets the user swap the poster shown for a pinned favorite to any of the
/// alternate artworks TMDB has on file. Persists via
/// `SeenMoviesService.setFavoritePosterOverride`.
struct AlternatePosterPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let tmdbId: Int
    @StateObject private var seenService = SeenMoviesService.shared

    @State private var posters: [TMDBImage] = []
    @State private var isLoading = true
    @State private var selectedPath: String?

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()

                if isLoading && posters.isEmpty {
                    ProgressView()
                        .tint(FFColors.goldPrimary)
                } else if posters.isEmpty {
                    VStack(spacing: FFSpacing.md) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 40))
                            .foregroundColor(FFColors.textTertiary)
                        Text("No alternate posters available")
                            .font(FFTypography.bodyMedium)
                            .foregroundColor(FFColors.textSecondary)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: FFSpacing.md),
                            GridItem(.flexible(), spacing: FFSpacing.md),
                            GridItem(.flexible(), spacing: FFSpacing.md)
                        ], spacing: FFSpacing.md) {
                            ForEach(posters) { poster in
                                posterTile(poster)
                            }
                        }
                        .padding(FFSpacing.md)
                    }
                }
            }
            .navigationTitle("Choose Poster")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(FFColors.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Default") {
                        seenService.setFavoritePosterOverride(tmdbId: tmdbId, posterPath: nil)
                        dismiss()
                    }
                    .foregroundColor(FFColors.goldPrimary)
                }
            }
            .task {
                selectedPath = seenService.favoritePosterOverrides[tmdbId]
                await loadPosters()
            }
        }
    }

    private func posterTile(_ poster: TMDBImage) -> some View {
        let isActive = poster.filePath == selectedPath
        let url = URL(string: "\(APIConfiguration.TMDB.imageBaseURL)/\(APIConfiguration.TMDB.PosterSize.medium.rawValue)\(poster.filePath)")

        return Button {
            seenService.setFavoritePosterOverride(tmdbId: tmdbId, posterPath: poster.filePath)
            selectedPath = poster.filePath
            dismiss()
        } label: {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let url {
                        CachedAsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(FFColors.backgroundElevated)
                                .shimmer()
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(FFColors.backgroundElevated)
                    }
                }
                .aspectRatio(2.0 / 3.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isActive ? FFColors.goldPrimary : Color.white.opacity(0.1),
                                lineWidth: isActive ? 2.5 : 0.5)
                }

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(FFColors.goldPrimary)
                        .background(Circle().fill(FFColors.backgroundDark))
                        .padding(4)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func loadPosters() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await TMDBService.shared.getMovieImages(id: tmdbId)
            // TMDB returns posters scored by vote average — surface the best ones first.
            posters = response.posters.sorted { ($0.voteAverage ?? 0) > ($1.voteAverage ?? 0) }
        } catch {
            posters = []
        }
    }
}
