//
//  MovieListDetailView.swift
//  FantasyFlicks
//
//  Detail + edit view for a user-created movie collection.
//

import SwiftUI
import UniformTypeIdentifiers

struct MovieListDetailView: View {
    let listId: String
    @StateObject private var listsService = MovieListsService.shared
    @StateObject private var seenService = SeenMoviesService.shared
    @State private var selectedMovie: FFMovie?
    @State private var showAddSearch = false
    @State private var showEditMetadata = false

    private var list: MovieList? { listsService.list(for: listId) }

    var body: some View {
        ZStack {
            FFColors.backgroundDark.ignoresSafeArea()

            if let list {
                ScrollView {
                    VStack(alignment: .leading, spacing: FFSpacing.lg) {
                        header(list: list)
                        if list.movieIds.isEmpty {
                            emptyState
                        } else {
                            listContent(list: list)
                        }
                        Spacer(minLength: 80)
                    }
                }
            } else {
                Text("List not found")
                    .foregroundColor(FFColors.textSecondary)
            }
        }
        .navigationTitle(list?.name ?? "Collection")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let list, !list.isCurated {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showAddSearch = true
                        } label: {
                            Label("Add Movie", systemImage: "plus")
                        }
                        Button {
                            showEditMetadata = true
                        } label: {
                            Label("Rename / Edit", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            listsService.deleteList(id: list.id)
                        } label: {
                            Label("Delete Collection", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(FFColors.goldPrimary)
                    }
                }
            }
        }
        .task {
            if let list {
                await seenService.hydrateMissingMetadata(tmdbIds: list.movieIds, limit: 50)
            }
        }
        .sheet(isPresented: $showAddSearch) {
            AddToListSearchSheet(listId: listId)
        }
        .sheet(isPresented: $showEditMetadata) {
            if let list {
                EditMovieListSheet(list: list)
            }
        }
        .sheet(item: $selectedMovie) { movie in
            NavigationStack { MovieDetailView(movie: movie) }
        }
    }

    private func header(list: MovieList) -> some View {
        VStack(alignment: .leading, spacing: FFSpacing.xs) {
            if let subtitle = list.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(FFTypography.bodyMedium)
                    .foregroundColor(FFColors.textSecondary)
            }
            HStack(spacing: FFSpacing.sm) {
                Text("\(list.movieIds.count) \(list.movieIds.count == 1 ? "movie" : "movies")")
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textTertiary)
                if list.isPublic {
                    Text("Public")
                        .font(FFTypography.caption)
                        .foregroundColor(FFColors.goldPrimary)
                }
                if list.isCurated {
                    Text("Curated")
                        .font(FFTypography.caption)
                        .foregroundColor(FFColors.goldLight)
                }
            }
        }
        .padding(.horizontal)
    }

    private func listContent(list: MovieList) -> some View {
        LazyVStack(spacing: FFSpacing.sm) {
            ForEach(Array(list.movieIds.enumerated()), id: \.element) { index, tmdbId in
                if let cached = seenService.cachedMovie(for: tmdbId) {
                    Button {
                        selectedMovie = cached.toFFMovie()
                    } label: {
                        row(cached: cached, index: index, list: list)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .onDrag {
                        NSItemProvider(object: "\(index)" as NSString)
                    }
                    .onDrop(of: [.plainText], delegate: ListReorderDropDelegate(
                        destinationIndex: index,
                        listId: listId,
                        listsService: listsService
                    ))
                }
            }
        }
        .padding(.horizontal)
    }

    private func row(cached: CachedMovie, index: Int, list: MovieList) -> some View {
        HStack(spacing: FFSpacing.md) {
            Text("\(index + 1)")
                .font(FFTypography.labelMedium)
                .foregroundColor(FFColors.textTertiary)
                .frame(width: 24)
            Group {
                if let url = cached.posterURL {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 6).fill(FFColors.backgroundElevated)
                    }
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(FFColors.backgroundElevated)
                        .overlay { Image(systemName: "film").foregroundColor(FFColors.textTertiary) }
                }
            }
            .frame(width: 44, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(cached.title)
                    .font(FFTypography.labelMedium)
                    .foregroundColor(FFColors.textPrimary)
                    .lineLimit(2)
                if let year = cached.year {
                    Text(String(year))
                        .font(FFTypography.caption)
                        .foregroundColor(FFColors.textTertiary)
                }
            }
            Spacer()

            if !list.isCurated {
                Button {
                    listsService.toggleMovie(tmdbId: cached.id, in: listId)
                } label: {
                    Image(systemName: "minus.circle")
                        .foregroundColor(FFColors.ruby.opacity(0.8))
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
            }
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 13))
                .foregroundColor(FFColors.textTertiary.opacity(0.5))
        }
        .padding(FFSpacing.md)
        .background {
            RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                .fill(FFColors.backgroundElevated.opacity(0.5))
        }
    }

    private var emptyState: some View {
        VStack(spacing: FFSpacing.md) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 40))
                .foregroundColor(FFColors.textTertiary)
            Text("No movies yet")
                .font(FFTypography.titleMedium)
                .foregroundColor(FFColors.textSecondary)
            Button {
                showAddSearch = true
            } label: {
                Text("Add a Movie")
                    .font(FFTypography.labelMedium)
                    .foregroundColor(FFColors.goldPrimary)
                    .padding(.horizontal, FFSpacing.lg)
                    .padding(.vertical, 8)
                    .background(FFColors.goldPrimary.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, FFSpacing.xxl)
    }
}

// MARK: - Reorder delegate

private struct ListReorderDropDelegate: DropDelegate {
    let destinationIndex: Int
    let listId: String
    let listsService: MovieListsService

    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [.plainText]).first else { return false }
        _ = provider.loadObject(ofClass: NSString.self) { item, _ in
            guard let str = item as? String, let source = Int(str) else { return }
            Task { @MainActor in
                listsService.reorderMovies(in: listId, fromIndex: source, toIndex: destinationIndex)
            }
        }
        return true
    }
}

// MARK: - Add to List search sheet

struct AddToListSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    let listId: String
    @StateObject private var listsService = MovieListsService.shared
    @StateObject private var seenService = SeenMoviesService.shared

    @State private var searchText: String = ""
    @State private var results: [FFMovie] = []
    @State private var isSearching = false

    private var list: MovieList? { listsService.list(for: listId) }

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: FFSpacing.md) {
                        ForEach(results) { movie in
                            let isIn = list?.movieIds.contains(movie.tmdbId) ?? false
                            Button {
                                seenService.cacheMovie(movie)
                                listsService.toggleMovie(tmdbId: movie.tmdbId, in: listId)
                            } label: {
                                HStack(spacing: FFSpacing.md) {
                                    if let url = movie.posterURL {
                                        CachedAsyncImage(url: url) { image in
                                            image.resizable().aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            RoundedRectangle(cornerRadius: 6).fill(FFColors.backgroundElevated)
                                        }
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
                                    Image(systemName: isIn ? "checkmark.circle.fill" : "plus.circle")
                                        .foregroundColor(isIn ? FFColors.goldPrimary : FFColors.textSecondary)
                                        .font(.system(size: 20))
                                }
                                .padding(FFSpacing.md)
                                .background {
                                    RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                                        .fill(FFColors.backgroundElevated.opacity(0.5))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Add Movies")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search TMDB")
            .onChange(of: searchText) { _, newValue in
                Task {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    guard searchText == newValue else { return }
                    await search(newValue)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(FFColors.goldPrimary)
                }
            }
        }
    }

    private func search(_ query: String) async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else {
            results = []
            return
        }
        isSearching = true
        defer { isSearching = false }
        do {
            let response = try await TMDBService.shared.searchMovies(query: q, page: 1)
            results = response.results.map { TMDBService.shared.convertToFFMovie($0) }
        } catch {
            results = []
        }
    }
}

// MARK: - Edit metadata sheet

struct EditMovieListSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var listsService = MovieListsService.shared
    let list: MovieList

    @State private var name: String
    @State private var subtitle: String
    @State private var isPublic: Bool

    init(list: MovieList) {
        self.list = list
        _name = State(initialValue: list.name)
        _subtitle = State(initialValue: list.subtitle ?? "")
        _isPublic = State(initialValue: list.isPublic)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()
                Form {
                    Section("Name") {
                        TextField("Collection name", text: $name)
                    }
                    Section("Description") {
                        TextField("Optional", text: $subtitle)
                    }
                    Section {
                        Toggle("Public on my profile", isOn: $isPublic)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Edit Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        var updated = list
                        updated.name = name.trimmingCharacters(in: .whitespaces)
                        let trimmedSubtitle = subtitle.trimmingCharacters(in: .whitespaces)
                        updated.subtitle = trimmedSubtitle.isEmpty ? nil : trimmedSubtitle
                        updated.isPublic = isPublic
                        listsService.updateList(updated)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Create new list sheet

struct CreateMovieListSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var listsService = MovieListsService.shared

    @State private var name: String = ""
    @State private var subtitle: String = ""
    @State private var isPublic: Bool = false
    var onCreate: ((MovieList) -> Void)? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()
                Form {
                    Section("Name") {
                        TextField("e.g. Rainy Day Classics", text: $name)
                    }
                    Section("Description") {
                        TextField("Optional", text: $subtitle)
                    }
                    Section {
                        Toggle("Public on my profile", isOn: $isPublic)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") {
                        let trimmedSubtitle = subtitle.trimmingCharacters(in: .whitespaces)
                        let list = listsService.createList(
                            name: name,
                            subtitle: trimmedSubtitle.isEmpty ? nil : trimmedSubtitle,
                            isPublic: isPublic
                        )
                        onCreate?(list)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
