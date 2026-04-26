//
//  MovieListsService.swift
//  FantasyFlicks
//
//  Create, edit, and browse user-made movie lists (Spotify-playlist style
//  collections). Persists locally + to Firestore when authenticated.
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class MovieListsService: ObservableObject {

    static let shared = MovieListsService()

    @Published private(set) var userLists: [MovieList] = []
    @Published private(set) var curatedLists: [MovieList] = CuratedMovieLists.all

    private let db = Firestore.firestore()
    private let localKey = "ff_user_movie_lists"

    private init() {
        loadLocal()
    }

    // MARK: - Public API

    /// All lists visible on the user's own Movies tab — curated first, then
    /// their own creations sorted by most-recently updated.
    var allVisibleLists: [MovieList] {
        curatedLists + userLists.sorted { $0.updatedAt > $1.updatedAt }
    }

    func list(for id: String) -> MovieList? {
        if let curated = curatedLists.first(where: { $0.id == id }) { return curated }
        return userLists.first(where: { $0.id == id })
    }

    /// Create a new empty user-owned list. Returns the new list so the caller
    /// can push them straight into editing it.
    func createList(name: String, subtitle: String? = nil, isPublic: Bool = false) -> MovieList {
        let ownerId = AuthenticationService.shared.currentUser?.id ?? "local"
        let list = MovieList(
            ownerId: ownerId,
            name: name.trimmingCharacters(in: .whitespaces),
            subtitle: subtitle?.trimmingCharacters(in: .whitespaces),
            isPublic: isPublic
        )
        userLists.append(list)
        persist()
        return list
    }

    func updateList(_ list: MovieList) {
        guard !list.isCurated else { return }
        var updated = list
        updated.updatedAt = Date()
        if let idx = userLists.firstIndex(where: { $0.id == list.id }) {
            userLists[idx] = updated
        } else {
            userLists.append(updated)
        }
        persist()
    }

    func deleteList(id: String) {
        userLists.removeAll { $0.id == id && !$0.isCurated }
        persist()
    }

    /// Toggle a movie's membership in a list. Creates the list if needed.
    func toggleMovie(tmdbId: Int, in listId: String) {
        guard let idx = userLists.firstIndex(where: { $0.id == listId }) else { return }
        var list = userLists[idx]
        if let removeIdx = list.movieIds.firstIndex(of: tmdbId) {
            list.movieIds.remove(at: removeIdx)
        } else {
            list.movieIds.append(tmdbId)
        }
        list.updatedAt = Date()
        if list.coverPosterPath == nil,
           let firstId = list.movieIds.first,
           let cached = SeenMoviesService.shared.cachedMovie(for: firstId) {
            list.coverPosterPath = cached.posterPath
        }
        userLists[idx] = list
        persist()
    }

    /// Reorder movies within a list (drag-and-drop support).
    func reorderMovies(in listId: String, fromIndex: Int, toIndex: Int) {
        guard let idx = userLists.firstIndex(where: { $0.id == listId }) else { return }
        var list = userLists[idx]
        guard fromIndex < list.movieIds.count, toIndex <= list.movieIds.count else { return }
        let movie = list.movieIds.remove(at: fromIndex)
        let clampedTo = min(toIndex, list.movieIds.count)
        list.movieIds.insert(movie, at: clampedTo)
        list.updatedAt = Date()
        userLists[idx] = list
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        if let data = try? JSONEncoder().encode(userLists) {
            UserDefaults.standard.set(data, forKey: localKey)
        }
        Task { await pushToFirestore() }
    }

    private func loadLocal() {
        guard let data = UserDefaults.standard.data(forKey: localKey),
              let decoded = try? JSONDecoder().decode([MovieList].self, from: data) else { return }
        userLists = decoded
    }

    private func pushToFirestore() async {
        guard let userId = AuthenticationService.shared.currentUser?.id else { return }
        guard let payload = (try? JSONEncoder().encode(userLists)).flatMap({ String(data: $0, encoding: .utf8) }) else { return }
        try? await db.collection("users").document(userId).updateData([
            "movieListsJSON": payload,
            "movieListsUpdatedAt": Timestamp(date: Date())
        ])
    }
}
