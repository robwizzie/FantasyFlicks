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
    let watchedDate: Date
    // Legacy integer rating for back-compat with older saved data. New code
    // should read/write `ratingStars` which supports half-stars.
    var rating: Int?
    /// Half-star rating 0.5-5.0 (0.5 increments). When present, takes precedence over `rating`.
    var ratingStars: Double?
    var reviewText: String?
    var title: String        // cached for display without API call
    var posterPath: String?
    var isRewatch: Bool

    /// The best available rating as a Double — prefers half-star if set,
    /// otherwise falls back to the legacy integer.
    var effectiveRating: Double? {
        if let rs = ratingStars { return rs }
        if let r = rating { return Double(r) }
        return nil
    }

    init(tmdbId: Int, watchedDate: Date = Date(), rating: Int? = nil,
         ratingStars: Double? = nil, reviewText: String? = nil,
         title: String, posterPath: String? = nil, isRewatch: Bool = false) {
        self.id = UUID().uuidString
        self.tmdbId = tmdbId
        self.watchedDate = watchedDate
        self.rating = rating
        self.ratingStars = ratingStars
        self.reviewText = reviewText
        self.title = title
        self.posterPath = posterPath
        self.isRewatch = isRewatch
    }

    enum CodingKeys: String, CodingKey {
        case id, tmdbId, watchedDate, rating, ratingStars, reviewText, title, posterPath, isRewatch
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

    private func save() {
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

    func importLetterboxd(from url: URL) async -> Int {
        isImporting = true
        defer { isImporting = false }

        guard url.startAccessingSecurityScopedResource() else { return 0 }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let data = try Data(contentsOf: url)
            guard let csvString = String(data: data, encoding: .utf8) else { return 0 }

            let filename = url.lastPathComponent.lowercased()
            let (kind, entries) = parseLetterboxdCSV(csvString, filename: filename)
            var matchedCount = 0
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
                                let response = try await TMDBService.shared.searchMovies(query: item.entry.name, page: 1)
                                let match = Self.bestLetterboxdMatch(for: item.entry, in: response.results)
                                return (item.index, item.entry, match)
                            } catch {
                                return (item.index, item.entry, nil)
                            }
                        }
                    }

                    for await (index, entry, tmdbMovie) in group {
                        guard let tmdbMovie else { continue }
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

            return matchedCount
        } catch {
            return 0
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
            //   - `watched.csv` usually has no dates → skip diary creation (film already in seenTmdbIds).
            //   - `diary.csv` / `reviews.csv` may have watched date and/or review → create an entry.
            //   - Each Letterboxd diary row IS an event, so rewatches create separate entries.
            let dateStr = entry.watchedDate ?? entry.entryDate
            let parsedDate = dateStr.flatMap { parseLetterboxdDate($0) }
            let hasReview = (entry.reviewText?.isEmpty == false)
            let hasDate = parsedDate != nil

            if hasDate || hasReview {
                let date = parsedDate ?? Date()
                // Dedupe by (tmdbId, day, reviewText) so re-importing the same CSV is idempotent
                // but a legitimate rewatch on a different day still creates a new entry.
                let duplicate = diary.contains { existing in
                    existing.tmdbId == tmdbId &&
                    Calendar.current.isDate(existing.watchedDate, inSameDayAs: date) &&
                    existing.reviewText == entry.reviewText
                }
                if !duplicate {
                    // Preserve Letterboxd's half-star resolution.
                    let starRating: Double? = entry.rating.map {
                        max(0.5, min(5.0, ($0 * 2).rounded() / 2))
                    }
                    let newEntry = DiaryEntry(
                        tmdbId: tmdbId,
                        watchedDate: date,
                        rating: starRating.map { Int($0.rounded()) }, // keep legacy field in sync
                        ratingStars: starRating,
                        reviewText: entry.reviewText,
                        title: tmdbMovie.title,
                        posterPath: tmdbMovie.posterPath,
                        isRewatch: entry.isRewatch
                    )
                    diary.append(newEntry)
                }
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
    }

    /// Parse a Letterboxd CSV. Detects whether it's a watchlist / watched / diary / reviews
    /// export from the filename and/or the header columns. Returns the kind alongside
    /// the parsed entries so the caller can route them to the correct list.
    private func parseLetterboxdCSV(_ csv: String, filename: String) -> (LetterboxdCSVKind, [LetterboxdEntry]) {
        var entries: [LetterboxdEntry] = []
        let lines = csv.components(separatedBy: .newlines)

        guard let headerLine = lines.first else { return (.watched, []) }
        let headers = parseCSVRow(headerLine).map { $0.lowercased().trimmingCharacters(in: .whitespaces) }

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

        guard let nameIdx = nameIndex else { return (kind, []) }

        for line in lines.dropFirst() {
            let fields = parseCSVRow(line)
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

            entries.append(LetterboxdEntry(
                name: name, year: year, rating: rating,
                watchedDate: watchedDate, reviewText: reviewText,
                entryDate: entryDate, isRewatch: isRewatch
            ))
        }

        return (kind, entries)
    }

    private func parseCSVRow(_ row: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false

        for char in row {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(current)
        return fields
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

