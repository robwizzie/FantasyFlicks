//
//  RecommendationEngine.swift
//  FantasyFlicks
//
//  Builds personalised movie recommendations out of what the user has actually
//  rated — imported from Letterboxd, logged in the diary, or starred in the app.
//
//  The model has three signals, blended per candidate:
//
//    1. Collaborative — TMDB's "people who liked X also liked Y" graph, seeded
//       from the films this user rated highest.
//    2. Content — genre and era affinity, measured against *their own* average
//       rating. Someone who rates everything 4 stars gets no signal from
//       "they gave it 4 stars"; what matters is what they rate above their bar.
//    3. Creative — directors and actors whose work they consistently rate well.
//
//  Every recommendation carries the reasons that produced it, so the UI can
//  explain itself instead of being a black box.
//

import Foundation
import Combine

// MARK: - Reason

/// A human-readable justification for a recommendation.
struct RecommendationReason: Identifiable, Hashable, Sendable {
    enum Kind: String, Sendable {
        case similarTo      // "Because you loved Whiplash"
        case genre          // "You rate Sci-Fi highly"
        case person         // "From the director of Arrival"
        case acclaim        // "Widely acclaimed"
        case era            // "From a decade you love"
    }

    let kind: Kind
    let text: String

    var id: String { "\(kind.rawValue)|\(text)" }

    var iconName: String {
        switch kind {
        case .similarTo: return "heart.fill"
        case .genre: return "theatermasks.fill"
        case .person: return "person.fill"
        case .acclaim: return "star.fill"
        case .era: return "calendar"
        }
    }
}

// MARK: - Recommendation

struct MovieRecommendation: Identifiable, Hashable, Sendable {
    let movie: FFMovie
    /// 0-100. How well this fits the user's taste relative to the other candidates.
    let matchScore: Int
    let reasons: [RecommendationReason]

    var id: Int { movie.tmdbId }

    /// The single strongest reason, for compact UI.
    var headlineReason: RecommendationReason? { reasons.first }
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
        lovedMovieIds: [], favouredPeopleIds: [], peopleNames: [:], genreNames: [:]
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

    // MARK: - Tuning

    /// How many of the user's top-rated films seed the collaborative pass.
    private let seedCount = 12
    /// How many rated films we'll pull full credits for when building the profile.
    private let profileSampleSize = 45
    /// Candidates kept after scoring.
    private let resultLimit = 60
    /// A candidate needs at least this many TMDB votes to be trusted.
    private let minimumVoteCount = 200
    /// Rebuild automatically if the cached set is older than this.
    private let staleAfter: TimeInterval = 6 * 60 * 60

    private enum Keys {
        static let factsCache = "ff_reco_movie_facts"
        static let dismissed = "ff_reco_dismissed"
    }

    // MARK: - State

    private var factsCache: [Int: MovieTasteFacts] = [:]
    private var buildTask: Task<Void, Never>?
    /// Size of the ratings set the current recommendations were built from.
    private var ratingsCountAtLastBuild = 0

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
        let ratingsMoved = abs(seenService.ratings.count - ratingsCountAtLastBuild) >= 5

        if isFresh, !ratingsMoved, !recommendations.isEmpty { return }
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

        var candidates = await gatherCandidates(for: taste)
        guard !candidates.isEmpty else {
            recommendations = []
            error = "Couldn't reach TMDB to build your recommendations. Pull to try again."
            return
        }

        // Rank, trim, then enrich only the winners with credits so the
        // "from the director of…" reasons are accurate without 200 extra calls.
        candidates.sort { $0.rawScore > $1.rawScore }
        let winners = Array(candidates.prefix(resultLimit))
        let enriched = await enrichReasons(for: winners, taste: taste)

        recommendations = normalise(enriched)
        lastBuiltAt = Date()
        ratingsCountAtLastBuild = seenService.ratings.count
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

        let loved = ratings
            .filter { $0.value >= max(4.0, meanRating + 0.5) }
            .sorted { $0.value > $1.value }
            .map { $0.key }

        return TasteProfile(
            ratedCount: ratings.count,
            meanRating: meanRating,
            genreAffinity: genreAffinity,
            decadeAffinity: decadeAffinity,
            lovedMovieIds: Array(loved),
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
        /// tmdbIds of loved films whose "also liked" list produced this.
        var similarToSeeds: [Int] = []
        /// Person ids that surfaced this via a taste-driven discover query.
        var viaPeople: [Int] = []
        var rawScore: Double = 0
    }

    private func gatherCandidates(for taste: TasteProfile) async -> [Candidate] {
        let excluded = seenService.seenTmdbIds
            .union(dismissedIds)
            .union(Set(taste.lovedMovieIds))

        var pool: [Int: Candidate] = [:]

        // 1. Collaborative: what fans of their favourite films also loved.
        let seeds = Array(taste.lovedMovieIds.prefix(seedCount))
        for batch in seeds.chunked(into: 4) {
            await withTaskGroup(of: (Int, [TMDBMovie]).self) { group in
                for seedId in batch {
                    group.addTask { [weak self] in
                        guard let self else { return (seedId, []) }
                        let recommended = (try? await self.tmdb.getRecommendations(movieId: seedId, page: 1))?.results ?? []
                        let similar = (try? await self.tmdb.getSimilarMovies(movieId: seedId, page: 1))?.results ?? []
                        return (seedId, recommended + similar)
                    }
                }
                for await (seedId, movies) in group {
                    for movie in movies where !excluded.contains(movie.id) {
                        var candidate = pool[movie.id] ?? Candidate(movie: movie)
                        candidate.similarToSeeds.append(seedId)
                        pool[movie.id] = candidate
                    }
                }
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

        // Score everything now that all evidence is in.
        return pool.values
            .filter { ($0.movie.voteCount ?? 0) >= minimumVoteCount }
            .map { candidate in
                var scored = candidate
                scored.rawScore = score(candidate, taste: taste)
                return scored
            }
    }

    // MARK: - Scoring

    /// Blend the three signals into a single 0-1 score.
    private func score(_ candidate: Candidate, taste: TasteProfile) -> Double {
        let movie = candidate.movie

        // Collaborative — saturates fast; three independent favourites pointing
        // at the same film is already a very strong signal.
        let collaborative = min(1.0, Double(candidate.similarToSeeds.count) / 3.0)

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

        let weights: [(Double, Double)] = [
            (collaborative, 1.7),
            (genreSignal, 1.2),
            (peopleSignal, 1.3),
            (quality, 0.9),
            (eraSignal, 0.4)
        ]
        let total = weights.reduce(0.0) { $0 + $1.1 }
        return weights.reduce(0.0) { $0 + $1.0 * $1.1 } / total
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
                reasons: item.reasons
            )
        }
    }

    // MARK: - Reasons

    /// Turn the evidence behind each winner into readable reasons, strongest first.
    private func enrichReasons(
        for candidates: [Candidate],
        taste: TasteProfile
    ) async -> [(candidate: Candidate, reasons: [RecommendationReason])] {
        // Titles for the seed films we'll name in "because you loved…" reasons.
        var seedTitles: [Int: String] = [:]
        for seedId in taste.lovedMovieIds.prefix(seedCount) {
            if let cached = seenService.cachedMovie(for: seedId) {
                seedTitles[seedId] = cached.title
            }
        }

        return candidates.map { candidate in
            var reasons: [RecommendationReason] = []

            // 1. Strongest signal first: a specific film they loved.
            if let seedId = candidate.similarToSeeds.first, let title = seedTitles[seedId] {
                let others = candidate.similarToSeeds.count - 1
                let text = others > 0
                    ? "Because you loved \(title) +\(others) more"
                    : "Because you loved \(title)"
                reasons.append(RecommendationReason(kind: .similarTo, text: text))
            }

            // 2. A director or actor they consistently rate well.
            if let personId = candidate.viaPeople.first, let name = taste.peopleNames[personId] {
                reasons.append(RecommendationReason(kind: .person, text: "More from \(name)"))
            }

            // 3. Their best genre that this film actually belongs to.
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
