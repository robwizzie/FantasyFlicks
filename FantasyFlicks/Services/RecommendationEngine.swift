//
//  RecommendationEngine.swift
//  FantasyFlicks
//
//  Builds personalised movie recommendations out of what the user has actually
//  rated — imported from Letterboxd, logged in the diary, or starred in the app.
//
//  The model blends four signals per candidate:
//
//    1. Community — members whose ratings actually line up with this user's,
//       and what they rate highly that this user hasn't seen. This is the
//       strongest evidence available and leads whenever it exists. See
//       `TasteGraphService`.
//    2. Graph — TMDB's "people who liked X also liked Y", seeded from the films
//       this user rated highest and *weighted by how highly*. A 5★ pushes about
//       three times as hard as a 4★, a top-of-list hit counts for more than a
//       buried one, and `/recommendations` outweighs the much weaker `/similar`.
//    3. Content — genre and era affinity, measured against *their own* average
//       rating. Someone who rates everything 4 stars gets no signal from
//       "they gave it 4 stars"; what matters is what they rate above their bar.
//    4. Creative — directors and actors whose work they consistently rate well.
//
//  Signal weights shift with what's available: a film the community hasn't
//  reached isn't scored as though the community disliked it, and a thinly
//  supported prediction counts for proportionally less.
//
//  Every recommendation carries the reasons that produced it, so the UI can
//  explain itself instead of being a black box.
//

import Foundation
import Combine

// MARK: - Reason

/// A human-readable justification for a recommendation.
struct RecommendationReason: Identifiable, Hashable, Sendable {
    enum Kind: String, Sendable, CaseIterable {
        case community      // "9 people with your taste rate this 4.6★"
        case similarTo      // "Because you loved Whiplash"
        case genre          // "You rate Sci-Fi highly"
        case person         // "From the director of Arrival"
        case acclaim        // "Widely acclaimed"
        case era            // "From a decade you love"

        /// Label for the "why was this recommended" filter.
        var displayName: String {
            switch self {
            case .community: return "Taste matches"
            case .similarTo: return "Films you loved"
            case .genre: return "Your genres"
            case .person: return "Directors & cast"
            case .acclaim: return "Acclaimed"
            case .era: return "Your eras"
            }
        }

        var iconName: String {
            switch self {
            case .community: return "person.2.fill"
            case .similarTo: return "heart.fill"
            case .genre: return "theatermasks.fill"
            case .person: return "person.fill"
            case .acclaim: return "star.fill"
            case .era: return "calendar"
            }
        }
    }

    let kind: Kind
    let text: String

    var id: String { "\(kind.rawValue)|\(text)" }

    var iconName: String { kind.iconName }
}

// MARK: - Recommendation

struct MovieRecommendation: Identifiable, Hashable, Sendable {
    let movie: FFMovie
    /// 0-100. How well this fits the user's taste relative to the other candidates.
    let matchScore: Int
    let reasons: [RecommendationReason]
    /// What members with similar taste suggest this user would rate it, when
    /// enough of them have seen it. Nil when the community had nothing to say.
    let predictedRating: Double?
    /// Neighbours who rated it 4+.
    let supporterCount: Int

    var id: Int { movie.tmdbId }

    /// The single strongest reason, for compact UI.
    var headlineReason: RecommendationReason? { reasons.first }

    var reasonKinds: Set<RecommendationReason.Kind> { Set(reasons.map { $0.kind }) }
}

// MARK: - Sorting & Filtering

enum RecommendationSort: String, CaseIterable, Identifiable, Sendable {
    case match
    case predicted
    case tmdbRating
    case newest
    case oldest
    case title

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .match: return "Best Match"
        case .predicted: return "Predicted Rating"
        case .tmdbRating: return "TMDB Rating"
        case .newest: return "Newest First"
        case .oldest: return "Oldest First"
        case .title: return "Title (A–Z)"
        }
    }

    var iconName: String {
        switch self {
        case .match: return "wand.and.stars"
        case .predicted: return "person.2.fill"
        case .tmdbRating: return "star.fill"
        case .newest: return "arrow.down.circle"
        case .oldest: return "arrow.up.circle"
        case .title: return "textformat.abc"
        }
    }
}

/// Narrowing applied on top of a built recommendation set. Purely client-side —
/// changing any of it re-filters instantly rather than rebuilding.
struct RecommendationFilter: Equatable, Sendable {
    var genreIds: Set<Int> = []
    var minimumYear: Int?
    var maximumYear: Int?
    var minimumTMDBRating: Double = 0
    var minimumMatchScore: Int = 0
    /// Only keep recommendations backed by at least one of these reasons.
    var reasonKinds: Set<RecommendationReason.Kind> = []
    var hideWatchlisted = false

    var isActive: Bool { self != RecommendationFilter() }

    /// Number of distinct narrowings in play, for the filter button's badge.
    var activeCount: Int {
        var count = 0
        if !genreIds.isEmpty { count += 1 }
        if minimumYear != nil || maximumYear != nil { count += 1 }
        if minimumTMDBRating > 0 { count += 1 }
        if minimumMatchScore > 0 { count += 1 }
        if !reasonKinds.isEmpty { count += 1 }
        if hideWatchlisted { count += 1 }
        return count
    }
}

// MARK: - Taste Profile

/// What we learned about a user's taste from their ratings.
struct TasteProfile: Sendable {
    /// How many rated films the profile was built from.
    let ratedCount: Int
    /// The user's own average rating — their personal "meh" line.
    let meanRating: Double
    /// genreId -> average rating delta vs. their mean, smoothed.
    let genreAffinity: [Int: Double]
    /// decade (e.g. 1990) -> average rating delta vs. their mean, smoothed.
    let decadeAffinity: [Int: Double]
    /// Films they rated highest, best first. These seed the collaborative pass.
    let lovedMovieIds: [Int]
    /// The same films paired with how hard each should push, heaviest first.
    /// A 5★ carries roughly two and a half times the weight of a 4★.
    let weightedSeeds: [(id: Int, weight: Double)]
    /// Directors/actors whose films they rate above their own average.
    let favouredPeopleIds: [Int]
    /// Display names for the people above, for reason strings.
    let peopleNames: [Int: String]
    /// Genre display names, for reason strings.
    let genreNames: [Int: String]

    /// Genres they reliably rate *below* their own average — filtered out of discovery.
    var dislikedGenreIds: [Int] {
        genreAffinity.filter { $0.value < -0.6 }.map { $0.key }
    }

    /// Genres they rate best, strongest first.
    var topGenreIds: [Int] {
        genreAffinity
            .filter { $0.value > 0 }
            .sorted { $0.value > $1.value }
            .map { $0.key }
    }

    /// Below this we don't have enough signal to say anything useful.
    static let minimumRatingsForRecommendations = 5

    var isUsable: Bool { ratedCount >= Self.minimumRatingsForRecommendations }

    static let empty = TasteProfile(
        ratedCount: 0, meanRating: 0, genreAffinity: [:], decadeAffinity: [:],
        lovedMovieIds: [], weightedSeeds: [], favouredPeopleIds: [],
        peopleNames: [:], genreNames: [:]
    )
}

// MARK: - Cached Movie Facts

/// The taste-relevant facts about a film. Cached permanently so we only pay the
/// TMDB round-trip for a given movie once, ever.
private struct MovieTasteFacts: Codable, Sendable {
    let tmdbId: Int
    let genreIds: [Int]
    /// Director ids first, then top-billed cast.
    let directorIds: [Int]
    let castIds: [Int]
    let year: Int?
    let names: [String: String]   // "\(personId)" -> display name

    var peopleIds: [Int] { directorIds + castIds }
}

// MARK: - Engine

@MainActor
final class RecommendationEngine: ObservableObject {

    // MARK: - Singleton

    static let shared = RecommendationEngine()

    // MARK: - Published

    @Published private(set) var recommendations: [MovieRecommendation] = []
    @Published private(set) var profile: TasteProfile = .empty
    @Published private(set) var isLoading = false
    @Published private(set) var lastBuiltAt: Date?
    @Published var error: String?

    /// Movies the user explicitly said "not interested" to. Never resurfaced.
    @Published private(set) var dismissedIds: Set<Int> = []

    /// How many members with comparable taste the last build found.
    @Published private(set) var neighbourCount = 0

    // MARK: - Presentation

    @Published var sort: RecommendationSort = .match
    @Published var filter = RecommendationFilter()

    /// What the list should actually show. Filtering and sorting are applied
    /// here rather than baked into `recommendations`, so changing either is
    /// instant and never costs a rebuild.
    /// Recommendations minus anything the user has since watched or dismissed.
    ///
    /// The build already excludes both, but that snapshot goes stale the moment
    /// a Letterboxd sync lands or a film gets marked seen — and a rebuild is up
    /// to six hours away. Re-checking at read time means a film you just logged
    /// disappears from the shelf immediately, which is the whole complaint that
    /// started this: already-watched films sitting in For You.
    var availableRecommendations: [MovieRecommendation] {
        let seen = seenService.seenTmdbIds
        let dismissed = dismissedIds
        return recommendations.filter {
            !seen.contains($0.movie.tmdbId) && !dismissed.contains($0.movie.tmdbId)
        }
    }

    var visibleRecommendations: [MovieRecommendation] {
        let watchlist = seenService.watchlist
        let active = filter
        let lowestYear = active.minimumYear
        let highestYear = active.maximumYear

        let filtered = availableRecommendations.filter { recommendation in
            let movie = recommendation.movie

            if !active.genreIds.isEmpty {
                // Discover/search results only carry `genreIds`; `genres` is
                // populated for enriched movies. Check both.
                let ids = Set(movie.genreIds).union(movie.genres.map { $0.id })
                guard !ids.isDisjoint(with: active.genreIds) else { return false }
            }
            if let lowestYear, let year = movie.year, year < lowestYear { return false }
            if let highestYear, let year = movie.year, year > highestYear { return false }
            if active.minimumTMDBRating > 0, movie.voteAverage < active.minimumTMDBRating { return false }
            if recommendation.matchScore < active.minimumMatchScore { return false }
            if !active.reasonKinds.isEmpty,
               recommendation.reasonKinds.isDisjoint(with: active.reasonKinds) { return false }
            if active.hideWatchlisted, watchlist.contains(movie.tmdbId) { return false }
            return true
        }

        return filtered.sorted(by: Self.comparator(for: sort))
    }

    /// Every genre present in the current results, so the filter sheet only
    /// offers genres that can actually match something.
    var availableGenres: [(id: Int, name: String)] {
        var ids = Set<Int>()
        for recommendation in availableRecommendations {
            ids.formUnion(recommendation.movie.genreIds)
            ids.formUnion(recommendation.movie.genres.map { $0.id })
        }
        return ids
            .compactMap { id in profile.genreNames[id].map { (id: id, name: $0) } }
            .sorted { $0.name < $1.name }
    }

    /// Release-year span of the current results, for the year-range control.
    var availableYearRange: ClosedRange<Int>? {
        let years = availableRecommendations.compactMap { $0.movie.year }
        guard let low = years.min(), let high = years.max(), low < high else { return nil }
        return low...high
    }

    private static func comparator(for sort: RecommendationSort) -> (MovieRecommendation, MovieRecommendation) -> Bool {
        switch sort {
        case .match:
            return { $0.matchScore > $1.matchScore }
        case .predicted:
            // Unpredicted films sort last rather than as zero, so turning this
            // on doesn't bury everything the community hasn't reached yet.
            return {
                ($0.predictedRating ?? -1, $0.matchScore) > ($1.predictedRating ?? -1, $1.matchScore)
            }
        case .tmdbRating:
            return { ($0.movie.voteAverage, $0.matchScore) > ($1.movie.voteAverage, $1.matchScore) }
        case .newest:
            return { ($0.movie.year ?? 0, $0.matchScore) > ($1.movie.year ?? 0, $1.matchScore) }
        case .oldest:
            return { ($0.movie.year ?? 9999, -$0.matchScore) < ($1.movie.year ?? 9999, -$1.matchScore) }
        case .title:
            return { $0.movie.title.localizedCaseInsensitiveCompare($1.movie.title) == .orderedAscending }
        }
    }

    func resetFilter() { filter = RecommendationFilter() }

    // MARK: - Tuning

    /// How many of the user's top-rated films seed the TMDB co-occurrence pass.
    /// Higher than it used to be: seeds are now rating-weighted, so a long tail
    /// of 4★ films adds breadth without diluting what the 5★ films are saying.
    private let seedCount = 24
    /// How many rated films we'll pull full credits for when building the profile.
    private let profileSampleSize = 45
    /// Candidates kept after scoring.
    private let resultLimit = 80
    /// A candidate needs at least this many TMDB votes to be trusted.
    private let minimumVoteCount = 200
    /// Rebuild automatically if the cached set is older than this.
    private let staleAfter: TimeInterval = 6 * 60 * 60
    /// Rebuild once the usable shelf has been worn down to this many films.
    private let restockThreshold = 15
    /// Community picks pulled from the neighbourhood per build.
    private let neighbourPickLimit = 120

    /// How hard a rated film pushes on what gets built from it.
    ///
    /// Deliberately steep. The old engine counted every "loved" film equally,
    /// so three 4★ films outvoted a single 5★ — which is backwards, because a
    /// 5★ is the clearest statement of taste a user ever makes. A 4★ now
    /// carries well under half the weight of a 5★.
    private nonisolated static func seedWeight(for rating: Double, personalMean: Double) -> Double {
        let base: Double
        switch rating {
        case 5.0: base = 1.0
        case 4.5: base = 0.66
        case 4.0: base = 0.40
        default: return 0
        }
        // A 4★ from someone who averages 2.5★ means more than a 4★ from
        // someone who hands them out freely.
        let lift = max(0, rating - personalMean) / 2.5
        return base * (1 + min(0.5, lift))
    }

    /// TMDB returns these lists ranked by relevance. Position 1 is a far
    /// stronger statement than position 18, and flat counting threw that away.
    private nonisolated static func positionWeight(_ index: Int) -> Double {
        1.0 / (1.0 + Double(index) * 0.08)
    }

    /// `/recommendations` is TMDB's curated "people who liked this also liked"
    /// graph. `/similar` is keyword and genre overlap — useful for breadth,
    /// but nowhere near the same evidence, and merging them as equals was
    /// letting weak matches outrank strong ones.
    private nonisolated static let recommendationSourceWeight = 1.0
    private nonisolated static let similarSourceWeight = 0.4

    private enum Keys {
        static let factsCache = "ff_reco_movie_facts"
        static let dismissed = "ff_reco_dismissed"
    }

    // MARK: - State

    private var factsCache: [Int: MovieTasteFacts] = [:]
    private var buildTask: Task<Void, Never>?
    /// Size of the ratings set the current recommendations were built from.
    private var ratingsCountAtLastBuild = 0
    /// Size of the seen set the current recommendations were built from.
    private var seenCountAtLastBuild = 0

    private let seenService = SeenMoviesService.shared
    private let tmdb = TMDBService.shared

    // MARK: - Init

    private init() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Keys.factsCache),
           let decoded = try? JSONDecoder().decode([MovieTasteFacts].self, from: data) {
            factsCache = Dictionary(uniqueKeysWithValues: decoded.map { ($0.tmdbId, $0) })
        }
        dismissedIds = Set(defaults.array(forKey: Keys.dismissed) as? [Int] ?? [])
    }

    // MARK: - Public API

    /// True when the user has rated enough films for recommendations to mean anything.
    var hasEnoughData: Bool {
        seenService.ratings.count >= TasteProfile.minimumRatingsForRecommendations
    }

    /// How many more ratings are needed before recommendations turn on.
    var ratingsNeeded: Int {
        max(0, TasteProfile.minimumRatingsForRecommendations - seenService.ratings.count)
    }

    /// Build recommendations if we don't have fresh ones. Cheap to call from `.task`.
    func refreshIfNeeded() async {
        let isFresh = lastBuiltAt.map { Date().timeIntervalSince($0) < staleAfter } ?? false
        // A Letterboxd sync or a batch of new ratings changes the answer, so
        // age alone isn't enough — rebuild once the input has moved materially.
        let ratingsMoved = abs(seenService.ratings.count - ratingsCountAtLastBuild) >= 3
        let seenMoved = abs(seenService.seenTmdbIds.count - seenCountAtLastBuild) >= 5
        // Films are filtered out at read time as they're watched or dismissed,
        // so a shelf that's been picked over needs restocking even if the build
        // itself is still young.
        let runningLow = availableRecommendations.count < restockThreshold

        if isFresh, !ratingsMoved, !seenMoved, !runningLow, !recommendations.isEmpty { return }
        await rebuild()
    }

    /// Force a full rebuild.
    func rebuild() async {
        // Coalesce — a pull-to-refresh landing on top of an in-flight build
        // should join it rather than start a second one.
        if let buildTask {
            await buildTask.value
            return
        }

        let task = Task<Void, Never> { [weak self] in
            guard let self else { return }
            await self.performBuild()
        }
        buildTask = task
        await task.value
        buildTask = nil
    }

    /// Hide a recommendation permanently.
    func dismiss(tmdbId: Int) {
        dismissedIds.insert(tmdbId)
        UserDefaults.standard.set(Array(dismissedIds), forKey: Keys.dismissed)
        recommendations.removeAll { $0.movie.tmdbId == tmdbId }
    }

    /// Restore everything the user previously dismissed.
    func clearDismissed() {
        dismissedIds = []
        UserDefaults.standard.removeObject(forKey: Keys.dismissed)
    }

    // MARK: - Build Pipeline

    private func performBuild() async {
        guard hasEnoughData else {
            profile = .empty
            recommendations = []
            return
        }

        isLoading = true
        error = nil
        defer { isLoading = false }

        let taste = await buildTasteProfile()
        profile = taste

        guard taste.isUsable else {
            recommendations = []
            return
        }

        // Find members whose ratings line up with this user's, then ask what
        // they rate highly that this user hasn't seen. Runs first so its picks
        // can seed the candidate pool alongside the TMDB graph.
        let excluded = seenService.seenTmdbIds.union(dismissedIds)
        let neighbours = await TasteGraphService.shared.neighbours(
            of: seenService.ratings,
            ourMean: taste.meanRating,
            lovedIds: Set(taste.lovedMovieIds)
        )
        neighbourCount = neighbours.count

        // With a healthy neighbourhood, insist on corroboration; with only a
        // handful of matches, one enthusiastic close match is all there is.
        let minimumSupporters = neighbours.count >= 12 ? 2 : 1
        let picks = TasteGraphService.picks(
            from: neighbours,
            ourMean: taste.meanRating,
            excluding: excluded,
            minimumSupporters: minimumSupporters,
            limit: neighbourPickLimit
        )
        let picksById = Dictionary(uniqueKeysWithValues: picks.map { ($0.tmdbId, $0) })

        var candidates = await gatherCandidates(for: taste, neighbourPicks: picksById)
        guard !candidates.isEmpty else {
            recommendations = []
            error = "Couldn't reach TMDB to build your recommendations. Pull to try again."
            return
        }

        // Rank, trim, then enrich only the winners with credits so the
        // "from the director of…" reasons are accurate without 200 extra calls.
        candidates.sort { $0.rawScore > $1.rawScore }
        let winners = Array(candidates.prefix(resultLimit))
        await ensureFacts(for: winners.map { $0.movie.id })
        let enriched = enrichReasons(for: winners, taste: taste)

        recommendations = normalise(enriched)
        lastBuiltAt = Date()
        ratingsCountAtLastBuild = seenService.ratings.count
        seenCountAtLastBuild = seenService.seenTmdbIds.count
    }

    // MARK: - Taste Profile

    private func buildTasteProfile() async -> TasteProfile {
        let ratings = seenService.ratings
        guard !ratings.isEmpty else { return .empty }

        let meanRating = ratings.values.reduce(0, +) / Double(ratings.count)

        // Sample the films that carry the most signal: the ones they rated
        // furthest from their own average, in either direction. A 1-star is as
        // informative as a 5-star.
        let sample = ratings
            .sorted { abs($0.value - meanRating) > abs($1.value - meanRating) }
            .prefix(profileSampleSize)
            .map { (tmdbId: $0.key, rating: $0.value) }

        await ensureFacts(for: sample.map { $0.tmdbId })

        // Smoothed mean of "how far above your own average" per bucket. The
        // smoothing constant keeps a single 5-star outlier from crowning a genre.
        var genreTotals: [Int: (sum: Double, count: Int)] = [:]
        var decadeTotals: [Int: (sum: Double, count: Int)] = [:]
        var personTotals: [Int: (sum: Double, count: Int)] = [:]
        var peopleNames: [Int: String] = [:]

        for item in sample {
            guard let facts = factsCache[item.tmdbId] else { continue }
            let delta = item.rating - meanRating

            for genreId in facts.genreIds {
                var bucket = genreTotals[genreId] ?? (0, 0)
                bucket.sum += delta
                bucket.count += 1
                genreTotals[genreId] = bucket
            }

            if let year = facts.year {
                let decade = (year / 10) * 10
                var bucket = decadeTotals[decade] ?? (0, 0)
                bucket.sum += delta
                bucket.count += 1
                decadeTotals[decade] = bucket
            }

            // Directors count double — a director's fingerprint is a much
            // stronger predictor than a supporting cast credit.
            for personId in facts.directorIds {
                var bucket = personTotals[personId] ?? (0, 0)
                bucket.sum += delta * 2
                bucket.count += 2
                personTotals[personId] = bucket
            }
            for personId in facts.castIds {
                var bucket = personTotals[personId] ?? (0, 0)
                bucket.sum += delta
                bucket.count += 1
                personTotals[personId] = bucket
            }

            for (key, name) in facts.names {
                if let id = Int(key) { peopleNames[id] = name }
            }
        }

        let genreAffinity = genreTotals.mapValues { $0.sum / Double($0.count + 3) }
        let decadeAffinity = decadeTotals.mapValues { $0.sum / Double($0.count + 3) }

        // A person only counts once they've shown up more than once, or once
        // with a properly strong rating — otherwise every bit-part actor in a
        // 5-star film becomes a "favourite".
        let favouredPeople = personTotals
            .filter { $0.value.count >= 2 && $0.value.sum > 0 }
            .sorted { ($0.value.sum / Double($0.value.count)) > ($1.value.sum / Double($1.value.count)) }
            .prefix(15)
            .map { $0.key }

        // Seeds are the 4★-and-up films, weighted steeply toward 5★. The old
        // engine also required beating the personal mean by half a star, which
        // silently dropped every seed for a user who rates generously — the
        // people most likely to have a big rated library.
        let weightedSeeds = ratings
            .compactMap { tmdbId, rating -> (id: Int, weight: Double)? in
                let weight = Self.seedWeight(for: rating, personalMean: meanRating)
                guard weight > 0 else { return nil }
                return (id: tmdbId, weight: weight)
            }
            .sorted { $0.weight > $1.weight }

        return TasteProfile(
            ratedCount: ratings.count,
            meanRating: meanRating,
            genreAffinity: genreAffinity,
            decadeAffinity: decadeAffinity,
            lovedMovieIds: weightedSeeds.map { $0.id },
            weightedSeeds: weightedSeeds,
            favouredPeopleIds: Array(favouredPeople),
            peopleNames: peopleNames,
            genreNames: await genreNameLookup()
        )
    }

    /// Fetch and cache the taste-relevant facts for any movie we haven't seen before.
    private func ensureFacts(for tmdbIds: [Int]) async {
        let missing = tmdbIds.filter { factsCache[$0] == nil }
        guard !missing.isEmpty else { return }

        let batchSize = 5
        for start in stride(from: 0, to: missing.count, by: batchSize) {
            let end = min(start + batchSize, missing.count)
            let batch = Array(missing[start..<end])

            await withTaskGroup(of: MovieTasteFacts?.self) { group in
                for id in batch {
                    group.addTask { [weak self] in
                        guard let self else { return nil }
                        guard let movie = try? await self.tmdb.getFullMovie(id: id) else { return nil }
                        return Self.facts(from: movie)
                    }
                }
                for await facts in group {
                    if let facts { factsCache[facts.tmdbId] = facts }
                }
            }
        }

        persistFactsCache()
    }

    private nonisolated static func facts(from movie: FFMovie) -> MovieTasteFacts {
        let directors = movie.crew.filter { $0.job == "Director" }
        let topCast = Array(movie.cast.prefix(5))

        var names: [String: String] = [:]
        for person in directors { names["\(person.id)"] = person.name }
        for person in topCast { names["\(person.id)"] = person.name }

        return MovieTasteFacts(
            tmdbId: movie.tmdbId,
            genreIds: movie.genres.isEmpty ? movie.genreIds : movie.genres.map { $0.id },
            directorIds: directors.map { $0.id },
            castIds: topCast.map { $0.id },
            year: movie.year,
            names: names
        )
    }

    private func persistFactsCache() {
        guard let data = try? JSONEncoder().encode(Array(factsCache.values)) else { return }
        UserDefaults.standard.set(data, forKey: Keys.factsCache)
    }

    private var cachedGenreNames: [Int: String] = [:]

    private func genreNameLookup() async -> [Int: String] {
        if !cachedGenreNames.isEmpty { return cachedGenreNames }
        guard let genres = try? await tmdb.getGenres() else { return [:] }
        cachedGenreNames = Dictionary(uniqueKeysWithValues: genres.map { ($0.id, $0.name) })
        return cachedGenreNames
    }

    // MARK: - Candidate Generation

    /// A candidate accumulating evidence from multiple sources before scoring.
    private struct Candidate {
        let movie: TMDBMovie
        /// Accumulated weight from TMDB's "fans of X also liked Y" graph —
        /// seed rating × rank position × source quality, summed.
        var graphScore: Double = 0
        /// Seeds that produced this, heaviest contribution first.
        var graphSeeds: [(seedId: Int, weight: Double)] = []
        /// What members with similar taste say about it.
        var neighbourPick: NeighbourPick?
        /// Person ids that surfaced this via a taste-driven discover query.
        var viaPeople: [Int] = []
        var rawScore: Double = 0

        /// Strongest seed behind this candidate, for the "because you loved…" line.
        var topSeed: Int? {
            graphSeeds.max(by: { $0.weight < $1.weight })?.seedId
        }
    }

    private func gatherCandidates(
        for taste: TasteProfile,
        neighbourPicks: [Int: NeighbourPick]
    ) async -> [Candidate] {
        let excluded = seenService.seenTmdbIds
            .union(dismissedIds)
            .union(Set(taste.lovedMovieIds))

        var pool: [Int: Candidate] = [:]

        // 1. Collaborative: what fans of their favourite films also loved,
        //    weighted by how much *they* loved each seed.
        let seeds = taste.weightedSeeds.prefix(seedCount)
        for batch in Array(seeds).chunked(into: 4) {
            await withTaskGroup(of: (seed: (id: Int, weight: Double), recommended: [TMDBMovie], similar: [TMDBMovie]).self) { group in
                for seed in batch {
                    group.addTask { [weak self] in
                        guard let self else { return (seed, [], []) }
                        async let recommended = self.tmdb.getRecommendations(movieId: seed.id, page: 1)
                        async let similar = self.tmdb.getSimilarMovies(movieId: seed.id, page: 1)
                        return (
                            seed,
                            (try? await recommended)?.results ?? [],
                            (try? await similar)?.results ?? []
                        )
                    }
                }

                for await result in group {
                    let sources: [(movies: [TMDBMovie], weight: Double)] = [
                        (result.recommended, Self.recommendationSourceWeight),
                        (result.similar, Self.similarSourceWeight)
                    ]

                    for source in sources {
                        for (index, movie) in source.movies.enumerated() where !excluded.contains(movie.id) {
                            let contribution = result.seed.weight
                                * Self.positionWeight(index)
                                * source.weight

                            var candidate = pool[movie.id] ?? Candidate(movie: movie)
                            candidate.graphScore += contribution
                            candidate.graphSeeds.append((seedId: result.seed.id, weight: contribution))
                            pool[movie.id] = candidate
                        }
                    }
                }
            }
        }

        // 2. Community: films the taste-matched members rate highly. These are
        //    seeded straight into the pool — a film nobody's TMDB graph
        //    surfaced can still be the single best pick in the set if the
        //    people who share this user's taste are unanimous about it.
        if !neighbourPicks.isEmpty {
            let missing = neighbourPicks.keys.filter { pool[$0] == nil && !excluded.contains($0) }
            let topMissing = missing
                .compactMap { neighbourPicks[$0] }
                .sorted { $0.strength > $1.strength }
                .prefix(40)
                .map { $0.tmdbId }

            for batch in topMissing.chunked(into: 5) {
                await withTaskGroup(of: TMDBMovie?.self) { group in
                    for tmdbId in batch {
                        group.addTask { [weak self] in
                            guard let self,
                                  let details = try? await self.tmdb.getMovieDetails(id: tmdbId) else { return nil }
                            return Self.listEntry(from: details)
                        }
                    }
                    for await movie in group {
                        guard let movie, pool[movie.id] == nil else { continue }
                        pool[movie.id] = Candidate(movie: movie)
                    }
                }
            }

            for (tmdbId, pick) in neighbourPicks {
                pool[tmdbId]?.neighbourPick = pick
            }
        }

        // 2. Creative: more from the directors and actors they rate well.
        let people = Array(taste.favouredPeopleIds.prefix(8))
        let dislikedGenres = taste.dislikedGenreIds
        let voteFloor = minimumVoteCount
        for batch in people.chunked(into: 4) {
            await withTaskGroup(of: (Int, [TMDBMovie]).self) { group in
                for personId in batch {
                    group.addTask { [weak self] in
                        guard let self else { return (personId, []) }
                        let response = try? await self.tmdb.discoverByTaste(
                            genreIds: [],
                            peopleIds: [personId],
                            excludedGenreIds: dislikedGenres,
                            minVote: 6.0,
                            minVoteCount: voteFloor,
                            minimumYear: nil,
                            page: 1
                        )
                        return (personId, response?.results ?? [])
                    }
                }
                for await (personId, movies) in group {
                    for movie in movies where !excluded.contains(movie.id) {
                        var candidate = pool[movie.id] ?? Candidate(movie: movie)
                        candidate.viaPeople.append(personId)
                        pool[movie.id] = candidate
                    }
                }
            }
        }

        // 3. Content: high-quality films in the genres they favour, so a user
        //    with few ratings still gets a full shelf.
        let topGenres = Array(taste.topGenreIds.prefix(3))
        if !topGenres.isEmpty {
            for page in 1...2 {
                guard let response = try? await tmdb.discoverByTaste(
                    genreIds: topGenres,
                    peopleIds: [],
                    excludedGenreIds: taste.dislikedGenreIds,
                    minVote: 7.0,
                    minVoteCount: max(minimumVoteCount, 500),
                    minimumYear: nil,
                    page: page
                ) else { break }

                for movie in response.results where !excluded.contains(movie.id) {
                    if pool[movie.id] == nil {
                        pool[movie.id] = Candidate(movie: movie)
                    }
                }
            }
        }

        // Score everything now that all evidence is in. A candidate carried
        // purely by the community doesn't need TMDB's vote threshold — real
        // people with matching taste vouching for it is better evidence than
        // vote count ever was.
        let candidates = pool.values.filter {
            ($0.movie.voteCount ?? 0) >= minimumVoteCount || $0.neighbourPick != nil
        }

        // The graph score is an unbounded sum, so it only means anything
        // relative to the rest of this build.
        let strongestGraph = candidates.map { $0.graphScore }.max() ?? 0

        return candidates.map { candidate in
            var scored = candidate
            scored.rawScore = score(candidate, taste: taste, strongestGraph: strongestGraph)
            return scored
        }
    }

    /// Build a list-shaped `TMDBMovie` from a details payload, so community
    /// picks can enter the pool on the same footing as discover results.
    private nonisolated static func listEntry(from details: TMDBMovieDetails) -> TMDBMovie {
        TMDBMovie(
            id: details.id,
            title: details.title,
            originalTitle: details.originalTitle,
            overview: details.overview,
            posterPath: details.posterPath,
            backdropPath: details.backdropPath,
            releaseDate: details.releaseDate,
            genreIds: details.genres.map { $0.id },
            originalLanguage: details.originalLanguage,
            popularity: details.popularity,
            voteAverage: details.voteAverage,
            voteCount: details.voteCount,
            adult: false,
            video: false
        )
    }

    // MARK: - Scoring

    /// Blend every signal into a single 0-1 score.
    ///
    /// Weights shift with what's actually available: when the community has
    /// nothing to say about a film — no neighbours, or none of them have seen
    /// it — that weight moves to the TMDB graph rather than scoring the film as
    /// though the community actively disliked it.
    private func score(_ candidate: Candidate, taste: TasteProfile, strongestGraph: Double) -> Double {
        let movie = candidate.movie

        // Content — average genre affinity, mapped from roughly [-1, 1] to [0, 1].
        let genreIds = movie.genreIds ?? []
        let genreSignal: Double
        if genreIds.isEmpty {
            genreSignal = 0.5
        } else {
            let affinities = genreIds.map { taste.genreAffinity[$0] ?? 0 }
            let average = affinities.reduce(0, +) / Double(affinities.count)
            genreSignal = 0.5 + max(-1.0, min(1.0, average)) / 2.0
        }

        // Creative — neutral-low baseline so "no known people" doesn't punish a
        // film, but a match is a meaningful lift.
        let peopleSignal = candidate.viaPeople.isEmpty ? 0.35 : 1.0

        // Quality prior, gently weighted so a beloved-but-obscure film can still win.
        let quality = max(0.0, min(1.0, ((movie.voteAverage ?? 0) - 5.5) / 3.0))

        // Era — a mild nudge toward decades they rate well.
        var eraSignal = 0.5
        if let date = movie.releaseDate {
            let decade = (Calendar.current.component(.year, from: date) / 10) * 10
            if let affinity = taste.decadeAffinity[decade] {
                eraSignal = 0.5 + max(-1.0, min(1.0, affinity)) / 2.0
            }
        }

        // Graph — how much weighted evidence the user's own favourites pointed
        // at this, relative to the strongest candidate in the set. Square-rooted
        // so the long tail of one-weak-hit candidates isn't flattened to zero.
        let graphSignal = strongestGraph > 0
            ? (candidate.graphScore / strongestGraph).squareRoot()
            : 0

        var weights: [(signal: Double, weight: Double)] = [
            (graphSignal, 1.8),
            (genreSignal, 1.0),
            (peopleSignal, 0.9),
            (quality, 0.7),
            (eraSignal, 0.3)
        ]

        // Community — the headline signal when it exists. A predicted rating is
        // mapped against the user's own scale: predicting they'd give it their
        // average is neutral, predicting a 5 is the top of the range.
        if let pick = candidate.neighbourPick {
            let ceiling = max(0.5, 5.0 - taste.meanRating)
            let lift = (pick.predictedRating - taste.meanRating) / ceiling
            let communitySignal = max(0.0, min(1.0, 0.5 + lift / 2.0))
            // Confidence scales the *weight*, not the signal — a thinly
            // supported prediction should count for less, not read as negative.
            weights.append((communitySignal, 2.2 * pick.confidence))
        }

        let total = weights.reduce(0.0) { $0 + $1.weight }
        guard total > 0 else { return 0 }
        return weights.reduce(0.0) { $0 + $1.signal * $1.weight } / total
    }

    /// Map raw scores onto a 0-100 display range and attach reasons.
    private func normalise(_ scored: [(candidate: Candidate, reasons: [RecommendationReason])]) -> [MovieRecommendation] {
        guard let best = scored.map({ $0.candidate.rawScore }).max(), best > 0 else { return [] }

        return scored.map { item in
            // Relative to the strongest match, floored so the tail of the list
            // doesn't read as "3% match" for a perfectly good film.
            let relative = item.candidate.rawScore / best
            let percent = Int((0.55 + 0.45 * relative) * 100)

            return MovieRecommendation(
                movie: TMDBService.shared.convertToFFMovie(item.candidate.movie),
                matchScore: max(0, min(100, percent)),
                reasons: item.reasons,
                predictedRating: item.candidate.neighbourPick?.predictedRating,
                supporterCount: item.candidate.neighbourPick?.supporterCount ?? 0
            )
        }
    }

    // MARK: - Reasons

    /// Turn the evidence behind each winner into readable reasons, strongest first.
    private func enrichReasons(
        for candidates: [Candidate],
        taste: TasteProfile
    ) -> [(candidate: Candidate, reasons: [RecommendationReason])] {
        // Titles for the seed films we'll name in "because you loved…" reasons.
        var seedTitles: [Int: String] = [:]
        for seedId in taste.lovedMovieIds.prefix(seedCount) {
            if let cached = seenService.cachedMovie(for: seedId) {
                seedTitles[seedId] = cached.title
            }
        }

        return candidates.map { candidate in
            var reasons: [RecommendationReason] = []

            // 1. The community, when it has something to say — this is the
            //    strongest evidence available, so it leads.
            if let pick = candidate.neighbourPick {
                let text: String
                if pick.supporterCount >= 3 {
                    text = String(
                        format: "%d taste matches rate this %.1f★",
                        pick.supporterCount, pick.averageRating
                    )
                } else if let name = pick.supporters.first, pick.supporterCount == 1 {
                    text = String(format: "%@ rates this %.1f★", name, pick.averageRating)
                } else {
                    text = String(
                        format: "%d people with your taste rate this %.1f★",
                        pick.supporterCount, pick.averageRating
                    )
                }
                reasons.append(RecommendationReason(kind: .community, text: text))
            }

            // 2. A specific film they loved that points here. Names the seed
            //    that contributed most, not whichever happened to arrive first.
            if let seedId = candidate.topSeed, let title = seedTitles[seedId] {
                let others = Set(candidate.graphSeeds.map { $0.seedId }).count - 1
                let text = others > 0
                    ? "Because you loved \(title) +\(others) more"
                    : "Because you loved \(title)"
                reasons.append(RecommendationReason(kind: .similarTo, text: text))
            }

            // 3. A director or actor they consistently rate well — but only
            //    when that person actually directed or starred in *this* film.
            //    TMDB's `with_people` matches any crew credit, so this used to
            //    claim "More from Peter Ramsey" about a film he storyboarded.
            if let personId = candidate.viaPeople.first(where: { personId in
                guard let facts = self.factsCache[candidate.movie.id] else { return false }
                return facts.directorIds.contains(personId) || facts.castIds.contains(personId)
            }), let name = taste.peopleNames[personId] {
                let isDirector = factsCache[candidate.movie.id]?.directorIds.contains(personId) == true
                reasons.append(RecommendationReason(
                    kind: .person,
                    text: isDirector ? "Directed by \(name)" : "Starring \(name)"
                ))
            }

            // 4. Their best genre that this film actually belongs to.
            let genreIds = candidate.movie.genreIds ?? []
            if let bestGenre = genreIds
                .compactMap({ id -> (Int, Double)? in
                    guard let affinity = taste.genreAffinity[id], affinity > 0.15 else { return nil }
                    return (id, affinity)
                })
                .max(by: { $0.1 < $1.1 }),
               let name = taste.genreNames[bestGenre.0] {
                reasons.append(RecommendationReason(kind: .genre, text: "You rate \(name) highly"))
            }

            // 4. Era, only when it's a genuinely strong preference.
            if let date = candidate.movie.releaseDate {
                let decade = (Calendar.current.component(.year, from: date) / 10) * 10
                if let affinity = taste.decadeAffinity[decade], affinity > 0.3 {
                    reasons.append(RecommendationReason(kind: .era, text: "You love \(decade)s films"))
                }
            }

            // 5. Fallback so no card is ever left unexplained.
            if reasons.isEmpty, let vote = candidate.movie.voteAverage, vote >= 7.5 {
                reasons.append(RecommendationReason(
                    kind: .acclaim,
                    text: String(format: "Acclaimed — %.1f on TMDB", vote)
                ))
            }

            return (candidate: candidate, reasons: reasons)
        }
    }
}

// MARK: - Helpers

private extension Array {
    /// Split into fixed-size chunks so we can fan out to TMDB without
    /// opening dozens of sockets at once.
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
