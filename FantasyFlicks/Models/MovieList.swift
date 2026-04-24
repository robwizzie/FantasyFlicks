//
//  MovieList.swift
//  FantasyFlicks
//
//  A user-created or curated collection of movies (Letterboxd-style lists).
//  Stored per-user in UserDefaults + mirrored to Firestore so friends can
//  browse public lists later.
//

import Foundation

struct MovieList: Codable, Identifiable, Hashable, Sendable {
    let id: String
    /// Owner user id, or "system" for curated lists shipped with the app.
    var ownerId: String
    var name: String
    var subtitle: String?
    /// Ordered TMDB IDs. Kept as [Int] for easy JSON + Firestore storage.
    var movieIds: [Int]
    /// When true, visible to friends on the user's profile.
    var isPublic: Bool
    /// Curated (system-owned) lists can't be edited or deleted by the user.
    var isCurated: Bool
    /// Optional cover art (TMDB poster path) — nice for Spotify-playlist style tiles.
    var coverPosterPath: String?
    let createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        ownerId: String,
        name: String,
        subtitle: String? = nil,
        movieIds: [Int] = [],
        isPublic: Bool = false,
        isCurated: Bool = false,
        coverPosterPath: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.ownerId = ownerId
        self.name = name
        self.subtitle = subtitle
        self.movieIds = movieIds
        self.isPublic = isPublic
        self.isCurated = isCurated
        self.coverPosterPath = coverPosterPath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Seed curated collections shipped with the app. User sees these up front
/// so the Movies tab never looks empty, even for brand-new accounts.
enum CuratedMovieLists {
    static let all: [MovieList] = [
        MovieList(
            id: "curated.a24",
            ownerId: "system",
            name: "A24 Essentials",
            subtitle: "Indie hits, auteur picks, horror gems",
            isCurated: true
        ),
        MovieList(
            id: "curated.nolan",
            ownerId: "system",
            name: "Christopher Nolan",
            subtitle: "Every feature, biggest to smallest",
            isCurated: true
        ),
        MovieList(
            id: "curated.kids",
            ownerId: "system",
            name: "Family Night",
            subtitle: "Kid-friendly picks the whole room will watch",
            isCurated: true
        ),
        MovieList(
            id: "curated.animated",
            ownerId: "system",
            name: "Top Animation",
            subtitle: "Feature animation from Pixar, Ghibli, and beyond",
            isCurated: true
        ),
        MovieList(
            id: "curated.horror",
            ownerId: "system",
            name: "Halloween Picks",
            subtitle: "Modern horror with teeth",
            isCurated: true
        ),
        MovieList(
            id: "curated.oscars",
            ownerId: "system",
            name: "Best Picture Winners",
            subtitle: "Academy Award Best Picture — recent decades",
            isCurated: true
        )
    ]
}
