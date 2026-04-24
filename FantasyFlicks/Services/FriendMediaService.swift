//
//  FriendMediaService.swift
//  FantasyFlicks
//
//  Fetches another user's media lists (diary, watched, watchlist, ratings)
//  from Firestore for display in their profile.
//

import Foundation
import FirebaseFirestore

/// Snapshot of another user's movie lists.
struct FriendMediaSnapshot {
    var seenIds: Set<Int>
    var watchlistIds: Set<Int>
    var ratings: [Int: Double]
    var diary: [DiaryEntry]
    var cache: [Int: CachedMovie]
    /// Friend's custom-poster picks for their pinned favorites. Lets their
    /// chosen artwork render on your screen.
    var favoritePosterOverrides: [Int: String]

    func cachedMovie(for tmdbId: Int) -> CachedMovie? {
        if let entry = cache[tmdbId] { return entry }
        if let diaryEntry = diary.first(where: { $0.tmdbId == tmdbId }) {
            return CachedMovie(
                id: tmdbId,
                title: diaryEntry.title,
                posterPath: diaryEntry.posterPath,
                year: nil,
                voteAverage: nil
            )
        }
        return nil
    }

    static let empty = FriendMediaSnapshot(
        seenIds: [], watchlistIds: [], ratings: [:], diary: [], cache: [:], favoritePosterOverrides: [:]
    )
}

@MainActor
final class FriendMediaService {

    static let shared = FriendMediaService()

    private let db = Firestore.firestore()

    private init() {}

    /// Load a friend's media lists from their Firestore user doc.
    func fetchMediaSnapshot(for userId: String) async throws -> FriendMediaSnapshot {
        let snapshot = try await db.collection("users").document(userId).getDocument()
        guard let data = snapshot.data() else {
            return .empty
        }

        let seenIds = Set(data["mediaSeenIds"] as? [Int] ?? [])
        let watchlistIds = Set(data["mediaWatchlistIds"] as? [Int] ?? [])

        // Ratings stored as [String: Double] (new) or [String: Int] (legacy);
        // convert keys back to Int and coerce values to Double.
        let ratingsRaw = data["mediaRatings"] as? [String: Any] ?? [:]
        let ratings = ratingsRaw.reduce(into: [Int: Double]()) { result, pair in
            guard let key = Int(pair.key) else { return }
            if let dbl = pair.value as? Double {
                result[key] = dbl
            } else if let int = pair.value as? Int {
                result[key] = Double(int)
            } else if let num = pair.value as? NSNumber {
                result[key] = num.doubleValue
            }
        }

        // Diary + cache stored as JSON strings
        let decoder = JSONDecoder()

        let diary: [DiaryEntry]
        if let diaryString = data["mediaDiaryJSON"] as? String,
           let diaryData = diaryString.data(using: .utf8),
           let decoded = try? decoder.decode([DiaryEntry].self, from: diaryData) {
            diary = decoded
        } else {
            diary = []
        }

        var cache: [Int: CachedMovie] = [:]
        if let cacheString = data["mediaCacheJSON"] as? String,
           let cacheData = cacheString.data(using: .utf8),
           let decoded = try? decoder.decode([CachedMovie].self, from: cacheData) {
            cache = Dictionary(uniqueKeysWithValues: decoded.map { ($0.id, $0) })
        }

        // Backfill cache from diary so older data still renders
        for entry in diary where cache[entry.tmdbId] == nil {
            cache[entry.tmdbId] = CachedMovie(
                id: entry.tmdbId,
                title: entry.title,
                posterPath: entry.posterPath,
                year: nil,
                voteAverage: nil
            )
        }

        let rawOverrides = data["favoritePosterOverrides"] as? [String: String] ?? [:]
        let overrides = rawOverrides.reduce(into: [Int: String]()) { result, pair in
            if let key = Int(pair.key) { result[key] = pair.value }
        }

        return FriendMediaSnapshot(
            seenIds: seenIds,
            watchlistIds: watchlistIds,
            ratings: ratings,
            diary: diary,
            cache: cache,
            favoritePosterOverrides: overrides
        )
    }
}
