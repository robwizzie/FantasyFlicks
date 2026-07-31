//
//  SeenMoviesService.swift
//  FantasyFlicks
//
//  Tracks movies the user has watched, with diary, watchlist, ratings,
//  reviews, and Letterboxd CSV import support
//

import Foundation
import SwiftUI
import Combine
import UniformTypeIdentifiers
import FirebaseFirestore

// MARK: - Diary Entry

struct DiaryEntry: Codable, Identifiable, Hashable {
    let id: String
    let tmdbId: Int
    /// Mutable so an external sync can correct the date when the source
    /// entry is edited (see `applyExternalDiaryEntry`).
    var watchedDate: Date
    // Legacy integer rating for back-compat with older saved data. New code
    // should read/write `ratingStars` which supports half-stars.
    var rating: Int?
    /// Half-star rating 0.5-5.0 (0.5 increments). When present, takes precedence over `rating`.
    var ratingStars: Double?
    var reviewText: String?
    var title: String        // cached for display without API call
    var posterPath: String?
    var isRewatch: Bool
    /// Identifier of the source entry when this was synced from an external
    /// service (currently the Letterboxd RSS guid). Lets a later sync update
    /// the same entry in place when the user edits their review or rating.
    var externalId: String?

    /// The best available rating as a Double — prefers half-star if set,
    /// otherwise falls back to the legacy integer.
    var effectiveRating: Double? {
        if let rs = ratingStars { return rs }
        if let r = rating { return Double(r) }
        return nil
    }

    /// True when the RSS sync created this entry. CSV backfill tags entries
    /// with their Letterboxd URI instead, and hand-logged watches carry no tag
    /// at all — the sync is allowed to adopt both of those, but must never
    /// overwrite a different entry it created itself.
    var isLetterboxdFeedEntry: Bool {
        externalId?.hasPrefix("letterboxd-entry-") == true
    }

    init(tmdbId: Int, watchedDate: Date = Date(), rating: Int? = nil,
         ratingStars: Double? = nil, reviewText: String? = nil,
         title: String, posterPath: String? = nil, isRewatch: Bool = false,
         externalId: String? = nil) {
        self.id = UUID().uuidString
        self.tmdbId = tmdbId
        self.watchedDate = watchedDate
        self.rating = rating
        self.ratingStars = ratingStars
        self.reviewText = reviewText
        self.title = title
        self.posterPath = posterPath
        self.isRewatch = isRewatch
        self.externalId = externalId
    }

    enum CodingKeys: String, CodingKey {
        case id, tmdbId, watchedDate, rating, ratingStars, reviewText, title, posterPath, isRewatch
        case externalId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        tmdbId = try c.decode(Int.self, forKey: .tmdbId)
        watchedDate = try c.decode(Date.self, forKey: .watchedDate)
        rating = try c.decodeIfPresent(Int.self, forKey: .rating)
        ratingStars = try c.decodeIfPresent(Double.self, forKey: .ratingStars)
        reviewText = try c.decodeIfPresent(String.self, forKey: .reviewText)
        title = try c.decode(String.self, forKey: .title)
        posterPath = try c.decodeIfPresent(String.self, forKey: .posterPath)
        isRewatch = try c.decodeIfPresent(Bool.self, forKey: .isRewatch) ?? false
        externalId = try c.decodeIfPresent(String.self, forKey: .externalId)
    }

    var posterURL: URL? {
        guard let posterPath else { return nil }
        return URL(string: "\(APIConfiguration.TMDB.imageBaseURL)/\(APIConfiguration.TMDB.PosterSize.medium.rawValue)\(posterPath)")
    }
}

// MARK: - Cached Movie Metadata

/// Minimal movie metadata we persist locally so lists can render posters/titles
/// without needing a TMDB lookup on every open.
struct CachedMovie: Codable, Identifiable, Hashable {
    let id: Int            // tmdbId
    var title: String
    var posterPath: String?
    var backdropPath: String?
    var year: Int?
    var voteAverage: Double?

    var posterURL: URL? {
        guard let posterPath else { return nil }
        return URL(string: "\(APIConfiguration.TMDB.imageBaseURL)/\(APIConfiguration.TMDB.PosterSize.medium.rawValue)\(posterPath)")
    }

    var backdropURL: URL? {
        guard let backdropPath else { return nil }
        return URL(string: "\(APIConfiguration.TMDB.imageBaseURL)/w1280\(backdropPath)")
    }

    // Legacy decoding: tolerate old cached entries without backdropPath
    enum CodingKeys: String, CodingKey {
        case id, title, posterPath, backdropPath, year, voteAverage
    }

    init(id: Int, title: String, posterPath: String? = nil, backdropPath: String? = nil, year: Int? = nil, voteAverage: Double? = nil) {
        self.id = id
        self.title = title
        self.posterPath = posterPath
        self.backdropPath = backdropPath
        self.year = year
        self.voteAverage = voteAverage
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        posterPath = try c.decodeIfPresent(String.self, forKey: .posterPath)
        backdropPath = try c.decodeIfPresent(String.self, forKey: .backdropPath)
        year = try c.decodeIfPresent(Int.self, forKey: .year)
        voteAverage = try c.decodeIfPresent(Double.self, forKey: .voteAverage)
    }
}

// MARK: - Letterboxd Import Result

/// Outcome of importing one Letterboxd CSV.
///
/// Deliberately separates "we couldn't read the file", "we read it but it had
/// no film rows" and "we had rows but TMDB matched none of them". These used to
/// collapse into a bare `0`, which made a tokenizer bug that swallowed every
/// row present as a TMDB matching problem.
struct LetterboxdImportResult: Sendable {
    /// Films matched on TMDB and written to the local stores.
    var matched: Int = 0
    /// Rows we parsed but couldn't confidently match, by title.
    var unmatchedTitles: [String] = []
    /// Set when the file itself was unusable — nothing was parsed at all.
    var failureReason: String?

    /// Film rows we got out of the file, matched or not.
    var parsedRows: Int { matched + unmatchedTitles.count }

    /// Unmatched titles with a multi-file import's repeats collapsed. The same
    /// film appears in watched.csv, ratings.csv *and* diary.csv, so listing it
    /// once per file reads like three separate failures.
    var distinctUnmatchedTitles: [String] {
        var seen = Set<String>()
        return unmatchedTitles.filter { seen.insert($0.lowercased()).inserted }
    }

    var isSuccess: Bool { matched > 0 }

    /// One line the import sheet can show verbatim.
    var summary: String {
        if parsedRows == 0 {
            return failureReason ?? "No film rows in that file — pick the CSVs from your Letterboxd export."
        }
        if matched == 0 {
            return "Read \(parsedRows) \(parsedRows == 1 ? "row" : "rows") but couldn't match any on TMDB. Check your connection and try again."
        }
        let films = "Imported \(matched) \(matched == 1 ? "movie" : "movies")"
        let skipped = distinctUnmatchedTitles.count
        guard skipped > 0 else { return films }
        return "\(films) · \(skipped) we couldn't match"
    }

    /// Combine per-file results so a multi-file selection reports one total.
    static func + (lhs: Self, rhs: Self) -> Self {
        Self(
            matched: lhs.matched + rhs.matched,
            unmatchedTitles: lhs.unmatchedTitles + rhs.unmatchedTitles,
            failureReason: lhs.failureReason ?? rhs.failureReason
        )
    }
}

// MARK: - Service

@MainActor
final class SeenMoviesService: ObservableObject {

    // MARK: - Singleton

    static let shared = SeenMoviesService()

    // MARK: - Published

    @Published var seenTmdbIds: Set<Int> = []
    @Published var ratings: [Int: Double] = [:]      // tmdbId -> 0.5-5.0 in 0.5 steps (Letterboxd-style half-stars)
    @Published var diary: [DiaryEntry] = []
    @Published var watchlist: Set<Int> = []           // tmdbId set for want-to-watch
    @Published var movieCache: [Int: CachedMovie] = [:]  // tmdbId -> cached metadata
    /// Optional user-picked poster override for a movie. When set, FavoritesRow
    /// (and anywhere else opting in) renders this poster instead of the TMDB
    /// default. Lets users swap to an alternate artwork for a pinned favorite.
    @Published var favoritePosterOverrides: [Int: String] = [:] // tmdbId -> TMDB poster path
    @Published var isImporting = false
    @Published var lastImportCount: Int?

    // MARK: - Private Keys

    private let seenKey = "ff_seen_movie_tmdb_ids"
    private let ratingsKey = "ff_movie_ratings"
    private let diaryKey = "ff_movie_diary"
    private let watchlistKey = "ff_movie_watchlist"
    private let movieCacheKey = "ff_movie_cache"
    private let favoritePosterOverridesKey = "ff_favorite_poster_overrides"

    // MARK: - Firestore Sync

    private let db = Firestore.firestore()
    private var syncTask: Task<Void, Never>?

    // MARK: - Init

    private init() {
        load()
    }

    // MARK: - Movie Metadata Cache

    /// Cache movie metadata so lists can render without re-fetching from TMDB.
    func cacheMovie(_ movie: FFMovie) {
        movieCache[movie.tmdbId] = CachedMovie(
            id: movie.tmdbId,
            title: movie.title,
            posterPath: movie.posterPath,
            backdropPath: movie.backdropPath,
            year: movie.year,
            voteAverage: movie.voteAverage
        )
        save()
    }

    /// Return cached metadata for a tmdbId, if any.
    func cachedMovie(for tmdbId: Int) -> CachedMovie? {
        if let entry = movieCache[tmdbId] { return entry }
        // Fall back to diary (older data may only exist there)
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

    /// Ensure every id in the set has cached metadata. Fetches any missing from TMDB.
    /// Pass a `limit` to cap how many movies to hydrate per call — useful for
    /// large lists where you only want to fetch what's on screen.
    /// Safe to call from any view's `.task { }`.
    ///
    /// Considers a cached entry "missing" if it has no posterPath — older app
    /// builds imported Letterboxd rows without poster info, so we need to
    /// re-fetch those even though they're already in the cache.
    func hydrateMissingMetadata(tmdbIds: some Sequence<Int>, limit: Int? = nil) async {
        let missingAll = tmdbIds.filter { id in
            guard let cached = movieCache[id] else { return true }
            return cached.posterPath == nil
        }
        guard !missingAll.isEmpty else { return }

        // Apply the per-call limit so we don't hammer TMDB on large lists.
        let missingArray: [Int]
        if let limit, limit > 0 {
            missingArray = Array(missingAll.prefix(limit))
        } else {
            missingArray = Array(missingAll)
        }

        // Fetch in batches of 10 to respect rate limits while still being reasonable.
        let batchSize = 10
        for batchStart in stride(from: 0, to: missingArray.count, by: batchSize) {
            let end = Swift.min(batchStart + batchSize, missingArray.count)
            let batch = Array(missingArray[batchStart..<end])

            await withTaskGroup(of: (Int, FFMovie?).self) { group in
                for id in batch {
                    group.addTask {
                        let movie = try? await TMDBService.shared.getFullMovie(id: id)
                        return (id, movie)
                    }
                }
                for await (_, movie) in group {
                    if let movie {
                        movieCache[movie.tmdbId] = CachedMovie(
                            id: movie.tmdbId,
                            title: movie.title,
                            posterPath: movie.posterPath,
                            backdropPath: movie.backdropPath,
                            year: movie.year,
                            voteAverage: movie.voteAverage
                        )
                    }
                }
            }
        }
        save()
    }

    // MARK: - Seen CRUD

    var count: Int { seenTmdbIds.count }

    /// Mark a movie as seen and cache its metadata.
    func markSeen(_ movie: FFMovie) {
        cacheMovie(movie)
        seenTmdbIds.insert(movie.tmdbId)
        save()
    }

    /// Toggle a movie's seen state and cache its metadata.
    func toggleSeen(_ movie: FFMovie) {
        cacheMovie(movie)
        if seenTmdbIds.contains(movie.tmdbId) {
            seenTmdbIds.remove(movie.tmdbId)
            ratings.removeValue(forKey: movie.tmdbId)
        } else {
            seenTmdbIds.insert(movie.tmdbId)
        }
        save()
    }

    /// Legacy ID-only versions (used when we only have a tmdbId, e.g. from the star rating view).

    func markSeen(tmdbId: Int) {
        seenTmdbIds.insert(tmdbId)
        save()
    }

    func markUnseen(tmdbId: Int) {
        seenTmdbIds.remove(tmdbId)
        ratings.removeValue(forKey: tmdbId)
        save()
    }

    func isSeen(tmdbId: Int) -> Bool {
        seenTmdbIds.contains(tmdbId)
    }

    func toggleSeen(tmdbId: Int) {
        if seenTmdbIds.contains(tmdbId) {
            seenTmdbIds.remove(tmdbId)
            ratings.removeValue(forKey: tmdbId)
        } else {
            seenTmdbIds.insert(tmdbId)
        }
        save()
    }

    func markMultipleSeen(tmdbIds: [Int]) {
        seenTmdbIds.formUnion(tmdbIds)
        save()
    }

    // MARK: - Ratings

    /// Set a half-star rating (0.5-5.0 in 0.5 increments). Rating auto-marks the movie
    /// as watched — you can't rate something you haven't seen.
    func setRating(tmdbId: Int, stars: Double) {
        // Snap to nearest 0.5 and clamp to valid range.
        let snapped = (stars * 2).rounded() / 2
        let clamped = max(0.5, min(5.0, snapped))
        ratings[tmdbId] = clamped
        seenTmdbIds.insert(tmdbId)
        save()
    }

    /// Convenience overload for callers still using integer ratings.
    func setRating(tmdbId: Int, stars: Int) {
        setRating(tmdbId: tmdbId, stars: Double(stars))
    }

    func removeRating(tmdbId: Int) {
        ratings.removeValue(forKey: tmdbId)
        save()
    }

    func rating(for tmdbId: Int) -> Double? {
        ratings[tmdbId]
    }

    // MARK: - Diary

    /// Add a diary entry with full half-star support.
    func addDiaryEntry(tmdbId: Int, title: String, posterPath: String? = nil,
                       watchedDate: Date = Date(), rating: Double? = nil,
                       reviewText: String? = nil, isRewatch: Bool = false) {
        let entry = DiaryEntry(
            tmdbId: tmdbId,
            watchedDate: watchedDate,
            rating: rating.map { Int($0.rounded()) },
            ratingStars: rating,
            reviewText: reviewText,
            title: title,
            posterPath: posterPath,
            isRewatch: isRewatch
        )
        diary.insert(entry, at: 0) // newest first
        seenTmdbIds.insert(tmdbId)

        // Cache metadata so other views (Watched, Ratings) can render this movie
        if movieCache[tmdbId] == nil {
            movieCache[tmdbId] = CachedMovie(
                id: tmdbId,
                title: title,
                posterPath: posterPath,
                backdropPath: nil,
                year: nil,
                voteAverage: nil
            )
        }

        if let rating { setRating(tmdbId: tmdbId, stars: rating) }
        save()
    }

    /// Legacy int overload for older callers.
    func addDiaryEntry(tmdbId: Int, title: String, posterPath: String? = nil,
                       watchedDate: Date = Date(), rating: Int? = nil,
                       reviewText: String? = nil, isRewatch: Bool = false) {
        addDiaryEntry(
            tmdbId: tmdbId, title: title, posterPath: posterPath,
            watchedDate: watchedDate, rating: rating.map { Double($0) },
            reviewText: reviewText, isRewatch: isRewatch
        )
    }

    func removeDiaryEntry(id: String) {
        diary.removeAll { $0.id == id }
        save()
    }

    // MARK: - External Sync (Letterboxd)

    /// Upsert a diary entry that originated outside the app.
    ///
    /// Matching is layered so repeat syncs never duplicate a film:
    ///   1. an entry already tagged with this `externalId` — update in place
    ///      (this is how edited reviews and re-ratings land),
    ///   2. an untagged entry for the same film on the same day — almost
    ///      certainly the same watch imported earlier from CSV, so adopt it,
    ///   3. otherwise insert a new entry.
    ///
    /// Always marks the film watched and clears it from the watchlist.
    func applyExternalDiaryEntry(
        externalId: String,
        tmdbId: Int,
        title: String,
        watchedDate: Date,
        rating: Double?,
        reviewText: String?,
        isRewatch: Bool
    ) {
        let starRating = rating.map { max(0.5, min(5.0, ($0 * 2).rounded() / 2)) }

        var index = diary.firstIndex { $0.externalId == externalId }
        if index == nil {
            index = diary.firstIndex { entry in
                // Adopt anything for this film on this day that didn't come
                // from the feed — a CSV backfill row or a hand-logged watch.
                // Feed entries are excluded so a second viewing logged on the
                // same day gets its own row instead of clobbering the first.
                !entry.isLetterboxdFeedEntry &&
                entry.tmdbId == tmdbId &&
                Calendar.current.isDate(entry.watchedDate, inSameDayAs: watchedDate)
            }
        }

        if let index {
            diary[index].externalId = externalId
            diary[index].watchedDate = watchedDate
            diary[index].ratingStars = starRating
            diary[index].rating = starRating.map { Int($0.rounded()) }
            diary[index].reviewText = reviewText
            diary[index].isRewatch = isRewatch
            // Keep the cached title fresh, but never clobber a good title with
            // a worse one if the source sent something empty.
            if !title.isEmpty { diary[index].title = title }
        } else {
            let entry = DiaryEntry(
                tmdbId: tmdbId,
                watchedDate: watchedDate,
                rating: starRating.map { Int($0.rounded()) },
                ratingStars: starRating,
                reviewText: reviewText,
                title: title,
                posterPath: movieCache[tmdbId]?.posterPath,
                isRewatch: isRewatch,
                externalId: externalId
            )
            diary.append(entry)
        }

        seenTmdbIds.insert(tmdbId)
        watchlist.remove(tmdbId)

        if let starRating {
            ratings[tmdbId] = starRating
        }

        // Stub the cache so lists can render a title immediately; the poster
        // arrives with the caller's `hydrateMissingMetadata` pass.
        if movieCache[tmdbId] == nil {
            movieCache[tmdbId] = CachedMovie(id: tmdbId, title: title)
        }

        diary.sort { $0.watchedDate > $1.watchedDate }
        save()
    }

    func diaryEntries(for tmdbId: Int) -> [DiaryEntry] {
        diary.filter { $0.tmdbId == tmdbId }
    }

    // MARK: - Watchlist

    /// Movie-aware add that caches metadata for display.
    func addToWatchlist(_ movie: FFMovie) {
        cacheMovie(movie)
        watchlist.insert(movie.tmdbId)
        save()
    }

    /// Movie-aware toggle that caches metadata for display.
    func toggleWatchlist(_ movie: FFMovie) {
        cacheMovie(movie)
        if watchlist.contains(movie.tmdbId) {
            watchlist.remove(movie.tmdbId)
        } else {
            watchlist.insert(movie.tmdbId)
        }
        save()
    }

    /// Legacy ID-only versions.

    func addToWatchlist(tmdbId: Int) {
        watchlist.insert(tmdbId)
        save()
    }

    func removeFromWatchlist(tmdbId: Int) {
        watchlist.remove(tmdbId)
        save()
    }

    func isOnWatchlist(tmdbId: Int) -> Bool {
        watchlist.contains(tmdbId)
    }

    func toggleWatchlist(tmdbId: Int) {
        if watchlist.contains(tmdbId) {
            watchlist.remove(tmdbId)
        } else {
            watchlist.insert(tmdbId)
        }
        save()
    }

    // MARK: - Favorite Poster Overrides

    /// Return the active poster path for a favorited movie — user-picked
    /// alternate if one was set, otherwise the default cached poster.
    func favoritePosterPath(for tmdbId: Int) -> String? {
        if let override = favoritePosterOverrides[tmdbId] { return override }
        return cachedMovie(for: tmdbId)?.posterPath
    }

    /// Build the image URL for a favorited movie using either the user's picked
    /// alternate poster or the default cached poster.
    func favoritePosterURL(for tmdbId: Int) -> URL? {
        guard let path = favoritePosterPath(for: tmdbId) else { return nil }
        return URL(string: "\(APIConfiguration.TMDB.imageBaseURL)/\(APIConfiguration.TMDB.PosterSize.medium.rawValue)\(path)")
    }

    /// Pick a custom poster for a favorite. Pass nil to revert to the default.
    func setFavoritePosterOverride(tmdbId: Int, posterPath: String?) {
        if let posterPath {
            favoritePosterOverrides[tmdbId] = posterPath
        } else {
            favoritePosterOverrides.removeValue(forKey: tmdbId)
        }
        save()
    }

    // MARK: - Persistence

    /// Nesting depth of `batchUpdate` calls. While non-zero, `save()` is a
    /// no-op so a bulk import doesn't re-encode the whole diary and metadata
    /// cache once per row.
    private var saveSuspensionDepth = 0

    /// Apply a group of mutations with a single trailing persist + sync.
    /// Use this for anything that touches many movies at once (imports, syncs).
    func batchUpdate(_ mutations: () -> Void) {
        saveSuspensionDepth += 1
        mutations()
        saveSuspensionDepth -= 1
        save()
    }

    private func save() {
        guard saveSuspensionDepth == 0 else { return }

        UserDefaults.standard.set(Array(seenTmdbIds), forKey: seenKey)
        UserDefaults.standard.set(Array(watchlist), forKey: watchlistKey)

        let ratingsDict = ratings.reduce(into: [String: Double]()) { $0["\($1.key)"] = $1.value }
        UserDefaults.standard.set(ratingsDict, forKey: ratingsKey)

        if let diaryData = try? JSONEncoder().encode(diary) {
            UserDefaults.standard.set(diaryData, forKey: diaryKey)
        }

        if let cacheData = try? JSONEncoder().encode(Array(movieCache.values)) {
            UserDefaults.standard.set(cacheData, forKey: movieCacheKey)
        }

        let overridesDict = favoritePosterOverrides.reduce(into: [String: String]()) { $0["\($1.key)"] = $1.value }
        UserDefaults.standard.set(overridesDict, forKey: favoritePosterOverridesKey)

        scheduleFirestoreSync()

        // Re-evaluate achievements — unlocks that depend on seen/watchlist/ratings
        // will fire their celebration from here.
        AchievementService.shared.evaluateUnlocks(seen: self)
    }

    /// Push a debounced snapshot of every list to the signed-in user's Firestore doc,
    /// so friends can read it (subject to their privacy settings).
    private func scheduleFirestoreSync() {
        syncTask?.cancel()
        syncTask = Task { [weak self] in
            // Debounce rapid mutations
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await self?.pushToFirestore()
        }
    }

    /// Persist a freshly-imported favorites list straight to the user's profile doc.
    /// Caches posters too so `FavoritesRow` renders immediately.
    private func pushFavoritesToFirestore(tmdbIds: [Int]) async {
        guard let userId = AuthenticationService.shared.currentUser?.id else { return }
        save() // flush metadata cache we just populated
        do {
            try await db.collection("users").document(userId).updateData([
                "favoriteMovieIds": tmdbIds
            ])
        } catch {
            // Non-fatal — snapshot listener will pick up on next refresh.
        }
    }

    private func pushToFirestore() async {
        guard let userId = AuthenticationService.shared.currentUser?.id else { return }

        let encoder = JSONEncoder()
        let diaryJSON = (try? encoder.encode(diary)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        let cacheJSON = (try? encoder.encode(Array(movieCache.values))).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        let ratingsDict = ratings.reduce(into: [String: Double]()) { $0["\($1.key)"] = $1.value }

        let overridesDict = favoritePosterOverrides.reduce(into: [String: String]()) { $0["\($1.key)"] = $1.value }
        let payload: [String: Any] = [
            "mediaSeenIds": Array(seenTmdbIds),
            "mediaWatchlistIds": Array(watchlist),
            "mediaRatings": ratingsDict,
            "mediaDiaryJSON": diaryJSON,
            "mediaCacheJSON": cacheJSON,
            "favoritePosterOverrides": overridesDict,
            "mediaUpdatedAt": Timestamp(date: Date())
        ]

        do {
            try await db.collection("users").document(userId).updateData(payload)
        } catch {
            // Non-fatal — will retry on next mutation
        }
    }

    // MARK: - Cloud Restore

    /// Pull this user's media state back down from Firestore when the device
    /// has none of its own.
    ///
    /// Everything here is already pushed up by `pushToFirestore` so friends can
    /// read it, but nothing ever read it back — so a reinstall or a second
    /// device started empty, and a connected Letterboxd account could only
    /// recover the ~100 entries still in the RSS window.
    ///
    /// Guarded on *local emptiness* rather than merged, deliberately. A merge
    /// would need per-field conflict resolution across two devices; refusing to
    /// run when there's anything here cannot lose data, and covers the case
    /// that actually happens.
    func restoreFromCloudIfEmpty() async {
        guard seenTmdbIds.isEmpty, watchlist.isEmpty, ratings.isEmpty, diary.isEmpty else { return }
        guard let userId = AuthenticationService.shared.currentUser?.id else { return }

        guard let snapshot = try? await db.collection("users").document(userId).getDocument(),
              let data = snapshot.data() else { return }

        let cloudSeen = Set(data["mediaSeenIds"] as? [Int] ?? [])
        let cloudWatchlist = Set(data["mediaWatchlistIds"] as? [Int] ?? [])
        let cloudRatings = Self.decodeRatings(data["mediaRatings"] as? [String: Any] ?? [:])

        let cloudDiary: [DiaryEntry] = (data["mediaDiaryJSON"] as? String)
            .flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONDecoder().decode([DiaryEntry].self, from: $0) } ?? []

        let cloudCache: [CachedMovie] = (data["mediaCacheJSON"] as? String)
            .flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONDecoder().decode([CachedMovie].self, from: $0) } ?? []

        let cloudOverrides = (data["favoritePosterOverrides"] as? [String: String] ?? [:])
            .reduce(into: [Int: String]()) { result, pair in
                if let key = Int(pair.key) { result[key] = pair.value }
            }

        // Nothing worth restoring — don't churn a save for an empty payload.
        guard !cloudSeen.isEmpty || !cloudWatchlist.isEmpty || !cloudDiary.isEmpty else { return }

        batchUpdate {
            seenTmdbIds = cloudSeen
            watchlist = cloudWatchlist
            ratings = cloudRatings
            diary = cloudDiary.sorted { $0.watchedDate > $1.watchedDate }
            favoritePosterOverrides = cloudOverrides
            for entry in cloudCache { movieCache[entry.id] = entry }
        }
    }

    /// Firestore returns numbers as `Double`, `Int` or `NSNumber` depending on
    /// how they were written; keys are stringified tmdbIds.
    private static func decodeRatings(_ raw: [String: Any]) -> [Int: Double] {
        raw.reduce(into: [Int: Double]()) { result, pair in
            guard let key = Int(pair.key) else { return }
            if let value = pair.value as? Double {
                result[key] = value
            } else if let value = pair.value as? Int {
                result[key] = Double(value)
            } else if let value = pair.value as? NSNumber {
                result[key] = value.doubleValue
            }
        }
    }

    private func load() {
        seenTmdbIds = Set(UserDefaults.standard.array(forKey: seenKey) as? [Int] ?? [])
        watchlist = Set(UserDefaults.standard.array(forKey: watchlistKey) as? [Int] ?? [])

        // Load ratings — handle both the new [String: Double] layout AND the
        // legacy [String: Int] layout from older app versions. Integers are
        // coerced to whole-star doubles (e.g. 4 → 4.0).
        if let raw = UserDefaults.standard.dictionary(forKey: ratingsKey) {
            ratings = raw.reduce(into: [Int: Double]()) { result, pair in
                guard let key = Int(pair.key) else { return }
                if let dbl = pair.value as? Double {
                    result[key] = dbl
                } else if let int = pair.value as? Int {
                    result[key] = Double(int)
                } else if let num = pair.value as? NSNumber {
                    result[key] = num.doubleValue
                }
            }
        }

        if let cacheData = UserDefaults.standard.data(forKey: movieCacheKey),
           let decoded = try? JSONDecoder().decode([CachedMovie].self, from: cacheData) {
            movieCache = Dictionary(uniqueKeysWithValues: decoded.map { ($0.id, $0) })
        }

        if let diaryData = UserDefaults.standard.data(forKey: diaryKey),
           let decoded = try? JSONDecoder().decode([DiaryEntry].self, from: diaryData) {
            diary = decoded

            // Backfill cache from diary entries (for users who upgraded from older versions)
            for entry in decoded where movieCache[entry.tmdbId] == nil {
                movieCache[entry.tmdbId] = CachedMovie(
                    id: entry.tmdbId,
                    title: entry.title,
                    posterPath: entry.posterPath,
                    year: nil,
                    voteAverage: nil
                )
            }
        }

        if let raw = UserDefaults.standard.dictionary(forKey: favoritePosterOverridesKey) as? [String: String] {
            favoritePosterOverrides = raw.reduce(into: [Int: String]()) { result, pair in
                if let key = Int(pair.key) {
                    result[key] = pair.value
                }
            }
        }
    }

    // MARK: - Letterboxd Import

    /// What kind of Letterboxd CSV we're importing. Detected from filename + header columns.
    enum LetterboxdCSVKind {
        case diary       // diary.csv — watched entries with date, rating, review, rewatch
        case watched     // watched.csv — just a list of watched films with optional rating
        case watchlist   // watchlist.csv — to-watch list
        case reviews     // reviews.csv — reviews with ratings and watched dates
        case favorites   // favorites.csv — up to 4 pinned movies (Letterboxd-style)
    }

    @discardableResult
    func importLetterboxd(from url: URL) async -> LetterboxdImportResult {
        isImporting = true
        defer { isImporting = false }

        // Don't bail when this returns false — it does so for files the app can
        // already read (its own container, some Files providers), and gating on
        // it made those imports fail silently.
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer { if didStartAccess { url.stopAccessingSecurityScopedResource() } }

        let name = url.lastPathComponent

        do {
            let data = try Data(contentsOf: url)
            // Letterboxd exports UTF-8, but fall back rather than dropping the
            // whole file if a re-saved CSV arrives in a legacy encoding.
            guard let csvString = String(data: data, encoding: .utf8)
                    ?? String(data: data, encoding: .isoLatin1) else {
                lastImportCount = 0
                return LetterboxdImportResult(
                    failureReason: "Couldn't read the text in \(name). Re-export it from Letterboxd and try again."
                )
            }

            let filename = name.lowercased()
            let (kind, entries) = parseLetterboxdCSV(csvString, filename: filename)

            guard !entries.isEmpty else {
                lastImportCount = 0
                return LetterboxdImportResult(
                    failureReason: "\(name) had no film rows we recognised. Letterboxd's exports have a Name column — pick watched.csv, diary.csv, ratings.csv or watchlist.csv."
                )
            }

            var matchedCount = 0
            var unmatchedTitles: [String] = []
            // For favorites.csv, accumulate IDs in CSV order so the final write
            // matches the user's Letterboxd ordering.
            var favoriteMatches: [(index: Int, tmdbId: Int)] = []

            // Batch search against TMDB
            let batchSize = 5
            for batchStart in stride(from: 0, to: entries.count, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, entries.count)
                let batch = Array(entries[batchStart..<batchEnd]).enumerated().map {
                    (index: batchStart + $0.offset, entry: $0.element)
                }

                await withTaskGroup(of: (Int, LetterboxdEntry, TMDBMovie?).self) { group in
                    for item in batch {
                        group.addTask {
                            do {
                                // One retry: a rate limit or a dropped connection
                                // mid-import is otherwise indistinguishable from
                                // "no confident match", and quietly loses a film
                                // from the seen set for good.
                                let response: TMDBMovieListResponse
                                do {
                                    response = try await TMDBService.shared.searchMovies(query: item.entry.name, page: 1)
                                } catch {
                                    try await Task.sleep(for: .milliseconds(400))
                                    response = try await TMDBService.shared.searchMovies(query: item.entry.name, page: 1)
                                }
                                let match = Self.bestLetterboxdMatch(for: item.entry, in: response.results)
                                return (item.index, item.entry, match)
                            } catch {
                                return (item.index, item.entry, nil)
                            }
                        }
                    }

                    for await (index, entry, tmdbMovie) in group {
                        guard let tmdbMovie else {
                            unmatchedTitles.append(entry.name)
                            continue
                        }
                        matchedCount += 1
                        // Derive year from release date so we don't overwrite a good
                        // value with nil if the CSV omitted it.
                        let movieYear: Int? = {
                            if let d = tmdbMovie.releaseDate {
                                return Calendar.current.component(.year, from: d)
                            }
                            return entry.year
                        }()
                        // Always refresh the cached metadata — imports overwrite stub
                        // entries that were saved without posters by older builds.
                        movieCache[tmdbMovie.id] = CachedMovie(
                            id: tmdbMovie.id,
                            title: tmdbMovie.title,
                            posterPath: tmdbMovie.posterPath,
                            backdropPath: tmdbMovie.backdropPath,
                            year: movieYear,
                            voteAverage: tmdbMovie.voteAverage
                        )

                        if kind == .favorites {
                            favoriteMatches.append((index: index, tmdbId: tmdbMovie.id))
                        } else {
                            apply(entry: entry, tmdbMovie: tmdbMovie, kind: kind)
                        }
                    }
                }
            }

            // Favorites: push to the user's profile doc in CSV order, capped at 4.
            if kind == .favorites, !favoriteMatches.isEmpty {
                let ordered = favoriteMatches
                    .sorted { $0.index < $1.index }
                    .map { $0.tmdbId }
                let capped = Array(ordered.prefix(4))
                await pushFavoritesToFirestore(tmdbIds: capped)
            }

            // Sort diary newest first
            diary.sort { $0.watchedDate > $1.watchedDate }
            save()
            lastImportCount = matchedCount
            if matchedCount > 0 {
                AchievementService.shared.forceUnlock("letterboxd_convert")
            }

            // Kick off a background hydration pass for anything that's still
            // missing a poster (diary rows imported by older builds, cached
            // entries where TMDB search didn't return a poster path, etc.).
            Task { [weak self] in
                guard let self else { return }
                let missingIds = self.movieCache.values
                    .filter { $0.posterPath == nil }
                    .map { $0.id }
                if !missingIds.isEmpty {
                    await self.hydrateMissingMetadata(tmdbIds: missingIds, limit: 100)
                }
            }

            return LetterboxdImportResult(matched: matchedCount, unmatchedTitles: unmatchedTitles)
        } catch {
            lastImportCount = 0
            // Most often an iCloud Drive file that hasn't been downloaded to
            // the device yet, or a security-scoped URL the picker didn't grant.
            return LetterboxdImportResult(
                failureReason: "Couldn't open \(name). If it's in iCloud Drive, open it in Files once to download it, then import again."
            )
        }
    }

    /// Pick the best TMDB search result for a Letterboxd CSV row.
    /// Prefers exact title + year, then exact title, then year-plus-popularity.
    /// Returns nil if nothing in the result set is a reasonable match — better
    /// to skip than to import "Sinners" and get a random horror short.
    private nonisolated static func bestLetterboxdMatch(for entry: LetterboxdEntry, in results: [TMDBMovie]) -> TMDBMovie? {
        guard !results.isEmpty else { return nil }
        let target = entry.name.lowercased()
        let targetYear = entry.year

        // 1. Exact title + year.
        if let y = targetYear {
            if let exact = results.first(where: { movie in
                let title = movie.title.lowercased()
                let original = movie.originalTitle?.lowercased() ?? ""
                guard title == target || original == target else { return false }
                guard let date = movie.releaseDate else { return false }
                return Calendar.current.component(.year, from: date) == y
            }) {
                return exact
            }
            // 1b. Exact title + year within 1 (Letterboxd sometimes lists the
            // theatrical year while TMDB stores the festival year and vice versa).
            if let close = results.first(where: { movie in
                let title = movie.title.lowercased()
                let original = movie.originalTitle?.lowercased() ?? ""
                guard title == target || original == target else { return false }
                guard let date = movie.releaseDate else { return false }
                return abs(Calendar.current.component(.year, from: date) - y) <= 1
            }) {
                return close
            }
        }

        // 2. Exact title only (no year available).
        if targetYear == nil {
            if let exact = results.first(where: { $0.title.lowercased() == target || ($0.originalTitle?.lowercased() ?? "") == target }) {
                return exact
            }
        }

        // 3. Fallback: most popular result sharing the entry's year.
        if let y = targetYear {
            let yearMatches = results.filter { movie in
                guard let date = movie.releaseDate else { return false }
                return Calendar.current.component(.year, from: date) == y
            }
            if let best = yearMatches.max(by: { ($0.popularity ?? 0) < ($1.popularity ?? 0) }) {
                return best
            }
        }

        // Nothing confident — refuse to import. Prevents "Sinners" type mis-matches
        // from polluting the user's seen set and Movie Night deck.
        return nil
    }

    /// Apply a single matched CSV entry to the appropriate local store. The
    /// `tmdbMovie` is the TMDB search result we already matched, so we can
    /// save its poster/backdrop paths immediately — no second API round-trip.
    private func apply(entry: LetterboxdEntry, tmdbMovie: TMDBMovie, kind: LetterboxdCSVKind) {
        let tmdbId = tmdbMovie.id

        switch kind {
        case .watchlist:
            // Watchlist-only — do NOT mark as seen.
            watchlist.insert(tmdbId)

        case .favorites:
            // Favorites are handled inline by the importer (they need CSV ordering
            // and a direct profile-doc write). We only cached metadata above.
            return

        case .watched, .diary, .reviews:
            // All of these imply the film has been watched.
            seenTmdbIds.insert(tmdbId)
            // Clear any stale watchlist membership — if they've now watched it, it's no longer to-watch.
            watchlist.remove(tmdbId)

            // Ratings (Letterboxd 0.5-5.0 → our 0.5-5.0 doubles; preserve half-stars).
            if let lbRating = entry.rating {
                let clamped = max(0.5, min(5.0, (lbRating * 2).rounded() / 2))
                ratings[tmdbId] = clamped
            }

            // Diary entries:
            //   - `watched.csv` / `ratings.csv` carry a "Date" column, but it's
            //     the date the film was *added* to Letterboxd, not a watch
            //     date. Building diary rows from it invents watch history and
            //     collides with the real dates in diary.csv, so skip it — the
            //     film is already in `seenTmdbIds` with its rating.
            //   - `diary.csv` / `reviews.csv` carry a real "Watched Date".
            //   - Each Letterboxd diary row IS an event, so rewatches on
            //     different days still get their own entries.
            guard kind == .diary || kind == .reviews else { return }

            let dateStr = entry.watchedDate ?? entry.entryDate
            let parsedDate = dateStr.flatMap { parseLetterboxdDate($0) }
            let hasReview = (entry.reviewText?.isEmpty == false)
            guard parsedDate != nil || hasReview else { return }

            let date = parsedDate ?? Date()
            let starRating: Double? = entry.rating.map {
                max(0.5, min(5.0, ($0 * 2).rounded() / 2))
            }

            // Upsert rather than append-unless-identical. The old dedupe keyed
            // on reviewText too, so the *same viewing* arriving from a second
            // source — diary.csv has no Review column, reviews.csv does, and
            // the RSS sync extracts it from HTML — never matched and produced a
            // duplicate row per film. Identity is the viewing, not its text:
            //   1. a row already tagged with this Letterboxd URI,
            //   2. otherwise any entry for this film on this day,
            //   3. otherwise a new entry.
            var index = entry.uri.flatMap { uri in
                diary.firstIndex { $0.externalId == uri }
            }
            if index == nil {
                index = diary.firstIndex {
                    $0.tmdbId == tmdbId &&
                    Calendar.current.isDate($0.watchedDate, inSameDayAs: date)
                }
            }

            if let index {
                diary[index].watchedDate = date
                diary[index].isRewatch = entry.isRewatch
                if let starRating {
                    diary[index].ratingStars = starRating
                    diary[index].rating = Int(starRating.rounded())
                }
                // Only ever add text, never blank out a review we already hold
                // — diary.csv has no Review column and would otherwise wipe the
                // body that reviews.csv or the RSS sync brought in.
                if hasReview { diary[index].reviewText = entry.reviewText }
                if diary[index].posterPath == nil { diary[index].posterPath = tmdbMovie.posterPath }
                if let uri = entry.uri, diary[index].externalId == nil {
                    diary[index].externalId = uri
                }
            } else {
                diary.append(DiaryEntry(
                    tmdbId: tmdbId,
                    watchedDate: date,
                    rating: starRating.map { Int($0.rounded()) }, // keep legacy field in sync
                    ratingStars: starRating,
                    reviewText: entry.reviewText,
                    title: tmdbMovie.title,
                    posterPath: tmdbMovie.posterPath,
                    isRewatch: entry.isRewatch,
                    externalId: entry.uri
                ))
            }
        }
    }

    // MARK: - CSV Parsing

    private struct LetterboxdEntry {
        let name: String
        let year: Int?
        let rating: Double?
        let watchedDate: String?
        let reviewText: String?
        let entryDate: String?  // fallback from "Date" column on diary.csv
        let isRewatch: Bool
        /// The row's "Letterboxd URI". On diary.csv / reviews.csv this is the
        /// permalink for that specific viewing, which gives a re-import stable
        /// identity so it updates rows instead of duplicating them.
        let uri: String?
    }

    /// Parse a Letterboxd CSV. Detects whether it's a watchlist / watched / diary / reviews
    /// export from the filename and/or the header columns. Returns the kind alongside
    /// the parsed entries so the caller can route them to the correct list.
    private func parseLetterboxdCSV(_ csv: String, filename: String) -> (LetterboxdCSVKind, [LetterboxdEntry]) {
        var entries: [LetterboxdEntry] = []
        // Split into records with a real CSV tokenizer — reviews routinely
        // contain commas, quotes and hard line breaks, and splitting on
        // newlines first would shred every row after the first multi-line review.
        // Drop a UTF-8 BOM first or it fuses onto the first header name.
        let rows = Self.parseCSV(csv.hasPrefix("\u{FEFF}") ? String(csv.dropFirst()) : csv)

        guard let headerRow = rows.first else { return (.watched, []) }
        let headers = headerRow.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }

        // Detect CSV kind.
        // Filename is the strongest signal: Letterboxd names its exports consistently.
        let kind: LetterboxdCSVKind = {
            if filename.contains("favorites") || filename.contains("favourites") { return .favorites }
            if filename.contains("watchlist") { return .watchlist }
            if filename.contains("diary") { return .diary }
            if filename.contains("reviews") { return .reviews }
            if filename.contains("watched") { return .watched }
            // Fallback: infer from headers.
            if headers.contains("rewatch") || headers.contains("watched date") { return .diary }
            if headers.contains("review") && headers.contains("rating") { return .reviews }
            return .watched
        }()

        let nameIndex = headers.firstIndex(of: "name") ?? headers.firstIndex(of: "title")
        let yearIndex = headers.firstIndex(of: "year")
        let ratingIndex = headers.firstIndex(of: "rating")
        let watchedDateIndex = headers.firstIndex(of: "watched date")
        let dateIndex = headers.firstIndex(of: "date")
        let reviewIndex = headers.firstIndex(of: "review")
        let rewatchIndex = headers.firstIndex(of: "rewatch")
        let uriIndex = headers.firstIndex(of: "letterboxd uri")

        guard let nameIdx = nameIndex else { return (kind, []) }

        for fields in rows.dropFirst() {
            guard nameIdx < fields.count else { continue }

            let name = fields[nameIdx].trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }

            let year: Int? = yearIndex.flatMap { idx in
                idx < fields.count ? Int(fields[idx].trimmingCharacters(in: .whitespaces)) : nil
            }
            let rating: Double? = ratingIndex.flatMap { idx in
                idx < fields.count ? Double(fields[idx].trimmingCharacters(in: .whitespaces)) : nil
            }
            let watchedDate: String? = watchedDateIndex.flatMap { idx in
                idx < fields.count ? fields[idx].trimmingCharacters(in: .whitespaces) : nil
            }
            let entryDate: String? = dateIndex.flatMap { idx in
                idx < fields.count ? fields[idx].trimmingCharacters(in: .whitespaces) : nil
            }
            let reviewText: String? = reviewIndex.flatMap { idx -> String? in
                guard idx < fields.count else { return nil }
                let trimmed = fields[idx].trimmingCharacters(in: .whitespaces)
                return trimmed.isEmpty ? nil : trimmed
            }
            // Letterboxd writes "Yes" / "" for the Rewatch column.
            let isRewatch: Bool = rewatchIndex.flatMap { idx -> Bool? in
                guard idx < fields.count else { return nil }
                let value = fields[idx].trimmingCharacters(in: .whitespaces).lowercased()
                return value == "yes" || value == "true" || value == "1"
            } ?? false

            let uri: String? = uriIndex.flatMap { idx -> String? in
                guard idx < fields.count else { return nil }
                let trimmed = fields[idx].trimmingCharacters(in: .whitespaces)
                return trimmed.isEmpty ? nil : trimmed
            }

            entries.append(LetterboxdEntry(
                name: name, year: year, rating: rating,
                watchedDate: watchedDate, reviewText: reviewText,
                entryDate: entryDate, isRewatch: isRewatch, uri: uri
            ))
        }

        return (kind, entries)
    }

    /// RFC 4180 CSV tokenizer.
    ///
    /// Handles the four things Letterboxd exports actually contain and the old
    /// line-splitting parser got wrong:
    ///   - commas inside quoted fields,
    ///   - `""` as an escaped quote inside a quoted field,
    ///   - hard line breaks inside a quoted review body,
    ///   - CRLF record separators, which Letterboxd writes on every row.
    ///
    /// Walks Unicode *scalars* rather than `Character`s deliberately. Swift
    /// treats CRLF as a single extended grapheme cluster, so a `Character` loop
    /// compares it against neither "\r" nor "\n", falls through to the default
    /// branch, and appends it to the field instead of ending the record — the
    /// whole export collapses into one row and every import matches nothing.
    ///
    /// Returns one array of fields per record.
    nonisolated static func parseCSV(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var fields: [String] = []
        var current = ""
        var inQuotes = false

        let scalars = Array(text.unicodeScalars)
        var index = 0

        func endField() {
            fields.append(current)
            current = ""
        }

        func endRow() {
            endField()
            // Drop the empty record a trailing newline leaves behind.
            if fields.count > 1 || !(fields.first ?? "").isEmpty {
                rows.append(fields)
            }
            fields = []
        }

        while index < scalars.count {
            let scalar = scalars[index]

            if inQuotes {
                if scalar == "\"" {
                    // `""` is an escaped quote; a lone `"` closes the field.
                    if index + 1 < scalars.count, scalars[index + 1] == "\"" {
                        current.unicodeScalars.append("\"")
                        index += 2
                        continue
                    }
                    inQuotes = false
                } else if scalar == "\r" {
                    // Normalise line breaks inside a review body to plain \n so
                    // the stored text doesn't carry stray carriage returns.
                    current.unicodeScalars.append("\n")
                    if index + 1 < scalars.count, scalars[index + 1] == "\n" {
                        index += 1
                    }
                } else {
                    current.unicodeScalars.append(scalar)
                }
                index += 1
                continue
            }

            switch scalar {
            case "\"":
                inQuotes = true
            case ",":
                endField()
            case "\n":
                endRow()
            case "\r":
                endRow()
                // Swallow the \n of a \r\n pair so it doesn't open a blank row.
                if index + 1 < scalars.count, scalars[index + 1] == "\n" {
                    index += 1
                }
            default:
                current.unicodeScalars.append(scalar)
            }

            index += 1
        }

        // Flush whatever the file ended on.
        if !current.isEmpty || !fields.isEmpty {
            endRow()
        }

        return rows
    }

    private func parseLetterboxdDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }
}

// MARK: - CachedMovie → FFMovie

extension CachedMovie {
    /// Build a lightweight `FFMovie` from the cached metadata we already have.
    /// The movie detail view will fetch full details from TMDB on open if needed.
    func toFFMovie() -> FFMovie {
        FFMovie(
            tmdbId: id,
            title: title,
            overview: "",
            posterPath: posterPath,
            backdropPath: backdropPath,
            releaseDate: year.flatMap { y -> Date? in
                var comps = DateComponents()
                comps.year = y
                comps.month = 1
                comps.day = 1
                return Calendar.current.date(from: comps)
            },
            voteAverage: voteAverage ?? 0
        )
    }
}

